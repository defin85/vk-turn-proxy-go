package providerprompt

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/cdproto/runtime"
	"github.com/chromedp/chromedp"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const browserStartupTimeout = 15 * time.Second
const browserStageTimeout = 20 * time.Second

const browserHeadlessEnv = "VK_PROVIDER_BROWSER_HEADLESS"

type browserSession interface {
	Open(context.Context, string) error
	Cookies(context.Context, []string) ([]*http.Cookie, error)
	ExecuteStageRequests(context.Context, []provider.BrowserStageRequest) ([]provider.BrowserStageResult, error)
	ObserveStageResults(context.Context, []provider.BrowserStageObservation, <-chan struct{}, chan<- struct{}) ([]provider.BrowserStageResult, error)
	Close() error
}

type chromiumSession struct {
	process       *exec.Cmd
	debugURL      string
	userDataDir   string
	sessionCancel context.CancelFunc
	remoteCtx     context.Context
	remoteCancel  context.CancelFunc
	targetCtx     context.Context
	targetCancel  context.CancelFunc
	launchLog     *bytes.Buffer
}

func newChromiumSession(ctx context.Context) (browserSession, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}

	browserPath, err := resolveBrowserPath()
	if err != nil {
		return nil, err
	}
	debugPort, err := reserveTCPPort()
	if err != nil {
		return nil, fmt.Errorf("reserve browser debug port: %w", err)
	}
	userDataDir, err := os.MkdirTemp("", "vk-provider-browser-*")
	if err != nil {
		return nil, fmt.Errorf("create browser profile dir: %w", err)
	}

	sessionCtx, sessionCancel := context.WithCancel(context.Background())
	launchLog := &bytes.Buffer{}
	cmd := exec.Command(browserPath, chromiumLaunchArgs(userDataDir, debugPort)...)
	cmd.Stdout = launchLog
	cmd.Stderr = launchLog
	if err := cmd.Start(); err != nil {
		sessionCancel()
		_ = os.RemoveAll(userDataDir)
		return nil, fmt.Errorf("start chromium: %w", err)
	}

	debugURL := fmt.Sprintf("http://127.0.0.1:%d", debugPort)
	startupCtx, cancel := newBrowserOperationContext(sessionCtx, ctx, browserStartupTimeout)
	defer cancel()
	if err := waitForDevTools(startupCtx, debugURL); err != nil {
		sessionCancel()
		_ = cmd.Process.Kill()
		_, _ = cmd.Process.Wait()
		_ = os.RemoveAll(userDataDir)
		return nil, fmt.Errorf("wait for browser devtools: %w%s", err, browserStartupLogSuffix(launchLog.String()))
	}

	remoteCtx, remoteCancel := chromedp.NewRemoteAllocator(sessionCtx, debugURL)
	targetCtx, targetCancel := chromedp.NewContext(remoteCtx)

	return &chromiumSession{
		process:       cmd,
		debugURL:      debugURL,
		userDataDir:   userDataDir,
		sessionCancel: sessionCancel,
		remoteCtx:     remoteCtx,
		remoteCancel:  remoteCancel,
		targetCtx:     targetCtx,
		targetCancel:  targetCancel,
		launchLog:     launchLog,
	}, nil
}

func (s *chromiumSession) Open(ctx context.Context, challengeURL string) error {
	if s == nil {
		return errors.New("browser session is required")
	}
	if strings.TrimSpace(challengeURL) == "" {
		return errors.New("challenge URL is required")
	}

	return chromedp.Run(s.targetCtx,
		chromedp.ActionFunc(func(execCtx context.Context) error {
			return network.Enable().
				WithMaxPostDataSize(1 << 20).
				WithMaxResourceBufferSize(1 << 20).
				WithMaxTotalBufferSize(8 << 20).
				Do(execCtx)
		}),
		chromedp.Navigate(challengeURL),
		chromedp.WaitReady("body", chromedp.ByQuery),
	)
}

