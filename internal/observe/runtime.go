package observe

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log/slog"
	"regexp"
	"strings"
)

type RuntimeKind string

const (
	RuntimeClient RuntimeKind = "client"
	RuntimeServer RuntimeKind = "server"
)

type Metadata struct {
	SessionID string
	Provider  string
	TURNMode  string
	PeerMode  string
}

type Observer struct {
	logger  *slog.Logger
	metrics *Metrics
	runtime RuntimeKind
	meta    Metadata
}

func NewSessionID() string {
	var data [16]byte
	if _, err := rand.Read(data[:]); err != nil {
		panic(err)
	}

	return hex.EncodeToString(data[:])
}

func NewObserver(runtime RuntimeKind, logger *slog.Logger, metrics *Metrics, meta Metadata) *Observer {
	if logger == nil {
		logger = slog.Default()
	}

	attrs := make([]any, 0, 10)
	attrs = append(attrs, "runtime", runtime)
	if meta.SessionID != "" {
		attrs = append(attrs, "session_id", meta.SessionID)
	}
	if meta.Provider != "" {
		attrs = append(attrs, "provider", sanitizeText(meta.Provider))
	}
	if meta.TURNMode != "" {
		attrs = append(attrs, "turn_mode", sanitizeText(meta.TURNMode))
	}
	if meta.PeerMode != "" {
		attrs = append(attrs, "peer_mode", sanitizeText(meta.PeerMode))
	}

	return &Observer{
		logger:  logger.With(attrs...),
		metrics: metrics,
		runtime: runtime,
		meta:    meta,
	}
}

func (o *Observer) Logger() *slog.Logger {
	if o == nil {
		return slog.Default()
	}

	return o.logger
}

func (o *Observer) Emit(ctx context.Context, level slog.Level, event string, attrs ...any) {
	if o == nil {
		return
	}

	sanitized := make([]any, 0, len(attrs)+2)
	sanitized = append(sanitized, "event", sanitizeText(event))
	sanitized = append(sanitized, sanitizeAttrs(attrs...)...)

	switch {
	case level >= slog.LevelError:
		o.logger.ErrorContext(ctx, event, sanitized...)
	case level >= slog.LevelWarn:
		o.logger.WarnContext(ctx, event, sanitized...)
	default:
		o.logger.InfoContext(ctx, event, sanitized...)
	}
}

func (o *Observer) RecordSessionStart() {
	if o == nil || o.metrics == nil {
		return
	}

	o.metrics.IncSessionStarts(o.runtime, o.meta.Provider, o.meta.TURNMode, o.meta.PeerMode)
}

func (o *Observer) RecordSessionFailure(stage string, startup bool) {
	if o == nil || o.metrics == nil {
		return
	}

	o.metrics.IncSessionFailures(o.runtime, o.meta.Provider, o.meta.TURNMode, o.meta.PeerMode, sanitizeText(stage))
	if startup {
		o.metrics.IncStartupStageFailures(o.runtime, o.meta.Provider, o.meta.TURNMode, o.meta.PeerMode, sanitizeText(stage))
	}
}

func (o *Observer) SetActiveWorkers(count int) {
	if o == nil || o.metrics == nil {
		return
	}

	o.metrics.SetActiveWorkers(o.runtime, o.meta.Provider, o.meta.TURNMode, o.meta.PeerMode, count)
}

func (o *Observer) RecordForward(direction string, bytes int) {
	if o == nil || o.metrics == nil || bytes <= 0 {
		return
	}

	o.metrics.AddForwardedTraffic(o.runtime, o.meta.Provider, sanitizeText(direction), bytes)
}

func sanitizeAttrs(attrs ...any) []any {
	if len(attrs) == 0 {
		return nil
	}

	sanitized := make([]any, 0, len(attrs))
	for _, attr := range attrs {
		switch value := attr.(type) {
		case slog.Attr:
			value.Value = slog.AnyValue(sanitizeValue(value.Value.Any()))
			sanitized = append(sanitized, value)
		default:
			sanitized = append(sanitized, sanitizeValue(value))
		}
	}

	return sanitized
}

func sanitizeValue(value any) any {
	switch typed := value.(type) {
	case string:
		return sanitizeText(typed)
	case error:
		return sanitizeText(typed.Error())
	case fmt.Stringer:
		return sanitizeText(typed.String())
	default:
		return value
	}
}

var sanitizers = []*regexp.Regexp{
	regexp.MustCompile(`(?i)(generic-turn://)([^:@/\s]+):([^@/\s]+)@`),
	regexp.MustCompile(`(?i)(turns?://)([^:@/\s]+):([^@/\s]+)@`),
	regexp.MustCompile(`(?i)(https?://[^/\s]+/call/join/)([^?\s]+)`),
	regexp.MustCompile(`(?i)(access_token=)[^&\s]+`),
	regexp.MustCompile(`(?i)(anonym_token=)[^&\s]+`),
	regexp.MustCompile(`(?i)(session_key=)[^&\s]+`),
	regexp.MustCompile(`(?i)(credential=)[^&\s]+`),
	regexp.MustCompile(`(?i)(password=)[^&\s]+`),
	regexp.MustCompile(`(?i)(username=)[^&\s]+`),
	regexp.MustCompile(`(?i)("credential"\s*:\s*")[^"]+(")`),
	regexp.MustCompile(`(?i)("password"\s*:\s*")[^"]+(")`),
	regexp.MustCompile(`(?i)("username"\s*:\s*")[^"]+(")`),
}

func sanitizeText(value string) string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return trimmed
	}

	sanitized := trimmed
	sanitized = sanitizers[0].ReplaceAllString(sanitized, `${1}<redacted:turn-username>:<redacted:turn-password>@`)
	sanitized = sanitizers[1].ReplaceAllString(sanitized, `${1}<redacted:turn-username>:<redacted:turn-password>@`)
	sanitized = sanitizers[2].ReplaceAllString(sanitized, `${1}<redacted:invite-token>`)
	sanitized = sanitizers[3].ReplaceAllString(sanitized, `${1}<redacted:access-token>`)
	sanitized = sanitizers[4].ReplaceAllString(sanitized, `${1}<redacted:anonym-token>`)
	sanitized = sanitizers[5].ReplaceAllString(sanitized, `${1}<redacted:session-key>`)
	sanitized = sanitizers[6].ReplaceAllString(sanitized, `${1}<redacted:turn-password>`)
	sanitized = sanitizers[7].ReplaceAllString(sanitized, `${1}<redacted:turn-password>`)
	sanitized = sanitizers[8].ReplaceAllString(sanitized, `${1}<redacted:turn-username>`)
	sanitized = sanitizers[9].ReplaceAllString(sanitized, `${1}<redacted:turn-password>${2}`)
	sanitized = sanitizers[10].ReplaceAllString(sanitized, `${1}<redacted:turn-password>${2}`)
	sanitized = sanitizers[11].ReplaceAllString(sanitized, `${1}<redacted:turn-username>${2}`)

	return sanitized
}
