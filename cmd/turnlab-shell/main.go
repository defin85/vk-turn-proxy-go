package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"os/signal"
	"sort"
	"syscall"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/test/turnlab"
)

type shellConfig struct {
	jsonOutput         bool
	logLevel           string
	allocationLifetime time.Duration
	peerIdleTimeout    time.Duration
	bindAddress        string
	advertiseAddress   string
	turnPort           int
	turnTCPPort        int
	peerPort           int
	windowsGUI         bool
}

const defaultShellPeerIdleTimeout = 5 * time.Minute

type shellDescriptor struct {
	TURNAddress          string `json:"turn_address"`
	TURNTCPAddress       string `json:"turn_tcp_address"`
	GenericTurnLink      string `json:"generic_turn_link"`
	GenericTurnTCPLink   string `json:"generic_turn_tcp_link"`
	PeerAddress          string `json:"peer_address"`
	UpstreamAddress      string `json:"upstream_address"`
	BindAddress          string `json:"bind_address,omitempty"`
	AdvertiseAddress     string `json:"advertise_address,omitempty"`
	AllocationLifetimeMS int64  `json:"allocation_lifetime_ms,omitempty"`
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	os.Exit(runTurnlabShell(ctx, os.Stdout, os.Stderr, os.Args[1:]))
}

func runTurnlabShell(ctx context.Context, stdout io.Writer, stderr io.Writer, args []string) int {
	cfg, err := parseTurnlabShellFlags(stderr, args)
	if err != nil {
		return 2
	}
	turnlabOpts, bindAddress, advertiseAddress, err := resolveTurnlabOptions(cfg, detectNonLoopbackIPv4)
	if err != nil {
		fmt.Fprintf(stderr, "resolve turnlab shell addresses: %v\n", err)
		return 2
	}

	logger := observe.NewLoggerWriter(cfg.logLevel, stderr)
	harness, err := turnlab.StartWithOptions(ctx, logger, turnlabOpts)
	if err != nil {
		fmt.Fprintf(stderr, "start turnlab shell: %v\n", err)
		return 1
	}
	defer func() {
		if closeErr := harness.Close(); closeErr != nil {
			fmt.Fprintf(stderr, "close turnlab shell: %v\n", closeErr)
		}
	}()

	descriptor := shellDescriptor{
		TURNAddress:        harness.Descriptor.TURNAddress,
		TURNTCPAddress:     harness.Descriptor.TURNTCPAddress,
		GenericTurnLink:    harness.GenericTurnLink(),
		GenericTurnTCPLink: harness.Descriptor.GenericTurnTCPLink(),
		PeerAddress:        harness.Descriptor.PeerAddress,
		UpstreamAddress:    harness.Descriptor.UpstreamAddress,
		BindAddress:        bindAddress,
		AdvertiseAddress:   advertiseAddress,
	}
	if cfg.allocationLifetime > 0 {
		descriptor.AllocationLifetimeMS = cfg.allocationLifetime.Milliseconds()
	}

	if cfg.jsonOutput {
		encoder := json.NewEncoder(stdout)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(descriptor); err != nil {
			fmt.Fprintf(stderr, "encode turnlab shell descriptor: %v\n", err)
			return 1
		}
	} else {
		fmt.Fprintln(stdout, "turnlab shell is ready")
		fmt.Fprintln(stdout, "provider=generic-turn")
		fmt.Fprintf(stdout, "link=%s\n", descriptor.GenericTurnLink)
		fmt.Fprintf(stdout, "peer_addr=%s\n", descriptor.PeerAddress)
		fmt.Fprintf(stdout, "turn_addr=%s\n", descriptor.TURNAddress)
		fmt.Fprintf(stdout, "turn_tcp_addr=%s\n", descriptor.TURNTCPAddress)
		fmt.Fprintf(stdout, "bind_addr=%s\n", descriptor.BindAddress)
		fmt.Fprintf(stdout, "advertise_addr=%s\n", descriptor.AdvertiseAddress)
		fmt.Fprintf(stdout, "upstream_addr=%s\n", descriptor.UpstreamAddress)
		if descriptor.AllocationLifetimeMS > 0 {
			fmt.Fprintf(stdout, "allocation_lifetime_ms=%d\n", descriptor.AllocationLifetimeMS)
		}
		fmt.Fprintln(stdout, "stop=Ctrl+C")
	}

	<-ctx.Done()
	return 0
}

