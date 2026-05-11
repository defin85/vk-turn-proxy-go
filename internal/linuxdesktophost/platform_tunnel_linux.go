//go:build linux

package linuxdesktophost

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/netip"
	"os"
	"os/exec"
	"runtime"
	"slices"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/wireguardturnruntime"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
	"golang.zx2c4.com/wireguard/tun"
)

const (
	linuxTunInterfaceName = "rdtun0"
	linuxTunDefaultMTU    = 1280
	linuxDataplaneURL     = "http://1.1.1.1/cdn-cgi/trace"
)

type linuxCommandRunner interface {
	Run(context.Context, string, ...string) ([]byte, error)
}

type osLinuxCommandRunner struct{}

func (osLinuxCommandRunner) Run(ctx context.Context, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return output, fmt.Errorf("%s %s: %v: %s", name, strings.Join(args, " "), err, strings.TrimSpace(string(output)))
	}
	return output, nil
}

type linuxTunFactory func(string, int) (tun.Device, error)

type linuxWireGuardRuntime interface {
	PeerStats() (wireguardturnruntime.PeerStats, error)
	Close() error
}

type linuxRuntimeStarter func(context.Context, *clientcontrol.WireGuardTurnExecutionLease, tun.Device) (linuxWireGuardRuntime, error)

type linuxHostState struct {
	tunDevice       tun.Device
	interfaceName   string
	underlayDevice  string
	underlayGateway string
	exclusions      []string
	runtime         linuxWireGuardRuntime
}

type linuxTunLifecycle struct {
	logger *slog.Logger
	runner linuxCommandRunner
	tun    linuxTunFactory

	resolvConfPath string
	probeURL       string
	httpClient     *http.Client
	euid           func() int
	runtimeStarter linuxRuntimeStarter

	mu    sync.Mutex
	state *linuxHostState
}

type linuxDefaultRoute struct {
	Device  string
	Gateway string
}

func defaultLinuxTunPrerequisiteCheck(build clientcontrol.BuildIdentity) *linuxTunPrerequisiteFailure {
	if runtime.GOOS != "linux" {
		return &linuxTunPrerequisiteFailure{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			message: fmt.Sprintf(
				"The %s host cannot run linux_tun outside Linux.",
				hostTargetLabel(build),
			),
		}
	}
	if failure := linuxTunPackagedTargetFailure(build, os.Getenv(linuxTunPackagedTargetEnv)); failure != nil {
		return failure
	}
	if ubuntu, detail := isUbuntuHost(); !ubuntu {
		return &linuxTunPrerequisiteFailure{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			message: fmt.Sprintf(
				"The %s host keeps linux_tun unavailable because add-85 only promotes the packaged Ubuntu desktop target%s.",
				hostTargetLabel(build),
				detail,
			),
		}
	}
	if os.Geteuid() != 0 {
		return &linuxTunPrerequisiteFailure{
			prerequisite: clientcontrol.PlatformTunnelPrerequisitePermission,
			message:      "linux_tun requires an elevated packaged host with permission to create TUN devices and update routes",
		}
	}
	if _, err := os.Stat("/dev/net/tun"); err != nil {
		return &linuxTunPrerequisiteFailure{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			message:      fmt.Sprintf("linux_tun requires /dev/net/tun: %v", err),
		}
	}
	if _, err := exec.LookPath("ip"); err != nil {
		return &linuxTunPrerequisiteFailure{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			message:      fmt.Sprintf("linux_tun route preparation requires iproute2: %v", err),
		}
	}
	return nil
}

func linuxTunPackagedTargetFailure(
	build clientcontrol.BuildIdentity,
	target string,
) *linuxTunPrerequisiteFailure {
	normalized := strings.ToLower(strings.TrimSpace(target))
	if normalized == linuxTunPackagedTargetUbuntu {
		return nil
	}
	message := fmt.Sprintf(
		"The %s host keeps linux_tun unavailable because support requires the repo-owned Ubuntu package/install surface.",
		hostTargetLabel(build),
	)
	if normalized != "" {
		message = fmt.Sprintf(
			"The %s host keeps linux_tun unavailable because packaged target %q is not supported; add-85 only promotes the Ubuntu package target.",
			hostTargetLabel(build),
			normalized,
		)
	}
	return &linuxTunPrerequisiteFailure{
		prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		message:      message,
	}
}

