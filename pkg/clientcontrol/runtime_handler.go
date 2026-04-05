package clientcontrol

import (
	"context"
	"log/slog"
)

type runtimeRecord struct {
	level   slog.Level
	message string
	attrs   map[string]any
}

type runtimeHandler struct {
	forward *slog.Logger
	onEmit  func(context.Context, runtimeRecord)
	attrs   []slog.Attr
}

func newRuntimeHandler(forward *slog.Logger, onEmit func(context.Context, runtimeRecord)) *runtimeHandler {
	return &runtimeHandler{
		forward: forward,
		onEmit:  onEmit,
	}
}

func (h *runtimeHandler) Enabled(context.Context, slog.Level) bool {
	return true
}

func (h *runtimeHandler) Handle(ctx context.Context, record slog.Record) error {
	attrMap := make(map[string]any, len(h.attrs)+record.NumAttrs())
	attrList := make([]slog.Attr, 0, len(h.attrs)+record.NumAttrs())
	for _, attr := range h.attrs {
		attrMap[attr.Key] = attr.Value.Any()
		attrList = append(attrList, attr)
	}
	record.Attrs(func(attr slog.Attr) bool {
		attrMap[attr.Key] = attr.Value.Any()
		attrList = append(attrList, attr)
		return true
	})

	if h.forward != nil {
		h.forward.LogAttrs(ctx, record.Level, record.Message, attrList...)
	}
	if h.onEmit != nil {
		h.onEmit(ctx, runtimeRecord{
			level:   record.Level,
			message: record.Message,
			attrs:   attrMap,
		})
	}

	return nil
}

func (h *runtimeHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	merged := append(append([]slog.Attr(nil), h.attrs...), attrs...)
	return &runtimeHandler{
		forward: h.forward,
		onEmit:  h.onEmit,
		attrs:   merged,
	}
}

func (h *runtimeHandler) WithGroup(string) slog.Handler {
	return h
}