func (s *chromiumSession) Cookies(ctx context.Context, urls []string) ([]*http.Cookie, error) {
	if s == nil {
		return nil, errors.New("browser session is required")
	}

	params := network.GetCookies()
	if len(urls) > 0 {
		params = params.WithURLs(urls)
	}
	var (
		cookies []*network.Cookie
		err     error
	)
	if runErr := chromedp.Run(s.targetCtx, chromedp.ActionFunc(func(execCtx context.Context) error {
		cookies, err = params.Do(execCtx)
		return err
	})); runErr != nil {
		return nil, runErr
	}

	result := make([]*http.Cookie, 0, len(cookies))
	for _, cookie := range cookies {
		if cookie == nil {
			continue
		}
		httpCookie := &http.Cookie{
			Name:     cookie.Name,
			Value:    cookie.Value,
			Domain:   cookie.Domain,
			Path:     cookie.Path,
			HttpOnly: cookie.HTTPOnly,
			Secure:   cookie.Secure,
		}
		if !cookie.Session && cookie.Expires >= 0 {
			httpCookie.Expires = time.Unix(int64(cookie.Expires), 0)
		}
		result = append(result, httpCookie)
	}

	return result, nil
}

func (s *chromiumSession) ExecuteStageRequests(ctx context.Context, requests []provider.BrowserStageRequest) ([]provider.BrowserStageResult, error) {
	if s == nil {
		return nil, errors.New("browser session is required")
	}

	results := make([]provider.BrowserStageResult, 0, len(requests))
	for _, request := range requests {
		result, err := s.executeStageRequest(ctx, request)
		if err != nil {
			return nil, err
		}
		results = append(results, result)
	}

	return results, nil
}

func (s *chromiumSession) ObserveStageResults(
	ctx context.Context,
	observations []provider.BrowserStageObservation,
	confirmed <-chan struct{},
	ready chan<- struct{},
) ([]provider.BrowserStageResult, error) {
	if s == nil {
		return nil, errors.New("browser session is required")
	}
	if len(observations) == 0 {
		return nil, errors.New("browser stage observations are required")
	}
	if confirmed == nil {
		return nil, errors.New("browser stage observation confirmation channel is required")
	}

	listenCtx, stopListening := context.WithCancel(s.targetCtx)
	defer stopListening()

	type requestMeta struct {
		observation provider.BrowserStageObservation
		method      string
		url         string
		order       int
		formKeys    []string
		status      int
	}

	type observedStageResult struct {
		order  int
		result provider.BrowserStageResult
	}

	resultsCh := make(chan observedStageResult, len(observations)+8)
	errCh := make(chan error, 1)

	var (
		mu        sync.Mutex
		nextOrder int
		matched   = make(map[network.RequestID]requestMeta)
	)

	sendErr := func(err error) {
		select {
		case errCh <- err:
		default:
		}
	}

	chromedp.ListenTarget(listenCtx, func(event any) {
		switch ev := event.(type) {
		case *network.EventRequestWillBeSent:
			if ev.Request == nil {
				return
			}
			formValues := extractObservedFormValues(ev.Request)
			observation, ok := matchObservation(observations, ev.Request.Method, ev.Request.URL, formValues)
			if !ok {
				return
			}

			mu.Lock()
			matched[ev.RequestID] = requestMeta{
				observation: observation,
				method:      ev.Request.Method,
				url:         ev.Request.URL,
				order:       nextOrder,
				formKeys:    sortedKeys(formValues),
			}
			nextOrder++
			mu.Unlock()
		case *network.EventResponseReceived:
			mu.Lock()
			meta, ok := matched[ev.RequestID]
			if ok && ev.Response != nil {
				meta.status = int(ev.Response.Status)
				matched[ev.RequestID] = meta
			}
			mu.Unlock()
		case *network.EventLoadingFailed:
			mu.Lock()
			_, ok := matched[ev.RequestID]
			mu.Unlock()
			if ok {
				sendErr(fmt.Errorf("browser-observed stage request failed: %s", ev.ErrorText))
			}
		case *network.EventLoadingFinished:
			mu.Lock()
			meta, ok := matched[ev.RequestID]
			mu.Unlock()
			if !ok {
				return
			}

			go func(requestID network.RequestID, meta requestMeta) {
				var body []byte
				var err error
				if err := chromedp.Run(s.targetCtx, chromedp.ActionFunc(func(execCtx context.Context) error {
					body, err = network.GetResponseBody(requestID).Do(execCtx)
					return err
				})); err != nil {
					sendErr(fmt.Errorf("read browser-observed stage response: %w", err))
					return
				}

				raw := body
				if len(body) > 0 && !json.Valid(body) {
					raw, err = base64.StdEncoding.DecodeString(string(body))
					if err != nil {
						sendErr(fmt.Errorf("decode browser-observed stage response: %w", err))
						return
					}
				}

				var payload map[string]any
				if err := json.Unmarshal(raw, &payload); err != nil {
					sendErr(fmt.Errorf("decode browser-observed stage payload: %w", err))
					return
				}

				select {
				case resultsCh <- observedStageResult{
					order: meta.order,
					result: provider.BrowserStageResult{
						Stage:      meta.observation.Stage,
						Method:     meta.method,
						URL:        meta.url,
						FormKeys:   meta.formKeys,
						StatusCode: meta.status,
						Body:       payload,
					},
				}:
				case <-ctx.Done():
				}
			}(ev.RequestID, meta)
		}
	})

	if ready != nil {
		close(ready)
	}

	var (
		results         []observedStageResult
		postConfirmOpen bool
		timer           *time.Timer
		timerCh         <-chan time.Time
	)

	settleDelay := time.Second

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case err := <-errCh:
			return nil, err
		case observed := <-resultsCh:
			results = append(results, observed)
			if postConfirmOpen {
				if timer == nil {
					timer = time.NewTimer(settleDelay)
				} else {
					if !timer.Stop() {
						select {
						case <-timer.C:
						default:
						}
					}
					timer.Reset(settleDelay)
				}
				timerCh = timer.C
			}
		case <-confirmed:
			if postConfirmOpen {
				continue
			}
			postConfirmOpen = true
			if len(results) > 0 {
				timer = time.NewTimer(settleDelay)
				timerCh = timer.C
			} else {
				timer = time.NewTimer(browserStageTimeout)
				timerCh = timer.C
			}
		case <-timerCh:
			if len(results) == 0 {
				return nil, errors.New("browser-observed stage result was not captured")
			}
			sort.SliceStable(results, func(i, j int) bool {
				return results[i].order < results[j].order
			})
			sorted := make([]provider.BrowserStageResult, 0, len(results))
			for _, observed := range results {
				sorted = append(sorted, observed.result)
			}
			return sorted, nil
		}
	}
}

