package observe

import (
	"log/slog"
	"os"
	"strings"
)

func NewLogger(level string) *slog.Logger {
	options := &slog.HandlerOptions{Level: parseLevel(level)}
	handler := slog.NewTextHandler(os.Stdout, options)

	return slog.New(handler)
}

func parseLevel(level string) slog.Level {
	switch strings.ToLower(strings.TrimSpace(level)) {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
