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
	continuation, err := StartContinuation(ctx, challenge, Options{
		NewBrowserSession: h.newBrowserSession,
	})
	if err != nil {
		return nil, err
	}
	defer func() {
		_ = continuation.Close()
	}()

	h.printIntro(challenge)
	fmt.Fprintln(h.stderr, "controlled browser opened for provider challenge")

	if err := h.waitForContinue(ctx); err != nil {
		return nil, err
	}
	return continuation.Complete(ctx)
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
