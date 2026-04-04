package observe

import (
	"io"
	"log/slog"
	"os"
	"strings"
)

func NewLogger(level string) *slog.Logger {
	return NewLoggerWriter(level, os.Stdout)
}

func NewLoggerWriter(level string, writer io.Writer) *slog.Logger {
	if writer == nil {
		writer = os.Stdout
	}

	options := &slog.HandlerOptions{Level: parseLevel(level)}
	handler := slog.NewTextHandler(writer, options)

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