func (s *chromiumSession) executeStageRequest(ctx context.Context, request provider.BrowserStageRequest) (provider.BrowserStageResult, error) {
	if strings.TrimSpace(request.Method) == "" {
		return provider.BrowserStageResult{}, errors.New("browser stage request method is required")
	}
	if !strings.EqualFold(request.Method, http.MethodPost) {
		return provider.BrowserStageResult{}, fmt.Errorf("unsupported browser stage request method %q", request.Method)
	}
	if strings.TrimSpace(request.URL) == "" {
		return provider.BrowserStageResult{}, errors.New("browser stage request URL is required")
	}

	requestCtx, cancel := context.WithTimeout(ctx, browserStageTimeout)
	defer cancel()

	script, err := submitStageRequestScript(request)
	if err != nil {
		return provider.BrowserStageResult{}, err
	}
	var response struct {
		Method     string         `json:"method"`
		URL        string         `json:"url"`
		StatusCode int            `json:"statusCode"`
		Body       map[string]any `json:"body"`
	}
	if err := chromedp.Run(s.targetCtx, chromedp.ActionFunc(func(execCtx context.Context) error {
		result, exception, err := runtime.Evaluate(script).
			WithAwaitPromise(true).
			WithReturnByValue(true).
			Do(execCtx)
		if err != nil {
			return err
		}
		if exception != nil {
			return exception
		}
		if result == nil {
			return errors.New("browser stage response is empty")
		}
		if err := json.Unmarshal(result.Value, &response); err != nil {
			return fmt.Errorf("decode browser stage result: %w", err)
		}
		return nil
	})); err != nil {
		return provider.BrowserStageResult{}, fmt.Errorf("execute browser stage request: %w", err)
	}
	if err := requestCtx.Err(); err != nil {
		return provider.BrowserStageResult{}, fmt.Errorf("wait browser stage response: %w", err)
	}

	return provider.BrowserStageResult{
		Stage:      request.Stage,
		Method:     response.Method,
		URL:        response.URL,
		FormKeys:   sortedKeys(request.Form),
		StatusCode: response.StatusCode,
		Body:       response.Body,
	}, nil
}