func isUbuntuHost() (bool, string) {
	values, err := readOSRelease("/etc/os-release")
	if err != nil {
		return false, fmt.Sprintf(" (could not read /etc/os-release: %v)", err)
	}
	id := strings.ToLower(strings.TrimSpace(values["ID"]))
	idLike := strings.ToLower(strings.TrimSpace(values["ID_LIKE"]))
	if id == "ubuntu" || slices.Contains(strings.Fields(idLike), "ubuntu") {
		return true, ""
	}
	if id == "" {
		return false, " (os-release ID is empty)"
	}
	return false, fmt.Sprintf(" (detected ID=%s)", id)
}

func readOSRelease(path string) (map[string]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	values := make(map[string]string)
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		values[strings.TrimSpace(key)] = strings.Trim(strings.TrimSpace(value), `"`)
	}
	return values, scanner.Err()
}

func newLinuxTunLifecycle(logger *slog.Logger) LinuxTunLifecycle {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	return &linuxTunLifecycle{
		logger:         logger,
		runner:         osLinuxCommandRunner{},
		tun:            tun.CreateTUN,
		resolvConfPath: "/etc/resolv.conf",
		probeURL:       linuxDataplaneURL,
		euid:           os.Geteuid,
		runtimeStarter: startLinuxWireGuardRuntime,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

func startLinuxWireGuardRuntime(
	ctx context.Context,
	lease *clientcontrol.WireGuardTurnExecutionLease,
	tunDevice tun.Device,
) (linuxWireGuardRuntime, error) {
	return wireguardturnruntime.Start(ctx, wireguardturnruntime.Config{
		Lease:     lease,
		TUNDevice: tunDevice,
	})
}

func (l *linuxTunLifecycle) AcquirePermission(
	_ context.Context,
	_ clientcontrol.PlatformTunnelStartRequest,
) error {
	euid := os.Geteuid
	if l.euid != nil {
		euid = l.euid
	}
	if euid() != 0 {
		return fmt.Errorf("linux_tun requires an elevated packaged host")
	}
	if l.tun == nil {
		return fmt.Errorf("linux_tun TUN factory is not configured")
	}
	tunDevice, err := l.tun(linuxTunInterfaceName, linuxTunDefaultMTU)
	if err != nil {
		return fmt.Errorf("create Linux TUN device: %w", err)
	}
	interfaceName, err := tunDevice.Name()
	if err != nil {
		_ = tunDevice.Close()
		return fmt.Errorf("query Linux TUN interface name: %w", err)
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.state != nil {
		_ = l.cleanupLocked(context.Background())
	}
	l.state = &linuxHostState{
		tunDevice:     tunDevice,
		interfaceName: strings.TrimSpace(interfaceName),
	}
	return nil
}

func (l *linuxTunLifecycle) ValidateRoutePolicy(
	ctx context.Context,
	req clientcontrol.PlatformTunnelStartRequest,
	_ *clientcontrol.RuntimeExecutionPlan,
	lease *clientcontrol.WireGuardTurnExecutionLease,
) (*linuxRoutePolicyState, error) {
	if req.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		return nil, &linuxTunRoutePolicyError{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			message: fmt.Sprintf(
				"linux_tun requires underlay_route_policy %s",
				clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			),
		}
	}
	if lease == nil {
		return nil, &linuxTunRoutePolicyError{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			message:      "linux_tun route validation requires a strict WireGuard runtime lease",
		}
	}
	underlay, err := l.queryDefaultUnderlayRoute(ctx)
	if err != nil {
		return nil, &linuxTunRoutePolicyError{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			message:      err.Error(),
		}
	}
	dnsServers, dnsErr := l.queryDNSServers(ctx, underlay.Device)
	if dnsErr != nil {
		return nil, &linuxTunRoutePolicyError{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
			message:      dnsErr.Error(),
		}
	}
	exclusions, err := resolveLinuxUnderlayRouteExclusions(ctx, lease.TURNServerAddress, dnsServers)
	if err != nil {
		prerequisite := clientcontrol.PlatformTunnelPrerequisiteRouteExclusion
		if strings.Contains(strings.ToLower(err.Error()), "dns") {
			prerequisite = clientcontrol.PlatformTunnelPrerequisiteDNSBypass
		}
		return nil, &linuxTunRoutePolicyError{
			prerequisite: prerequisite,
			message:      err.Error(),
		}
	}
	if len(exclusions) == 0 {
		return nil, &linuxTunRoutePolicyError{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			message:      "linux_tun route validation produced no underlay exclusions",
		}
	}
	l.mu.Lock()
	if l.state != nil {
		l.state.underlayDevice = underlay.Device
		l.state.underlayGateway = underlay.Gateway
		l.state.exclusions = append([]string(nil), exclusions...)
	}
	l.mu.Unlock()
	return &linuxRoutePolicyState{
		UnderlayRoutePolicy: req.UnderlayRoutePolicy,
		Exclusions:          exclusions,
	}, nil
}

func (l *linuxTunLifecycle) BringupHost(
	ctx context.Context,
	_ clientcontrol.PlatformTunnelStartRequest,
	_ *clientcontrol.RuntimeExecutionPlan,
	lease *clientcontrol.WireGuardTurnExecutionLease,
	routeState *linuxRoutePolicyState,
) error {
	state, err := l.currentState()
	if err != nil {
		return err
	}
	if routeState == nil {
		return fmt.Errorf("linux_tun host bring-up requires route policy state")
	}
	ipv4Addresses := filterLinuxIPv4CIDRs(lease.ClientAddresses)
	if len(ipv4Addresses) == 0 {
		return fmt.Errorf("linux_tun requires at least one IPv4 client address")
	}
	if err := l.runIP(ctx, "link", "set", "dev", state.interfaceName, "up", "mtu", fmt.Sprintf("%d", effectiveLinuxMTU(lease.MTU))); err != nil {
		return fmt.Errorf("bring Linux TUN interface up: %w", err)
	}
	for _, address := range ipv4Addresses {
		if err := l.runIP(ctx, "address", "replace", address, "dev", state.interfaceName); err != nil {
			return fmt.Errorf("assign Linux TUN address %s: %w", address, err)
		}
	}
	for _, destination := range []string{"0.0.0.0/1", "128.0.0.0/1"} {
		if err := l.runIP(ctx, "route", "replace", destination, "dev", state.interfaceName, "metric", "0"); err != nil {
			return fmt.Errorf("install Linux TUN split default route %s: %w", destination, err)
		}
	}
	for _, excludedHost := range routeState.Exclusions {
		args := []string{"route", "replace", excludedHost + "/32"}
		if strings.TrimSpace(state.underlayGateway) != "" {
			args = append(args, "via", state.underlayGateway)
		}
		args = append(args, "dev", state.underlayDevice, "metric", "1")
		if err := l.runIP(ctx, args...); err != nil {
			return fmt.Errorf("install Linux underlay route exclusion for %s: %w", excludedHost, err)
		}
	}
	return nil
}

func (l *linuxTunLifecycle) AttachRuntime(
	ctx context.Context,
	_ clientcontrol.PlatformTunnelStartRequest,
	_ *clientcontrol.RuntimeExecutionPlan,
	lease *clientcontrol.WireGuardTurnExecutionLease,
	_ *linuxRoutePolicyState,
) error {
	state, err := l.currentState()
	if err != nil {
		return err
	}
	if l.runtimeStarter == nil {
		return fmt.Errorf("linux_tun runtime starter is not configured")
	}
	runtime, err := l.runtimeStarter(ctx, lease, state.tunDevice)
	if err != nil {
		return err
	}
	l.mu.Lock()
	if l.state != nil {
		l.state.runtime = runtime
	}
	l.mu.Unlock()
	return nil
}

func (l *linuxTunLifecycle) VerifyDataplane(
	ctx context.Context,
	_ clientcontrol.PlatformTunnelStartRequest,
	_ *clientcontrol.RuntimeExecutionPlan,
	lease *clientcontrol.WireGuardTurnExecutionLease,
	_ *linuxRoutePolicyState,
) (*clientcontrol.PlatformTunnelDataplaneEvidence, error) {
	state, err := l.currentState()
	if err != nil {
		return nil, err
	}
	if state.runtime == nil {
		return nil, fmt.Errorf("linux_tun dataplane verification requires an attached WireGuard runtime")
	}
	beforeStats, err := state.runtime.PeerStats()
	if err != nil {
		return nil, fmt.Errorf("query WireGuard runtime stats before dataplane probe: %w", err)
	}
	remoteEgressIP, probeErr := l.queryRemoteEgressIP(ctx)
	afterStats, afterStatsErr := state.runtime.PeerStats()
	if probeErr != nil && afterStatsErr == nil && shouldRetryLinuxProbeAfterHandshake(beforeStats, afterStats) {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(200 * time.Millisecond):
		}
		beforeStats = afterStats
		remoteEgressIP, probeErr = l.queryRemoteEgressIP(ctx)
		afterStats, afterStatsErr = state.runtime.PeerStats()
	}
	if probeErr != nil {
		return nil, fmt.Errorf(
			"run linux_tun data-plane probe: %w (wireguard_before_rx=%d wireguard_before_tx=%d wireguard_before_handshake=%s)",
			probeErr,
			beforeStats.RxBytes,
			beforeStats.TxBytes,
			beforeStats.LastHandshakeTime.UTC().Format(time.RFC3339Nano),
		)
	}
	if afterStatsErr != nil {
		return nil, fmt.Errorf("query WireGuard runtime stats after dataplane probe: %w", afterStatsErr)
	}
	expectedEgressIP := expectedLinuxEgressIPFromEndpoint(lease.PeerEndpointAddress)
	wgRxDelta := afterStats.RxBytes - beforeStats.RxBytes
	wgTxDelta := afterStats.TxBytes - beforeStats.TxBytes
	handshakeFresh := linuxWireGuardHandshakeIsFresh(afterStats.LastHandshakeTime, time.Now().UTC())
	egressMatches := expectedEgressIP == "" || strings.TrimSpace(remoteEgressIP) == expectedEgressIP
	evidence := &clientcontrol.PlatformTunnelDataplaneEvidence{
		HostAttached:                 true,
		WireGuardHandshakeFresh:      handshakeFresh,
		WireGuardRxBytesDelta:        wgRxDelta,
		WireGuardTxBytesDelta:        wgTxDelta,
		RemoteEgressIP:               strings.TrimSpace(remoteEgressIP),
		ExpectedRemoteEgressIP:       expectedEgressIP,
		BidirectionalTrafficVerified: handshakeFresh && wgRxDelta > 0 && wgTxDelta > 0 && egressMatches,
	}
	if !evidence.BidirectionalTrafficVerified {
		return evidence, fmt.Errorf(
			"linux_tun dataplane evidence incomplete: handshake_fresh=%t wireguard_rx_delta=%d wireguard_tx_delta=%d remote_egress_ip=%q expected_remote_egress_ip=%q",
			evidence.WireGuardHandshakeFresh,
			evidence.WireGuardRxBytesDelta,
			evidence.WireGuardTxBytesDelta,
			evidence.RemoteEgressIP,
			evidence.ExpectedRemoteEgressIP,
		)
	}
	return evidence, nil
}

func (l *linuxTunLifecycle) Cleanup(ctx context.Context) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.cleanupLocked(ctx)
}

