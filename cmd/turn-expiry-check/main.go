package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"time"

	"github.com/pion/transport/v4/stdnet"
	"github.com/pion/turn/v5"

	"github.com/defin85/vk-turn-proxy-go/internal/provider/genericturn"
	"github.com/defin85/vk-turn-proxy-go/internal/turnrest"
)

const defaultRTO = 200 * time.Millisecond

type config struct {
	Link             string
	TURNMode         string
	RTO              time.Duration
	SkipNetwork      bool
	JSON             bool
	AfterExpiryGrace time.Duration
}

type report struct {
	Address             string      `json:"address"`
	UsernameFormat      string      `json:"username_format"`
	CandidateExpiry     string      `json:"candidate_expiry,omitempty"`
	CandidateTTL        string      `json:"candidate_ttl,omitempty"`
	CandidateSuffix     string      `json:"candidate_suffix,omitempty"`
	AllocateNow         probeResult `json:"allocate_now"`
	AllocateAfterExpiry probeResult `json:"allocate_after_expiry"`
}

type probeResult struct {
	Attempted bool   `json:"attempted"`
	OK        bool   `json:"ok"`
	RelayAddr string `json:"relay_addr,omitempty"`
	Error     string `json:"error,omitempty"`
}

func main() {
	os.Exit(run(context.Background(), os.Stdout, os.Stderr, os.Args[1:]))
}

func run(ctx context.Context, stdout io.Writer, stderr io.Writer, args []string) int {
	cfg, err := parseFlags(stderr, args)
	if err != nil {
		return 2
	}

	resolution, err := genericturn.New().Resolve(ctx, cfg.Link)
	if err != nil {
		fmt.Fprintf(stderr, "parse generic-turn link: %v\n", err)
		return 2
	}

	now := time.Now().UTC()
	rep := report{
		Address:             resolution.Credentials.Address,
		UsernameFormat:      "unknown",
		AllocateNow:         probeResult{},
		AllocateAfterExpiry: probeResult{},
	}

	candidate, ok := turnrest.ParseExpiryCandidate(resolution.Credentials.Username)
	if ok {
		rep.UsernameFormat = candidate.Format
		rep.CandidateExpiry = candidate.Expiry.Format(time.RFC3339)
		rep.CandidateTTL = time.Until(candidate.Expiry).Round(time.Second).String()
		if candidate.Suffix != "" {
			rep.CandidateSuffix = candidate.Suffix
		}
	} else {
		rep.CandidateTTL = ""
	}

	if !cfg.SkipNetwork {
		rep.AllocateNow = freshAllocate(
			ctx,
			resolution.Credentials.Address,
			resolution.Credentials.Username,
			resolution.Credentials.Password,
			cfg.TURNMode,
			cfg.RTO,
		)
	}

	if !cfg.SkipNetwork && ok && cfg.AfterExpiryGrace > 0 {
		wait := time.Until(candidate.Expiry.Add(cfg.AfterExpiryGrace))
		if wait > 0 {
			timer := time.NewTimer(wait)
			defer timer.Stop()
			select {
			case <-ctx.Done():
				fmt.Fprintf(stderr, "context canceled before after-expiry probe: %v\n", ctx.Err())
				return 1
			case <-timer.C:
			}
		}
		rep.AllocateAfterExpiry = freshAllocate(
			ctx,
			resolution.Credentials.Address,
			resolution.Credentials.Username,
			resolution.Credentials.Password,
			cfg.TURNMode,
			cfg.RTO,
		)
	}

	if cfg.JSON {
		encoder := json.NewEncoder(stdout)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(rep); err != nil {
			fmt.Fprintf(stderr, "encode report: %v\n", err)
			return 1
		}
		return 0
	}

	fmt.Fprintf(stdout, "address=%s\n", rep.Address)
	fmt.Fprintf(stdout, "username_format=%s\n", rep.UsernameFormat)
	if rep.CandidateExpiry != "" {
		fmt.Fprintf(stdout, "candidate_expiry=%s\n", rep.CandidateExpiry)
		fmt.Fprintf(stdout, "candidate_ttl=%s\n", rep.CandidateTTL)
		if rep.CandidateSuffix != "" {
			fmt.Fprintf(stdout, "candidate_suffix=%s\n", rep.CandidateSuffix)
		}
	} else {
		fmt.Fprintln(stdout, "candidate_expiry=unrecognized")
	}
	printProbeResult(stdout, "allocate_now", rep.AllocateNow)
	printProbeResult(stdout, "allocate_after_expiry", rep.AllocateAfterExpiry)
	fmt.Fprintf(stdout, "observed_at=%s\n", now.Format(time.RFC3339))

	return 0
}

