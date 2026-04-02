package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/vk"
)

func main() {
	registry := provider.NewRegistry(vk.New())
	os.Exit(runProbe(context.Background(), os.Stdout, os.Stderr, os.Args[1:], registry))
}

func runProbe(ctx context.Context, stdout io.Writer, stderr io.Writer, args []string, registry *provider.Registry) int {
	cfg, err := parseProbeFlags(stderr, args)
	if err != nil {
		return 2
	}

	if cfg.ListProviders {
		names := registry.Names()
		sort.Strings(names)
		for _, name := range names {
			fmt.Fprintln(stdout, name)
		}
		return 0
	}

	if err := cfg.Validate(); err != nil {
		fmt.Fprintf(stderr, "invalid probe config: %v\n", err)
		return 2
	}

	adapter, err := registry.Get(cfg.Provider)
	if err != nil {
		fmt.Fprintf(stderr, "provider lookup: %v\n", err)
		return 2
	}

	resolution, err := adapter.Resolve(ctx, cfg.Link)
	if err != nil {
		artifactPath, artifactErr := writeProbeArtifact(cfg.OutputDir, cfg.Provider, artifactFromError(err))
		if artifactErr != nil {
			fmt.Fprintf(stderr, "write probe artifact: %v\n", artifactErr)
		}
		if artifactPath != "" {
			fmt.Fprintf(stderr, "artifact_path=%s\n", artifactPath)
		}
		if errors.Is(err, provider.ErrNotImplemented) {
			fmt.Fprintf(stderr, "provider adapter is not ready: %v\n", err)
			return 3
		}
		fmt.Fprintf(stderr, "probe failed: %v\n", err)
		return 1
	}

	artifactPath, err := writeProbeArtifact(cfg.OutputDir, cfg.Provider, resolution.Artifact)
	if err != nil {
		fmt.Fprintf(stderr, "write probe artifact: %v\n", err)
		return 1
	}

	stageCount := 0
	if resolution.Artifact != nil {
		stageCount = len(resolution.Artifact.Stages)
	}
	fmt.Fprintf(stdout, "provider=%s turn_addr=%s ttl=%s stages=%d artifact=%s\n",
		cfg.Provider,
		resolution.Credentials.Address,
		resolution.Credentials.TTL,
		stageCount,
		artifactPath,
	)

	return 0
}

func parseProbeFlags(stderr io.Writer, args []string) (config.ProbeConfig, error) {
	cfg := config.DefaultProbeConfig()
	flags := flag.NewFlagSet("probe", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&cfg.Provider, "provider", cfg.Provider, "provider name")
	flags.StringVar(&cfg.Link, "link", cfg.Link, "provider link or invite")
	flags.StringVar(&cfg.BindInterface, "bind-interface", cfg.BindInterface, "preferred local interface or address")
	flags.StringVar(&cfg.OutputDir, "output-dir", cfg.OutputDir, "directory for collected artifacts")
	flags.BoolVar(&cfg.ListProviders, "list-providers", cfg.ListProviders, "list available providers and exit")

	return cfg, flags.Parse(args)
}

func artifactFromError(err error) *provider.ProbeArtifact {
	var carrier provider.ArtifactCarrier
	if errors.As(err, &carrier) {
		return carrier.Artifact()
	}

	return nil
}

func writeProbeArtifact(outputDir string, providerName string, artifact *provider.ProbeArtifact) (string, error) {
	if artifact == nil {
		return "", nil
	}

	if artifact.Provider == "" {
		artifact.Provider = providerName
	}

	dir := filepath.Join(outputDir, providerName)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}

	path := filepath.Join(dir, "probe-artifact.json")
	data, err := json.MarshalIndent(artifact, "", "  ")
	if err != nil {
		return "", err
	}
	if err := os.WriteFile(path, append(data, '\n'), 0o644); err != nil {
		return "", err
	}

	return path, nil
}
