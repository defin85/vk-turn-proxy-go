package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/vpscatalog"
)

type config struct {
	Listen     string
	ReadToken  string
	IssueToken string
	AdminToken string
	Issuer     string
	Audience   string
	EndpointID string
	LogLevel   string
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	os.Exit(run(ctx, os.Stdout, os.Stderr, os.Args[1:]))
}

func run(ctx context.Context, stdout io.Writer, stderr io.Writer, args []string) int {
	cfg, err := parseFlags(stderr, args)
	if err != nil {
		fmt.Fprintf(stderr, "invalid vps-provider-catalog flags: %v\n", err)
		return 2
	}
	listener, err := net.Listen("tcp", cfg.Listen)
	if err != nil {
		fmt.Fprintf(stderr, "vps-provider-catalog listen failed: %v\n", err)
		return 1
	}
	defer listener.Close()

	now := time.Now().UTC()
	service := vpscatalog.NewService(vpscatalog.ServiceOptions{
		Snapshot:   vpscatalog.AttachIntegrity(sampleSnapshot(now, cfg), "vps-provider-catalog"),
		Authorizer: authorizerFromConfig(cfg),
		Now:        time.Now,
	})
	server := &http.Server{
		Handler: service.Handler(),
		BaseContext: func(net.Listener) context.Context {
			return ctx
		},
	}
	logger := observe.NewLoggerWriter(cfg.LogLevel, stdout)
	logger.Info(
		"vps provider catalog listening",
		"listen", listener.Addr().String(),
		"endpoint_id", cfg.EndpointID,
		"issuer", cfg.Issuer,
		"audience", cfg.Audience,
	)

	errCh := make(chan error, 1)
	go func() {
		errCh <- server.Serve(listener)
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdownCtx)
		if err := <-errCh; err != nil && !errors.Is(err, http.ErrServerClosed) {
			fmt.Fprintf(stderr, "vps-provider-catalog stopped: %v\n", err)
			return 1
		}
		return 0
	case err := <-errCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			fmt.Fprintf(stderr, "vps-provider-catalog stopped: %v\n", err)
			return 1
		}
		return 0
	}
}

func parseFlags(stderr io.Writer, args []string) (config, error) {
	cfg := config{
		Listen:     "127.0.0.1:7788",
		Issuer:     "vk-turn-proxy-go",
		Audience:   "clientcontrol",
		EndpointID: "vps-main",
		LogLevel:   "info",
	}
	flags := flag.NewFlagSet("vps-provider-catalog", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&cfg.Listen, "listen", cfg.Listen, "HTTP listen address")
	flags.StringVar(&cfg.ReadToken, "read-token", "", "bearer token for catalog reads")
	flags.StringVar(&cfg.IssueToken, "issue-token", "", "bearer token for artifact issue/export")
	flags.StringVar(&cfg.AdminToken, "admin-token", "", "bearer token for metrics, audit, and admin operations")
	flags.StringVar(&cfg.Issuer, "issuer", cfg.Issuer, "snapshot issuer")
	flags.StringVar(&cfg.Audience, "audience", cfg.Audience, "snapshot audience")
	flags.StringVar(&cfg.EndpointID, "endpoint-id", cfg.EndpointID, "stable VPS catalog endpoint id")
	flags.StringVar(&cfg.LogLevel, "log-level", cfg.LogLevel, "log level: debug|info|warn|error")
	if err := flags.Parse(args); err != nil {
		return config{}, err
	}
	cfg.Listen = strings.TrimSpace(cfg.Listen)
	cfg.ReadToken = strings.TrimSpace(cfg.ReadToken)
	cfg.IssueToken = strings.TrimSpace(cfg.IssueToken)
	cfg.AdminToken = strings.TrimSpace(cfg.AdminToken)
	cfg.Issuer = strings.TrimSpace(cfg.Issuer)
	cfg.Audience = strings.TrimSpace(cfg.Audience)
	cfg.EndpointID = strings.TrimSpace(cfg.EndpointID)
	if cfg.Listen == "" {
		return config{}, fmt.Errorf("missing -listen")
	}
	if cfg.ReadToken == "" {
		return config{}, fmt.Errorf("missing -read-token")
	}
	if cfg.IssueToken == "" {
		return config{}, fmt.Errorf("missing -issue-token")
	}
	if cfg.AdminToken == "" {
		return config{}, fmt.Errorf("missing -admin-token")
	}
	if cfg.Issuer == "" {
		return config{}, fmt.Errorf("missing -issuer")
	}
	if cfg.Audience == "" {
		return config{}, fmt.Errorf("missing -audience")
	}
	if cfg.EndpointID == "" {
		return config{}, fmt.Errorf("missing -endpoint-id")
	}
	return cfg, nil
}