func parseFlags(stderr io.Writer, args []string) (config, error) {
	cfg := config{
		TURNMode: "udp",
		RTO:      defaultRTO,
	}

	flags := flag.NewFlagSet("turn-expiry-check", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&cfg.Link, "link", "", "generic-turn:// link to inspect")
	flags.StringVar(&cfg.TURNMode, "turn-mode", cfg.TURNMode, "turn transport to use: udp or tcp")
	flags.DurationVar(&cfg.RTO, "rto", cfg.RTO, "pion TURN client retransmission timeout")
	flags.BoolVar(&cfg.SkipNetwork, "skip-network", cfg.SkipNetwork, "only parse the username candidate expiry without TURN Allocate probes")
	flags.BoolVar(&cfg.JSON, "json", cfg.JSON, "emit a JSON report")
	flags.DurationVar(&cfg.AfterExpiryGrace, "after-expiry-grace", cfg.AfterExpiryGrace, "if set, wait until candidate expiry plus this grace period and repeat fresh TURN Allocate")
	if err := flags.Parse(args); err != nil {
		return config{}, err
	}
	if strings.TrimSpace(cfg.Link) == "" {
		return config{}, fmt.Errorf("missing -link")
	}
	switch cfg.TURNMode {
	case "udp", "tcp":
	default:
		return config{}, fmt.Errorf("unsupported -turn-mode %q", cfg.TURNMode)
	}
	if cfg.RTO <= 0 {
		return config{}, fmt.Errorf("rto must be positive")
	}
	if cfg.AfterExpiryGrace < 0 {
		return config{}, fmt.Errorf("after-expiry-grace must be non-negative")
	}

	return cfg, nil
}

func printProbeResult(stdout io.Writer, label string, result probeResult) {
	switch {
	case !result.Attempted:
		fmt.Fprintf(stdout, "%s=skipped\n", label)
	case result.OK:
		fmt.Fprintf(stdout, "%s=ok relay_addr=%s\n", label, result.RelayAddr)
	default:
		fmt.Fprintf(stdout, "%s=error err=%s\n", label, result.Error)
	}
}

func freshAllocate(
	ctx context.Context,
	address string,
	username string,
	password string,
	turnMode string,
	rto time.Duration,
) probeResult {
	result := probeResult{Attempted: true}

	baseConn, err := openBaseConn(ctx, address, turnMode)
	if err != nil {
		result.Error = err.Error()
		return result
	}
	defer baseConn.Close()

	turnNet, err := stdnet.NewNet()
	if err != nil {
		result.Error = fmt.Sprintf("create turn network: %v", err)
		return result
	}

	client, err := turn.NewClient(&turn.ClientConfig{
		STUNServerAddr: address,
		TURNServerAddr: address,
		Conn:           baseConn,
		Net:            turnNet,
		Username:       username,
		Password:       password,
		RTO:            rto,
	})
	if err != nil {
		result.Error = fmt.Sprintf("create turn client: %v", err)
		return result
	}
	defer client.Close()

	if err := client.Listen(); err != nil {
		result.Error = fmt.Sprintf("listen turn client: %v", err)
		return result
	}

	relayConn, err := client.Allocate()
	if err != nil {
		result.Error = fmt.Sprintf("allocate turn relay: %v", err)
		return result
	}
	defer relayConn.Close()

	result.OK = true
	if relayConn.LocalAddr() != nil {
		result.RelayAddr = relayConn.LocalAddr().String()
	}

	return result
}

func openBaseConn(ctx context.Context, address string, turnMode string) (net.PacketConn, error) {
	switch turnMode {
	case "udp":
		remoteAddr, err := net.ResolveUDPAddr("udp", address)
		if err != nil {
			return nil, fmt.Errorf("resolve turn udp address %q: %w", address, err)
		}

		network := "udp4"
		localAddr := "0.0.0.0:0"
		if remoteAddr.IP != nil && remoteAddr.IP.To4() == nil {
			network = "udp6"
			localAddr = "[::]:0"
		}

		conn, err := net.ListenPacket(network, localAddr)
		if err != nil {
			return nil, fmt.Errorf("bind turn client socket: %w", err)
		}

		return conn, nil
	case "tcp":
		remoteAddr, err := net.ResolveTCPAddr("tcp", address)
		if err != nil {
			return nil, fmt.Errorf("resolve turn tcp address %q: %w", address, err)
		}

		dialer := &net.Dialer{}
		network := "tcp"
		if remoteAddr.IP != nil {
			if remoteAddr.IP.To4() != nil {
				network = "tcp4"
			} else {
				network = "tcp6"
			}
		}

		conn, err := dialer.DialContext(ctx, network, remoteAddr.String())
		if err != nil {
			return nil, fmt.Errorf("dial turn server: %w", err)
		}

		return turn.NewSTUNConn(conn), nil
	default:
		return nil, fmt.Errorf("unsupported turn mode %q", turnMode)
	}
}