func matchObservation(observations []provider.BrowserStageObservation, method string, requestURL string, formValues map[string]string) (provider.BrowserStageObservation, bool) {
	for _, observation := range observations {
		if !strings.EqualFold(observation.Method, method) {
			continue
		}
		if strings.HasPrefix(requestURL, observation.URLPrefix) {
			if !matchesObservedFormKeys(observation.RequiredFormKeys, formValues) {
				continue
			}
			if !matchesObservedFormValues(observation.RequiredFormValues, formValues) {
				continue
			}
			if !matchesObservedFormValueAlternatives(observation.RequiredFormValueAlternatives, formValues) {
				continue
			}
			return observation, true
		}
	}

	return provider.BrowserStageObservation{}, false
}

func matchesObservedFormKeys(required []string, observed map[string]string) bool {
	if len(required) == 0 {
		return true
	}

	for _, key := range required {
		if _, ok := observed[key]; !ok {
			return false
		}
	}

	return true
}

func matchesObservedFormValues(required map[string]string, observed map[string]string) bool {
	if len(required) == 0 {
		return true
	}
	for key, want := range required {
		if got, ok := observed[key]; !ok || got != want {
			return false
		}
	}
	return true
}

func matchesObservedFormValueAlternatives(required map[string][]string, observed map[string]string) bool {
	if len(required) == 0 {
		return true
	}

	for key, allowed := range required {
		got, ok := observed[key]
		if !ok {
			return false
		}
		matched := false
		for _, candidate := range allowed {
			if got == candidate {
				matched = true
				break
			}
		}
		if !matched {
			return false
		}
	}

	return true
}

func extractObservedFormValues(request *network.Request) map[string]string {
	if request == nil || !request.HasPostData {
		return nil
	}

	formValues := make(map[string]string)
	for _, entry := range request.PostDataEntries {
		if entry == nil || entry.Bytes == "" {
			continue
		}
		raw := entry.Bytes
		decoded, err := base64.StdEncoding.DecodeString(raw)
		if err == nil {
			raw = string(decoded)
		}

		parsedValues, err := url.ParseQuery(raw)
		if err != nil {
			continue
		}
		for key := range parsedValues {
			if len(parsedValues[key]) == 0 {
				continue
			}
			formValues[key] = parsedValues.Get(key)
		}
	}

	if len(formValues) == 0 {
		return nil
	}

	return formValues
}

func sortedKeys(values map[string]string) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func uniqueSorted(values []string) []string {
	if len(values) == 0 {
		return nil
	}

	seen := make(map[string]struct{}, len(values))
	keys := make([]string, 0, len(values))
	for _, value := range values {
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		keys = append(keys, value)
	}
	sort.Strings(keys)
	return keys
}

func newBrowserOperationContext(baseCtx context.Context, callerCtx context.Context, timeout time.Duration) (context.Context, context.CancelFunc) {
	if baseCtx == nil {
		baseCtx = context.Background()
	}

	opCtx, cancel := context.WithCancel(baseCtx)
	stopCallerCancel := func() bool { return false }
	if callerCtx != nil {
		stopCallerCancel = context.AfterFunc(callerCtx, cancel)
	}

	if timeout <= 0 {
		return opCtx, func() {
			stopCallerCancel()
			cancel()
		}
	}

	timeoutCtx, timeoutCancel := context.WithTimeout(opCtx, timeout)
	return timeoutCtx, func() {
		timeoutCancel()
		stopCallerCancel()
		cancel()
	}
}

func submitStageRequestScript(request provider.BrowserStageRequest) (string, error) {
	methodJSON, err := json.Marshal(strings.ToUpper(request.Method))
	if err != nil {
		return "", fmt.Errorf("marshal browser stage method: %w", err)
	}
	urlJSON, err := json.Marshal(request.URL)
	if err != nil {
		return "", fmt.Errorf("marshal browser stage url: %w", err)
	}
	formJSON, err := json.Marshal(request.Form)
	if err != nil {
		return "", fmt.Errorf("marshal browser stage form: %w", err)
	}

	return fmt.Sprintf(`(async function () {
  const method = %s;
  const action = %s;
  const fields = %s;
  const body = new URLSearchParams();
  for (const [key, value] of Object.entries(fields || {})) {
    body.append(key, value == null ? "" : String(value));
  }
  const response = await fetch(action, {
    method,
    credentials: "include",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body
  });
  let payload;
  try {
    payload = await response.json();
  } catch (error) {
    throw new Error("browser stage response is not valid JSON");
  }
  return {
    method,
    url: action,
    statusCode: response.status,
    body: payload
  };
})()`, methodJSON, urlJSON, formJSON), nil
}