func (l *linuxTunLifecycle) cleanupLocked(ctx context.Context) error {
	if l.state == nil {
		return nil
	}
	state := l.state
	l.state = nil
	var errs []error
	if strings.TrimSpace(state.interfaceName) != "" {
		for _, destination := range []string{"0.0.0.0/1", "128.0.0.0/1"} {
			if err := l.runIP(ctx, "route", "del", destination, "dev", state.interfaceName); err != nil {
				errs = append(errs, fmt.Errorf("remove Linux TUN route %s: %w", destination, err))
			}
		}
		for _, excludedHost := range state.exclusions {
			args := []string{"route", "del", excludedHost + "/32"}
			if strings.TrimSpace(state.underlayGateway) != "" {
				args = append(args, "via", state.underlayGateway)
			}
			args = append(args, "dev", state.underlayDevice)
			if err := l.runIP(ctx, args...); err != nil {
				errs = append(errs, fmt.Errorf("remove Linux underlay route exclusion %s: %w", excludedHost, err))
			}
		}
		if err := l.runIP(ctx, "address", "flush", "dev", state.interfaceName); err != nil {
			errs = append(errs, fmt.Errorf("flush Linux TUN addresses: %w", err))
		}
		if err := l.runIP(ctx, "link", "set", "dev", state.interfaceName, "down"); err != nil {
			errs = append(errs, fmt.Errorf("set Linux TUN interface down: %w", err))
		}
	}
	if state.runtime != nil {
		if err := state.runtime.Close(); err != nil {
			errs = append(errs, err)
		}
	}
	if state.tunDevice != nil {
		if err := state.tunDevice.Close(); err != nil && !errors.Is(err, os.ErrClosed) {
			errs = append(errs, err)
		}
	}
	return errors.Join(filterCleanupErrors(errs)...)
}

