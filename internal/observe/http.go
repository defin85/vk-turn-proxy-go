package observe

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
)

func StartMetricsServer(ctx context.Context, listenAddr string, metrics *Metrics, logger *slog.Logger) (net.Addr, error) {
	if metrics == nil || listenAddr == "" {
		return nil, nil
	}
	if logger == nil {
		logger = slog.Default()
	}

	listener, err := net.Listen("tcp", listenAddr)
	if err != nil {
		return nil, fmt.Errorf("listen metrics endpoint: %w", err)
	}

	server := &http.Server{
		Handler: metricsMux(metrics),
	}
	go func() {
		<-ctx.Done()
		_ = server.Close()
	}()
	go func() {
		if err := server.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("metrics server stopped unexpectedly", "err", sanitizeText(err.Error()))
		}
	}()

	return listener.Addr(), nil
}

func metricsMux(metrics *Metrics) http.Handler {
	mux := http.NewServeMux()
	mux.Handle("/metrics", metrics.Handler())
	return mux
}