func (s *chromiumSession) Close() error {
	if s == nil {
		return nil
	}

	var errs []error
	if s.targetCancel != nil {
		if err := chromedp.Cancel(s.targetCtx); err != nil && !errors.Is(err, context.Canceled) {
			errs = append(errs, err)
		}
		s.targetCancel = nil
	}
	if s.remoteCancel != nil {
		s.remoteCancel()
		s.remoteCancel = nil
	}
	if s.sessionCancel != nil {
		s.sessionCancel()
		s.sessionCancel = nil
	}
	if s.process != nil && s.process.Process != nil {
		if err := s.process.Process.Kill(); err != nil && !errors.Is(err, os.ErrProcessDone) {
			errs = append(errs, err)
		}
		_, _ = s.process.Process.Wait()
		s.process = nil
	}
	if s.userDataDir != "" {
		if err := os.RemoveAll(s.userDataDir); err != nil {
			errs = append(errs, err)
		}
		s.userDataDir = ""
	}

	return errors.Join(errs...)
}

func resolveBrowserPath() (string, error) {
	if configured := strings.TrimSpace(os.Getenv("VK_PROVIDER_BROWSER")); configured != "" {
		return configured, nil
	}
	for _, candidate := range []string{"chromium", "chromium-browser", "google-chrome", "google-chrome-stable"} {
		path, err := exec.LookPath(candidate)
		if err == nil {
			return path, nil
		}
	}

	return "", errors.New("no supported browser executable found")
}

func chromiumLaunchArgs(userDataDir string, debugPort int) []string {
	args := []string{
		"--no-first-run",
		"--no-default-browser-check",
		fmt.Sprintf("--user-data-dir=%s", userDataDir),
		fmt.Sprintf("--remote-debugging-port=%d", debugPort),
	}
	if shouldLaunchBrowserHeadless() {
		args = append(args,
			"--headless=new",
			"--disable-gpu",
			"--no-sandbox",
			"--disable-dev-shm-usage",
		)
	} else {
		args = append(args, "--new-window")
	}
	args = append(args, "about:blank")

	return args
}

func shouldLaunchBrowserHeadless() bool {
	if raw, ok := os.LookupEnv(browserHeadlessEnv); ok && strings.TrimSpace(raw) != "" {
		return parseTruthyEnv(raw)
	}

	return parseTruthyEnv(os.Getenv("CI")) ||
		parseTruthyEnv(os.Getenv("GITHUB_ACTIONS")) ||
		parseTruthyEnv(os.Getenv("ACT"))
}

func parseTruthyEnv(raw string) bool {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "1", "true", "yes", "on":
		return true
	default:
		return false
	}
}

func browserStartupLogSuffix(logs string) string {
	if strings.TrimSpace(logs) == "" {
		return ""
	}

	lines := strings.Split(strings.TrimSpace(logs), "\n")
	if len(lines) > 8 {
		lines = lines[len(lines)-8:]
	}

	return "\nstartup log tail:\n" + strings.Join(lines, "\n")
}

func reserveTCPPort() (int, error) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer listener.Close()

	addr, ok := listener.Addr().(*net.TCPAddr)
	if !ok {
		return 0, fmt.Errorf("unexpected listener address %T", listener.Addr())
	}

	return addr.Port, nil
}

func waitForDevTools(ctx context.Context, baseURL string) error {
	versionURL := strings.TrimRight(baseURL, "/") + "/json/version"
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	client := &http.Client{Timeout: 2 * time.Second}
	for {
		request, err := http.NewRequestWithContext(ctx, http.MethodGet, versionURL, nil)
		if err != nil {
			return err
		}
		response, err := client.Do(request)
		if err == nil {
			body := struct {
				WebSocketDebuggerURL string `json:"webSocketDebuggerUrl"`
			}{}
			decodeErr := json.NewDecoder(response.Body).Decode(&body)
			_ = response.Body.Close()
			if decodeErr == nil && strings.TrimSpace(body.WebSocketDebuggerURL) != "" {
				return nil
			}
		}

		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
		}
	}
}