func filterCleanupErrors(errs []error) []error {
	out := make([]error, 0, len(errs))
	for _, err := range errs {
		if err == nil {
			continue
		}
		message := strings.ToLower(err.Error())
		if strings.Contains(message, "cannot find device") ||
			strings.Contains(message, "no such process") ||
			strings.Contains(message, "no such file or directory") {
			continue
		}
		out = append(out, err)
	}
	return out
}

func (l *linuxTunLifecycle) currentState() (*linuxHostState, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.state == nil || l.state.tunDevice == nil || strings.TrimSpace(l.state.interfaceName) == "" {
		return nil, fmt.Errorf("linux_tun lifecycle does not have an active TUN interface")
	}
	clone := *l.state
	if len(l.state.exclusions) > 0 {
		clone.exclusions = append([]string(nil), l.state.exclusions...)
	}
	return &clone, nil
}

func (l *linuxTunLifecycle) queryDefaultUnderlayRoute(ctx context.Context) (*linuxDefaultRoute, error) {
	output, err := l.runIPOutput(ctx, "-4", "route", "show", "default")
	if err != nil {
		return nil, err
	}
	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	for scanner.Scan() {
		route, ok := parseLinuxDefaultRoute(scanner.Text())
		if ok {
			return route, nil
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return nil, fmt.Errorf("active IPv4 default route not found")
}

func parseLinuxDefaultRoute(line string) (*linuxDefaultRoute, bool) {
	fields := strings.Fields(line)
	if len(fields) == 0 || fields[0] != "default" {
		return nil, false
	}
	route := &linuxDefaultRoute{}
	for i := 1; i < len(fields); i++ {
		switch fields[i] {
		case "via":
			if i+1 < len(fields) {
				route.Gateway = fields[i+1]
				i++
			}
		case "dev":
			if i+1 < len(fields) {
				route.Device = fields[i+1]
				i++
			}
		}
	}
	return route, strings.TrimSpace(route.Device) != ""
}

func (l *linuxTunLifecycle) queryDNSServers(ctx context.Context, device string) ([]string, error) {
	var servers []string
	if strings.TrimSpace(device) != "" {
		if output, err := l.runCommandOutput(ctx, "resolvectl", "dns", device); err == nil {
			servers = append(servers, parseResolvectlDNSServers(string(output))...)
		}
	}
	fromFile, err := parseResolvConf(l.resolvConfPath)
	servers = append(servers, fromFile...)
	servers = dedupeLinuxStrings(filterNonLoopbackIPv4Strings(servers))
	if len(servers) == 0 {
		if err != nil {
			return nil, err
		}
		return nil, fmt.Errorf("DNS bypass requires at least one non-loopback IPv4 DNS server")
	}
	return servers, nil
}

func parseResolvectlDNSServers(output string) []string {
	fields := strings.Fields(output)
	out := make([]string, 0, len(fields))
	for _, field := range fields {
		field = strings.Trim(field, ",")
		if addr, err := netip.ParseAddr(field); err == nil && addr.Is4() {
			out = append(out, addr.String())
		}
	}
	return out
}

func parseResolvConf(path string) ([]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	var servers []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())
		if len(fields) >= 2 && fields[0] == "nameserver" {
			servers = append(servers, fields[1])
		}
	}
	return servers, scanner.Err()
}

