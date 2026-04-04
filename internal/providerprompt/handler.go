package providerprompt

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const continueToken = "continue"

type Handler struct {
	stdin             io.Reader
	stderr            io.Writer
	openURL           func(context.Context, string) error
	newBrowserSession func(context.Context) (browserSession, error)
}

type Options struct {
	OpenURL           func(context.Context, string) error
	NewBrowserSession func(context.Context) (browserSession, error)
}

func NewHandler(stdin io.Reader, stderr io.Writer, options Options) *Handler {
	openURL := options.OpenURL
	if openURL == nil {
		openURL = openURLInBrowser
	}
	newBrowserSession := options.NewBrowserSession
	if newBrowserSession == nil {
		newBrowserSession = newChromiumSession
	}

	return &Handler{
		stdin:             stdin,
		stderr:            stderr,
		openURL:           openURL,
		newBrowserSession: newBrowserSession,
	}
}

func (h *Handler) Handle(ctx context.Context, challenge provider.InteractiveChallenge) error {
	if h == nil {
		return errors.New("interactive provider handler is required")
	}
	if challenge == nil {
		return errors.New("interactive provider challenge is required")
	}
	if h.stderr == nil {
		return errors.New("interactive provider stderr is required")
	}
	if h.stdin == nil {
		return errors.New("interactive provider stdin is required")
	}

	fmt.Fprintf(h.stderr,
		"provider challenge requires manual action: provider=%s stage=%s kind=%s\n",
		challenge.ProviderName(),
		challenge.StageName(),
		challenge.Kind(),
	)
	if prompt := strings.TrimSpace(challenge.Prompt()); prompt != "" {
		fmt.Fprintln(h.stderr, prompt)
	}

	if challengeURL := strings.TrimSpace(challenge.OpenURL()); challengeURL != "" {
		if err := h.openURL(ctx, challengeURL); err != nil {
			fmt.Fprintf(h.stderr, "open browser failed; open manually: %s\n", challengeURL)
		} else {
			fmt.Fprintln(h.stderr, "browser opened for provider challenge")
		}
	}

	fmt.Fprintf(h.stderr, "type %q after completing the challenge, or cancel the command: ", continueToken)

	resultCh := make(chan error, 1)
	go func() {
		reader := bufio.NewReader(h.stdin)
		line, err := reader.ReadString('\n')
		if err != nil && !errors.Is(err, io.EOF) {
			resultCh <- fmt.Errorf("read interactive provider confirmation: %w", err)
			return
		}
		if strings.EqualFold(strings.TrimSpace(line), continueToken) {
			resultCh <- nil
			return
		}
		resultCh <- errors.New("interactive provider challenge was not confirmed")
	}()

	select {
	case <-ctx.Done():
		return fmt.Errorf("interactive provider challenge aborted: %w", ctx.Err())
	case err := <-resultCh:
		return err
	}
}

