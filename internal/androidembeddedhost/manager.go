package androidembeddedhost

import (
	"context"
	"io"
	"log/slog"
	"net"
	"net/http"
	"sync"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/buildinfo"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

type Option func(*config)

type config struct {
	listenAddr  string
	logger      *slog.Logger
	hostFactory func(*slog.Logger) *clientcontrol.Host
}

type Manager struct {
	mu          sync.Mutex
	listenAddr  string
	logger      *slog.Logger
	hostFactory func(*slog.Logger) *clientcontrol.Host

	host     *clientcontrol.Host
	server   *http.Server
	listener net.Listener
	baseURL  string
}

func New(opts ...Option) *Manager {
	cfg := config{
		listenAddr: "127.0.0.1:0",
		logger: slog.New(
			slog.NewTextHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelInfo}),
		),
		hostFactory: func(logger *slog.Logger) *clientcontrol.Host {
			return clientcontrol.New(
				clientcontrol.WithLogger(logger),
				clientcontrol.WithBuildIdentity(currentBuildIdentity()),
				clientcontrol.WithRegistry(mobileProviderRegistry()),
				clientcontrol.WithInteractiveChallengeMetadataResolver(
					mobileChallengeMetadata,
				),
			)
		},
	}
	for _, opt := range opts {
		if opt != nil {
			opt(&cfg)
		}
	}
	if cfg.logger == nil {
		cfg.logger = slog.New(
			slog.NewTextHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelInfo}),
		)
	}
	if cfg.hostFactory == nil {
		cfg.hostFactory = func(logger *slog.Logger) *clientcontrol.Host {
			return clientcontrol.New(
				clientcontrol.WithLogger(logger),
				clientcontrol.WithBuildIdentity(currentBuildIdentity()),
				clientcontrol.WithRegistry(mobileProviderRegistry()),
				clientcontrol.WithInteractiveChallengeMetadataResolver(
					mobileChallengeMetadata,
				),
			)
		}
	}

	return &Manager{
		listenAddr:  cfg.listenAddr,
		logger:      cfg.logger,
		hostFactory: cfg.hostFactory,
	}
}

func WithListenAddr(listenAddr string) Option {
	return func(cfg *config) {
		cfg.listenAddr = listenAddr
	}
}

func WithLogger(logger *slog.Logger) Option {
	return func(cfg *config) {
		cfg.logger = logger
	}
}

func WithHostFactory(factory func(*slog.Logger) *clientcontrol.Host) Option {
	return func(cfg *config) {
		cfg.hostFactory = factory
	}
}

func (m *Manager) EnsureStarted() (string, error) {
	m.mu.Lock()
	if m.server != nil && m.listener != nil && m.baseURL != "" {
		baseURL := m.baseURL
		m.mu.Unlock()
		return baseURL, nil
	}

	listener, err := net.Listen("tcp", m.listenAddr)
	if err != nil {
		m.mu.Unlock()
		return "", err
	}
	host := m.hostFactory(m.logger)
	server := &http.Server{
		Handler: clientcontrol.Handler(host),
		BaseContext: func(net.Listener) context.Context {
			return context.Background()
		},
	}
	baseURL := "http://" + listener.Addr().String()
	m.host = host
	m.server = server
	m.listener = listener
	m.baseURL = baseURL
	m.mu.Unlock()

	go func() {
		err := server.Serve(listener)
		if err != nil && err != http.ErrServerClosed {
			m.logger.Error("android embedded host stopped unexpectedly", "error", err)
			m.mu.Lock()
			if m.server == server {
				m.server = nil
				m.listener = nil
				m.baseURL = ""
				m.host = nil
			}
			m.mu.Unlock()
		}
	}()

	return baseURL, nil
}

func (m *Manager) Stop() error {
	m.mu.Lock()
	server := m.server
	if server == nil {
		m.mu.Unlock()
		return nil
	}
	m.server = nil
	m.listener = nil
	m.baseURL = ""
	m.host = nil
	m.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return server.Shutdown(ctx)
}

func (m *Manager) BaseURL() string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.baseURL
}

func currentBuildIdentity() clientcontrol.BuildIdentity {
	identity := buildinfo.Current(buildinfo.Options{
		Role:   "android_embedded_host",
		Target: "android/embedded",
	})
	return clientcontrol.BuildIdentity{
		Product:     identity.Product,
		Version:     identity.Version,
		BuildNumber: identity.BuildNumber,
		Revision:    identity.Revision,
		Dirty:       identity.Dirty,
		BuiltAt:     identity.BuiltAt,
		Role:        identity.Role,
		Target:      identity.Target,
	}
}