func resolveLinuxUnderlayRouteExclusions(ctx context.Context, turnServerAddress string, dnsServers []string) ([]string, error) {
	hosts := make([]string, 0, 1+len(dnsServers))
	turnHosts, err := resolveLinuxIPv4Hosts(ctx, turnServerAddress)
	if err != nil {
		return nil, fmt.Errorf("route exclusion for TURN underlay failed: %w", err)
	}
	hosts = append(hosts, turnHosts...)
	for _, dnsServer := range dnsServers {
		if addr, err := netip.ParseAddr(strings.TrimSpace(dnsServer)); err == nil && addr.Is4() {
			hosts = append(hosts, addr.String())
		}
	}
	hosts = dedupeLinuxStrings(hosts)
	if len(hosts) == 0 {
		return nil, fmt.Errorf("route exclusion requires at least one IPv4 underlay host")
	}
	return hosts, nil
}

func resolveLinuxIPv4Hosts(ctx context.Context, address string) ([]string, error) {
	host := strings.TrimSpace(address)
	if host == "" {
		return nil, fmt.Errorf("turn_server_address is empty")
	}
	if parsedHost, _, err := net.SplitHostPort(host); err == nil {
		host = parsedHost
	}
	if ip, err := netip.ParseAddr(host); err == nil {
		if !ip.Is4() {
			return nil, fmt.Errorf("turn_server_address %q is not IPv4", address)
		}
		return []string{ip.String()}, nil
	}
	results, err := net.DefaultResolver.LookupIP(ctx, "ip4", host)
	if err != nil {
		return nil, err
	}
	out := make([]string, 0, len(results))
	for _, result := range results {
		if result == nil {
			continue
		}
		addr, ok := netip.AddrFromSlice(result)
		if !ok || !addr.Is4() {
			continue
		}
		out = append(out, addr.String())
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("turn_server_address %q did not resolve to an IPv4 host", address)
	}
	return dedupeLinuxStrings(out), nil
}

