package providerprompt

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/chromedp/cdproto/network"
	"github.com/chromedp/chromedp"
)

const browserStartupTimeout = 15 * time.Second

type browserSession interface {
	Open(context.Context, string) error
	Cookies(context.Context, []string) ([]*http.Cookie, error)
	Close() error
}

type chromiumSession struct {
	process      *exec.Cmd
	debugURL     string
	userDataDir  string
	remoteCtx    context.Context
	remoteCancel context.CancelFunc
	targetCtx    context.Context
	targetCancel context.CancelFunc
}

func newChromiumSession(ctx context.Context) (browserSession, error) {
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

	cmd := exec.CommandContext(ctx, browserPath,
		"--no-first-run",
		"--no-default-browser-check",
		"--new-window",
		fmt.Sprintf("--user-data-dir=%s", userDataDir),
		fmt.Sprintf("--remote-debugging-port=%d", debugPort),
		"about:blank",
	)
	if err := cmd.Start(); err != nil {
		_ = os.RemoveAll(userDataDir)
		return nil, fmt.Errorf("start chromium: %w", err)
	}

	debugURL := fmt.Sprintf("http://127.0.0.1:%d", debugPort)
	startupCtx, cancel := context.WithTimeout(ctx, browserStartupTimeout)
	defer cancel()
	if err := waitForDevTools(startupCtx, debugURL); err != nil {
		_ = cmd.Process.Kill()
		_, _ = cmd.Process.Wait()
		_ = os.RemoveAll(userDataDir)
		return nil, fmt.Errorf("wait for browser devtools: %w", err)
	}

	remoteCtx, remoteCancel := chromedp.NewRemoteAllocator(ctx, debugURL)
	targetCtx, targetCancel := chromedp.NewContext(remoteCtx)

	return &chromiumSession{
		process:      cmd,
		debugURL:     debugURL,
		userDataDir:  userDataDir,
		remoteCtx:    remoteCtx,
		remoteCancel: remoteCancel,
		targetCtx:    targetCtx,
		targetCancel: targetCancel,
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
		network.Enable(),
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