func (h *Handler) Continue(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
	if err := h.validate(challenge); err != nil {
		return nil, err
	}
	challengeURL := strings.TrimSpace(challenge.OpenURL())
	if challengeURL == "" {
		return nil, errors.New("interactive provider challenge URL is required")
	}
	if h.newBrowserSession == nil {
		return nil, errors.New("provider browser session is required")
	}

	session, err := h.newBrowserSession(ctx)
	if err != nil {
		return nil, fmt.Errorf("start provider browser session: %w", err)
	}
	defer func() {
		_ = session.Close()
	}()

	h.printIntro(challenge)
	if err := session.Open(ctx, challengeURL); err != nil {
		return nil, fmt.Errorf("open controlled browser challenge: %w", err)
	}
	fmt.Fprintln(h.stderr, "controlled browser opened for provider challenge")

	var (
		observedResultsCh chan []provider.BrowserStageResult
		observationErrCh  chan error
		confirmed         chan struct{}
	)
	if observedChallenge, ok := challenge.(provider.BrowserObservedStageChallenge); ok {
		confirmed = make(chan struct{})
		observedResultsCh = make(chan []provider.BrowserStageResult, 1)
		observationErrCh = make(chan error, 1)
		go func() {
			stageResults, err := session.ObserveStageResults(ctx, observedChallenge.BrowserStageObservations(), confirmed)
			if err != nil {
				observationErrCh <- err
				return
			}
			observedResultsCh <- stageResults
		}()
	}

	if err := h.waitForContinue(ctx); err != nil {
		if confirmed != nil {
			close(confirmed)
		}
		return nil, err
	}
	if confirmed != nil {
		close(confirmed)
	}

	result := &provider.BrowserContinuation{}
	if observedResultsCh != nil {
		select {
		case <-ctx.Done():
			return nil, fmt.Errorf("observe browser continuation stage: %w", ctx.Err())
		case err := <-observationErrCh:
			return nil, fmt.Errorf("observe browser continuation stage: %w", err)
		case stageResults := <-observedResultsCh:
			result.StageResults = append(result.StageResults, stageResults...)
			return result, nil
		}
	}
	if stageChallenge, ok := challenge.(provider.BrowserOwnedStageChallenge); ok {
		stageResults, err := session.ExecuteStageRequests(ctx, stageChallenge.BrowserStageRequests())
		if err != nil {
			return nil, fmt.Errorf("execute browser continuation stage: %w", err)
		}
		result.StageResults = append(result.StageResults, stageResults...)
		return result, nil
	}

	cookieURLs := []string{challengeURL}
	if browserChallenge, ok := challenge.(provider.BrowserContinuationChallenge); ok {
		if urls := browserChallenge.CookieURLs(); len(urls) > 0 {
			cookieURLs = urls
		}
	}
	cookies, err := session.Cookies(ctx, cookieURLs)
	if err != nil {
		return nil, fmt.Errorf("collect browser continuation cookies: %w", err)
	}
	result.Cookies = append(result.Cookies, cookies...)

	return result, nil
}

func (h *Handler) validate(challenge provider.InteractiveChallenge) error {
	if h == nil {
		return errors.New("interactive provider handler is required")
	}
	if challenge == nil {
		return errors.New("interactive provider challenge is required")
	}
	if h.stderr == nil {
		return errors.New("interactive provider stderr is required")
	}
	if h.stdin == nil {
		return errors.New("interactive provider stdin is required")
	}

	return nil
}

func (h *Handler) printIntro(challenge provider.InteractiveChallenge) {
	fmt.Fprintf(h.stderr,
		"provider challenge requires manual action: provider=%s stage=%s kind=%s\n",
		challenge.ProviderName(),
		challenge.StageName(),
		challenge.Kind(),
	)
	if prompt := strings.TrimSpace(challenge.Prompt()); prompt != "" {
		fmt.Fprintln(h.stderr, prompt)
	}
}

func (h *Handler) waitForContinue(ctx context.Context) error {
	fmt.Fprintf(h.stderr, "type %q after completing the challenge, or cancel the command: ", continueToken)

	resultCh := make(chan error, 1)
	go func() {
		reader := bufio.NewReader(h.stdin)
		line, err := reader.ReadString('\n')
		if err != nil && !errors.Is(err, io.EOF) {
			resultCh <- fmt.Errorf("read interactive provider confirmation: %w", err)
			return
		}
		if strings.EqualFold(strings.TrimSpace(line), continueToken) {
			resultCh <- nil
			return
		}
		resultCh <- errors.New("interactive provider challenge was not confirmed")
	}()

	select {
	case <-ctx.Done():
		return fmt.Errorf("interactive provider challenge aborted: %w", ctx.Err())
	case err := <-resultCh:
		return err
	}
}

func openURLInBrowser(ctx context.Context, challengeURL string) error {
	var lastErr error
	for _, command := range []string{"xdg-open", "wslview", "open"} {
		path, err := exec.LookPath(command)
		if err != nil {
			lastErr = err
			continue
		}
		cmd := exec.CommandContext(ctx, path, challengeURL)
		if err := cmd.Run(); err != nil {
			lastErr = err
			continue
		}
		return nil
	}
	if lastErr == nil {
		lastErr = errors.New("no browser opener command found")
	}

	return lastErr
}