func (l *linuxTunLifecycle) queryRemoteEgressIP(ctx context.Context) (string, error) {
	if l.httpClient == nil {
		return "", fmt.Errorf("linux_tun dataplane HTTP client is not configured")
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, firstNonEmpty(l.probeURL, linuxDataplaneURL), nil)
	if err != nil {
		return "", err
	}
	resp, err := l.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("probe returned status %s", resp.Status)
	}
	limited := io.LimitReader(resp.Body, 4096)
	scanner := bufio.NewScanner(limited)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if value, ok := strings.CutPrefix(line, "ip="); ok {
			value = strings.TrimSpace(value)
			if value != "" {
				return value, nil
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}
	return "", fmt.Errorf("linux_tun data-plane probe trace response did not include ip=")
}

func (l *linuxTunLifecycle) runIP(ctx context.Context, args ...string) error {
	_, err := l.runIPOutput(ctx, args...)
	return err
}

func (l *linuxTunLifecycle) runIPOutput(ctx context.Context, args ...string) ([]byte, error) {
	return l.runCommandOutput(ctx, "ip", args...)
}

func (l *linuxTunLifecycle) runCommandOutput(ctx context.Context, name string, args ...string) ([]byte, error) {
	if l.runner == nil {
		return nil, fmt.Errorf("linux_tun command runner is not configured")
	}
	return l.runner.Run(ctx, name, args...)
}

func effectiveLinuxMTU(value int) int {
	if value > 0 {
		return value
	}
	return linuxTunDefaultMTU
}

func filterLinuxIPv4CIDRs(values []string) []string {
	out := make([]string, 0, len(values))
	for _, value := range values {
		prefix, err := netip.ParsePrefix(strings.TrimSpace(value))
		if err != nil || !prefix.Addr().Is4() {
			continue
		}
		out = append(out, prefix.String())
	}
	return dedupeLinuxStrings(out)
}

func filterNonLoopbackIPv4Strings(values []string) []string {
	out := make([]string, 0, len(values))
	for _, value := range values {
		addr, err := netip.ParseAddr(strings.TrimSpace(value))
		if err != nil || !addr.Is4() || addr.IsLoopback() {
			continue
		}
		out = append(out, addr.String())
	}
	return out
}

func dedupeLinuxStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" || slices.Contains(out, value) {
			continue
		}
		out = append(out, value)
	}
	sort.Strings(out)
	return out
}

func expectedLinuxEgressIPFromEndpoint(endpoint string) string {
	host := strings.TrimSpace(endpoint)
	if parsedHost, _, err := net.SplitHostPort(host); err == nil {
		host = parsedHost
	}
	if parsed := net.ParseIP(host); parsed != nil && parsed.To4() != nil {
		return parsed.String()
	}
	return ""
}

func shouldRetryLinuxProbeAfterHandshake(
	before wireguardturnruntime.PeerStats,
	after wireguardturnruntime.PeerStats,
) bool {
	if linuxWireGuardHandshakeIsFresh(before.LastHandshakeTime, time.Now().UTC()) {
		return false
	}
	if !linuxWireGuardHandshakeIsFresh(after.LastHandshakeTime, time.Now().UTC()) {
		return false
	}
	return after.TxBytes > before.TxBytes || after.RxBytes > before.RxBytes
}

func linuxWireGuardHandshakeIsFresh(handshake time.Time, now time.Time) bool {
	if handshake.IsZero() {
		return false
	}
	if now.IsZero() {
		now = time.Now().UTC()
	}
	age := now.Sub(handshake.UTC())
	return age >= -5*time.Second && age <= 2*time.Minute
}