func parseTurnlabShellFlags(stderr io.Writer, args []string) (shellConfig, error) {
	cfg := shellConfig{
		logLevel:        "info",
		peerIdleTimeout: defaultShellPeerIdleTimeout,
	}
	flags := flag.NewFlagSet("turnlab-shell", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.BoolVar(&cfg.jsonOutput, "json", cfg.jsonOutput, "emit the harness descriptor as JSON")
	flags.StringVar(&cfg.logLevel, "log-level", cfg.logLevel, "log level: debug|info|warn|error")
	flags.DurationVar(&cfg.allocationLifetime, "allocation-lifetime", cfg.allocationLifetime, "optional TURN allocation lifetime override")
	flags.DurationVar(&cfg.peerIdleTimeout, "peer-idle-timeout", cfg.peerIdleTimeout, "idle timeout for the shell-managed peer path")
	flags.StringVar(&cfg.bindAddress, "bind-address", cfg.bindAddress, "listener bind address for TURN and peer endpoints")
	flags.StringVar(&cfg.advertiseAddress, "advertise-address", cfg.advertiseAddress, "published address for TURN links and peer endpoints")
	flags.IntVar(&cfg.turnPort, "turn-port", cfg.turnPort, "fixed TURN UDP listen port; 0 keeps the current dynamic port behavior")
	flags.IntVar(&cfg.turnTCPPort, "turn-tcp-port", cfg.turnTCPPort, "fixed TURN TCP listen port; 0 keeps the current dynamic port behavior")
	flags.IntVar(&cfg.peerPort, "peer-port", cfg.peerPort, "fixed DTLS peer listen port; 0 keeps the current dynamic port behavior")
	flags.BoolVar(&cfg.windowsGUI, "windows-gui", cfg.windowsGUI, "publish desktop-consumable addresses for a Windows GUI using a harness started inside WSL or another sibling host")
	return cfg, flags.Parse(args)
}

func resolveTurnlabOptions(
	cfg shellConfig,
	detectAddress func() (string, error),
) (turnlab.Options, string, string, error) {
	bindAddress := cfg.bindAddress
	advertiseAddress := cfg.advertiseAddress

	if cfg.windowsGUI && (bindAddress == "" || advertiseAddress == "") {
		detectedAddress, err := detectAddress()
		if err != nil {
			return turnlab.Options{}, "", "", err
		}
		if bindAddress == "" {
			bindAddress = detectedAddress
		}
		if advertiseAddress == "" {
			advertiseAddress = detectedAddress
		}
	}

	if bindAddress == "" && advertiseAddress != "" {
		bindAddress = advertiseAddress
	}
	if advertiseAddress == "" && bindAddress != "" {
		advertiseAddress = bindAddress
	}
	if bindAddress == "" {
		bindAddress = "127.0.0.1"
	}
	if advertiseAddress == "" {
		advertiseAddress = bindAddress
	}
	if cfg.peerIdleTimeout < 0 {
		return turnlab.Options{}, "", "", errors.New("peer idle timeout must be positive")
	}
	if cfg.peerIdleTimeout == 0 {
		cfg.peerIdleTimeout = defaultShellPeerIdleTimeout
	}

	return turnlab.Options{
		AllocationLifetime: cfg.allocationLifetime,
		PeerIdleTimeout:    cfg.peerIdleTimeout,
		BindAddress:        bindAddress,
		AdvertiseAddress:   advertiseAddress,
		TURNPort:           cfg.turnPort,
		TURNTCPPort:        cfg.turnTCPPort,
		PeerPort:           cfg.peerPort,
	}, bindAddress, advertiseAddress, nil
}

func detectNonLoopbackIPv4() (string, error) {
	interfaces, err := net.Interfaces()
	if err != nil {
		return "", err
	}

	candidates := make([]string, 0, len(interfaces))
	for _, iface := range interfaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			var ip net.IP
			switch value := addr.(type) {
			case *net.IPNet:
				ip = value.IP
			case *net.IPAddr:
				ip = value.IP
			default:
				continue
			}
			if ip == nil || ip.IsLoopback() || !ip.IsGlobalUnicast() {
				continue
			}
			if v4 := ip.To4(); v4 != nil {
				candidates = append(candidates, v4.String())
			}
		}
	}
	if len(candidates) == 0 {
		return "", errors.New("no non-loopback IPv4 address found")
	}
	sort.Strings(candidates)
	return candidates[0], nil
}