func authorizerFromConfig(cfg config) vpscatalog.TokenAuthorizer {
	authorizer := make(vpscatalog.TokenAuthorizer)
	addScope(authorizer, cfg.ReadToken, vpscatalog.AuthScopeCatalogRead)
	addScope(authorizer, cfg.IssueToken, vpscatalog.AuthScopeArtifactIssue)
	addScope(authorizer, cfg.AdminToken, vpscatalog.AuthScopeAdminMutation)
	return authorizer
}

func addScope(authorizer vpscatalog.TokenAuthorizer, token string, scope vpscatalog.AuthScope) {
	token = strings.TrimSpace(token)
	if token == "" {
		return
	}
	for _, existing := range authorizer[token] {
		if existing == scope {
			return
		}
	}
	authorizer[token] = append(authorizer[token], scope)
}

func sampleSnapshot(now time.Time, cfg config) vpscatalog.CatalogSnapshot {
	evidenceExpires := now.Add(5 * time.Minute)
	return vpscatalog.CatalogSnapshot{
		Version:     vpscatalog.SchemaVersion,
		GeneratedAt: now,
		ExpiresAt:   now.Add(10 * time.Minute),
		Issuer:      cfg.Issuer,
		Audience:    cfg.Audience,
		EndpointID:  cfg.EndpointID,
		Generation:  uint64(now.Unix()),
		Sources: []vpscatalog.ProviderSource{{
			ID:           "managed-turn",
			ProviderID:   "generic-turn",
			DisplayName:  "Managed TURN",
			Description:  "VPS-managed TURN credential issuer",
			SourceFamily: "managed_turn",
			Health: vpscatalog.Health{
				Status:    vpscatalog.HealthStatusHealthy,
				ExpiresAt: &evidenceExpires,
			},
			Evidence: []vpscatalog.Evidence{{
				Kind:      "synthetic_probe",
				Subject:   "catalog_snapshot",
				Status:    vpscatalog.EvidenceStatusFresh,
				ExpiresAt: &evidenceExpires,
			}},
			ArtifactOffers: []vpscatalog.ArtifactOffer{{
				ID:                     "turn-handoff",
				Family:                 "generic_turn",
				AccessMethods:          []string{"turn_credentials"},
				Actions:                []string{"start_on_this_device", "export_handoff"},
				RemoteEndpointFamily:   "turn_server",
				RemoteEndpointRole:     "wireguard_raw_datagram",
				CompatibleProfileKinds: []string{"wireguard_native_v1"},
				MaxTTLSeconds:          60,
				Health: vpscatalog.Health{
					Status:    vpscatalog.HealthStatusHealthy,
					ExpiresAt: &evidenceExpires,
				},
				Evidence: []vpscatalog.Evidence{{
					Kind:      "remote_ingress_probe",
					Subject:   "turn_handoff",
					Status:    vpscatalog.EvidenceStatusFresh,
					ExpiresAt: &evidenceExpires,
				}},
				Redaction: vpscatalog.DefaultRedactionPolicy(),
			}},
		}},
	}
}
