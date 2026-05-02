//go:build windows

package windowsdesktophost

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/netip"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/wireguardturnruntime"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
	"golang.org/x/sys/windows"
	"golang.zx2c4.com/wireguard/tun"
)

const windowsWintunAdapterName = "RelayDock Wintun"

type windowsHostState struct {
	tunDevice            tun.Device
	interfaceAlias       string
	underlayInterfaceIdx int
	underlayNextHop      string
	exclusions           []string
	runtime              *wireguardturnruntime.Runtime
}

type windowsWintunLifecycle struct {
	logger *slog.Logger

	mu    sync.Mutex
	state *windowsHostState
}

type powershellQueryResult struct {
	InterfaceIndex int      `json:"interface_index"`
	InterfaceAlias string   `json:"interface_alias"`
	NextHop        string   `json:"next_hop"`
	DNSServers     []string `json:"dns_servers"`
}

type windowsDataplaneProbeResult struct {
	RemoteEgressIP            string `json:"remote_egress_ip"`
	WintunReceivedBytesBefore int64  `json:"wintun_received_bytes_before"`
	WintunReceivedBytesAfter  int64  `json:"wintun_received_bytes_after"`
}

func newWindowsWintunLifecycle(logger *slog.Logger) WindowsWintunLifecycle {
	return &windowsWintunLifecycle{logger: logger}
}

func currentWindowsWintunCapability(
	build clientcontrol.BuildIdentity,
	materializerErr error,
) clientcontrol.PlatformTunnelCapability {
	capability := supportedWindowsWintunCapability("packaged Windows host owns windows_wintun startup")
	if elevated, err := isProcessElevated(); err != nil {
		return unavailableWindowsWintunCapability(
			build,
			clientcontrol.PlatformTunnelPrerequisiteDriver,
			fmt.Sprintf("windows_wintun prerequisite check failed: %v", err),
		)
	} else if !elevated {
		return unavailableWindowsWintunCapability(
			build,
			clientcontrol.PlatformTunnelPrerequisiteDriver,
			"windows_wintun requires an elevated desktop host",
		)
	}
	if _, err := findWintunDLL(); err != nil {
		return unavailableWindowsWintunCapability(
			build,
			clientcontrol.PlatformTunnelPrerequisiteDriver,
			fmt.Sprintf(
				"The %s host is missing the packaged Wintun DLL required for mode %s: %v",
				firstNonEmpty(strings.TrimSpace(build.Target), "windows/amd64"),
				clientcontrol.PlatformTunnelModeWindowsWintun,
				err,
			),
		)
	}
	if materializerErr != nil {
		return materializerUnavailableWindowsWintunCapability(build, materializerErr)
	}
	return capability
}

func (l *windowsWintunLifecycle) CheckDriver(
	_ context.Context,
	_ clientcontrol.PlatformTunnelStartRequest,
) error {
	elevated, err := isProcessElevated()
	if err != nil {
		return err
	}
	if !elevated {
		return fmt.Errorf("windows_wintun requires an elevated desktop host")
	}
	if _, err := findWintunDLL(); err != nil {
		return fmt.Errorf("Wintun DLL is unavailable next to the bundled host: %w", err)
	}
	tunDevice, err := tun.CreateTUN(windowsWintunAdapterName, 1280)
	if err != nil {
		return fmt.Errorf("create Wintun adapter: %w", err)
	}
	interfaceAlias, err := tunDevice.Name()
	if err != nil {
		_ = tunDevice.Close()
		return fmt.Errorf("query Wintun adapter name: %w", err)
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.state != nil {
		_ = l.cleanupLocked(context.Background())
	}
	l.state = &windowsHostState{
		tunDevice:      tunDevice,
		interfaceAlias: strings.TrimSpace(interfaceAlias),
	}
	return nil
}

func (l *windowsWintunLifecycle) ValidateRoutePolicy(
	ctx context.Context,
	req clientcontrol.PlatformTunnelStartRequest,
	_ *clientcontrol.RuntimeExecutionPlan,
	lease *clientcontrol.WireGuardTurnExecutionLease,
) (*windowsRoutePolicyState, error) {
	if req.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		return nil, &windowsWintunRoutePolicyError{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			message: fmt.Sprintf(
				"windows_wintun requires underlay_route_policy %s",
				clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			),
		}
	}
	if lease == nil {
		return nil, &windowsWintunRoutePolicyError{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			message:      "windows_wintun route validation requires a strict WireGuard runtime lease",
		}
	}
	underlay, err := queryDefaultUnderlayRoute(ctx)
	if err != nil {
		return nil, &windowsWintunRoutePolicyError{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			message:      err.Error(),
		}
	}
	exclusions, err := resolveUnderlayRouteExclusions(ctx, lease.TURNServerAddress, underlay.DNSServers)
	if err != nil {
		prerequisite := clientcontrol.PlatformTunnelPrerequisiteRouteExclusion
		if strings.Contains(strings.ToLower(err.Error()), "dns") {
			prerequisite = clientcontrol.PlatformTunnelPrerequisiteDNSBypass
		}
		return nil, &windowsWintunRoutePolicyError{
			prerequisite: prerequisite,
			message:      err.Error(),
		}
	}
	if len(exclusions) == 0 {
		return nil, &windowsWintunRoutePolicyError{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			message:      "windows_wintun route validation produced no underlay exclusions",
		}
	}
	l.mu.Lock()
	if l.state != nil {
		l.state.underlayInterfaceIdx = underlay.InterfaceIndex
		l.state.underlayNextHop = underlay.NextHop
		l.state.exclusions = append([]string(nil), exclusions...)
	}
	l.mu.Unlock()
	return &windowsRoutePolicyState{
		UnderlayRoutePolicy: req.UnderlayRoutePolicy,
		Exclusions:          exclusions,
	}, nil
}

func (l *windowsWintunLifecycle) BringupHost(
	ctx context.Context,
	_ clientcontrol.PlatformTunnelStartRequest,
	_ *clientcontrol.RuntimeExecutionPlan,
	lease *clientcontrol.WireGuardTurnExecutionLease,
	routeState *windowsRoutePolicyState,
) error {
	state, err := l.currentState()
	if err != nil {
		return err
	}
	ipv4Addresses := filterIPv4CIDRs(lease.ClientAddresses)
	if len(ipv4Addresses) == 0 {
		return fmt.Errorf("windows_wintun requires at least one IPv4 client address")
	}
	payload := map[string]any{
		"interface_alias":          state.interfaceAlias,
		"client_addresses":         ipv4Addresses,
		"underlay_interface_index": state.underlayInterfaceIdx,
		"underlay_next_hop":        state.underlayNextHop,
		"exclusions":               routeState.Exclusions,
	}
	script := `
$ErrorActionPreference = 'Stop'
$req = $env:VKTP_PS_REQUEST | ConvertFrom-Json
$splitRoutes = @('0.0.0.0/1', '128.0.0.0/1')
Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $req.interface_alias -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
foreach ($cidr in $req.client_addresses) {
  $parts = $cidr -split '/'
  if ($parts.Length -ne 2) { throw "invalid client address $cidr" }
  $ip = $parts[0]
  $prefix = [int]$parts[1]
  New-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $req.interface_alias -IPAddress $ip -PrefixLength $prefix -Type Unicast | Out-Null
}
Set-NetIPInterface -AddressFamily IPv4 -InterfaceAlias $req.interface_alias -InterfaceMetric 1 | Out-Null
foreach ($route in $splitRoutes) {
  if (-not (Get-NetRoute -AddressFamily IPv4 -InterfaceAlias $req.interface_alias -DestinationPrefix $route -ErrorAction SilentlyContinue)) {
    New-NetRoute -AddressFamily IPv4 -InterfaceAlias $req.interface_alias -DestinationPrefix $route -NextHop '0.0.0.0' -RouteMetric 0 -PolicyStore ActiveStore | Out-Null
  }
}
foreach ($excludedHost in @($req.exclusions)) {
  $destination = "$excludedHost/32"
  if (-not (Get-NetRoute -AddressFamily IPv4 -InterfaceIndex $req.underlay_interface_index -DestinationPrefix $destination -ErrorAction SilentlyContinue | Where-Object { $_.NextHop -eq $req.underlay_next_hop })) {
    New-NetRoute -AddressFamily IPv4 -InterfaceIndex $req.underlay_interface_index -DestinationPrefix $destination -NextHop $req.underlay_next_hop -RouteMetric 1 -PolicyStore ActiveStore | Out-Null
  }
}
`
	if _, err := runPowerShellJSON(ctx, payload, script); err != nil {
		return fmt.Errorf("configure Wintun interface: %w", err)
	}
	return nil
}

func (l *windowsWintunLifecycle) AttachRuntime(
	ctx context.Context,
	_ clientcontrol.PlatformTunnelStartRequest,
	_ *clientcontrol.RuntimeExecutionPlan,
	lease *clientcontrol.WireGuardTurnExecutionLease,
	_ *windowsRoutePolicyState,
) error {
	state, err := l.currentState()
	if err != nil {
		return err
	}
	runtime, err := wireguardturnruntime.Start(ctx, wireguardturnruntime.Config{
		Lease:     lease,
		TUNDevice: state.tunDevice,
	})
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

func (l *windowsWintunLifecycle) VerifyDataplane(
	ctx context.Context,
	_ clientcontrol.PlatformTunnelStartRequest,
	_ *clientcontrol.RuntimeExecutionPlan,
	lease *clientcontrol.WireGuardTurnExecutionLease,
	_ *windowsRoutePolicyState,
) (*clientcontrol.PlatformTunnelDataplaneEvidence, error) {
	state, err := l.currentState()
	if err != nil {
		return nil, err
	}
	if state.runtime == nil {
		return nil, fmt.Errorf("windows_wintun dataplane verification requires an attached WireGuard runtime")
	}
	beforeStats, err := state.runtime.PeerStats()
	if err != nil {
		return nil, fmt.Errorf("query WireGuard runtime stats before dataplane probe: %w", err)
	}
	probe, err := queryWindowsWintunDataplaneProbe(ctx, state.interfaceAlias)
	if err != nil {
		return nil, fmt.Errorf("run Wintun data-plane probe: %w", err)
	}
	afterStats, err := state.runtime.PeerStats()
	if err != nil {
		return nil, fmt.Errorf("query WireGuard runtime stats after dataplane probe: %w", err)
	}

	expectedEgressIP := expectedEgressIPFromEndpoint(lease.PeerEndpointAddress)
	wgRxDelta := afterStats.RxBytes - beforeStats.RxBytes
	wgTxDelta := afterStats.TxBytes - beforeStats.TxBytes
	wintunRxDelta := probe.WintunReceivedBytesAfter - probe.WintunReceivedBytesBefore
	handshakeFresh := wireGuardHandshakeIsFresh(afterStats.LastHandshakeTime, time.Now().UTC())
	egressMatches := expectedEgressIP == "" || strings.TrimSpace(probe.RemoteEgressIP) == expectedEgressIP
	evidence := &clientcontrol.PlatformTunnelDataplaneEvidence{
		HostAttached:                 true,
		WireGuardHandshakeFresh:      handshakeFresh,
		WireGuardRxBytesDelta:        wgRxDelta,
		WireGuardTxBytesDelta:        wgTxDelta,
		WintunReceivedBytesDelta:     wintunRxDelta,
		RemoteEgressIP:               strings.TrimSpace(probe.RemoteEgressIP),
		ExpectedRemoteEgressIP:       expectedEgressIP,
		BidirectionalTrafficVerified: handshakeFresh && wgRxDelta > 0 && wgTxDelta > 0 && wintunRxDelta > 0 && egressMatches,
	}
	if !evidence.BidirectionalTrafficVerified {
		return evidence, fmt.Errorf(
			"windows_wintun dataplane evidence incomplete: handshake_fresh=%t wireguard_rx_delta=%d wireguard_tx_delta=%d wintun_received_bytes_delta=%d remote_egress_ip=%q expected_remote_egress_ip=%q",
			evidence.WireGuardHandshakeFresh,
			evidence.WireGuardRxBytesDelta,
			evidence.WireGuardTxBytesDelta,
			evidence.WintunReceivedBytesDelta,
			evidence.RemoteEgressIP,
			evidence.ExpectedRemoteEgressIP,
		)
	}
	return evidence, nil
}

func (l *windowsWintunLifecycle) Cleanup(ctx context.Context) error {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.cleanupLocked(ctx)
}

func (l *windowsWintunLifecycle) cleanupLocked(ctx context.Context) error {
	if l.state == nil {
		return nil
	}
	state := l.state
	l.state = nil
	var errs []error
	if strings.TrimSpace(state.interfaceAlias) != "" {
		payload := map[string]any{
			"interface_alias":          state.interfaceAlias,
			"underlay_interface_index": state.underlayInterfaceIdx,
			"underlay_next_hop":        state.underlayNextHop,
			"exclusions":               state.exclusions,
		}
		script := `
$ErrorActionPreference = 'Stop'
$req = $env:VKTP_PS_REQUEST | ConvertFrom-Json
foreach ($route in @('0.0.0.0/1', '128.0.0.0/1')) {
  Get-NetRoute -AddressFamily IPv4 -InterfaceAlias $req.interface_alias -DestinationPrefix $route -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
}
foreach ($excludedHost in @($req.exclusions)) {
  $destination = "$excludedHost/32"
  Get-NetRoute -AddressFamily IPv4 -InterfaceIndex $req.underlay_interface_index -DestinationPrefix $destination -ErrorAction SilentlyContinue |
    Where-Object { $_.NextHop -eq $req.underlay_next_hop } |
    Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
}
Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $req.interface_alias -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
`
		if _, err := runPowerShellJSON(ctx, payload, script); err != nil {
			errs = append(errs, fmt.Errorf("cleanup Wintun interface: %w", err))
		}
	}
	if state.runtime != nil {
		if err := state.runtime.Close(); err != nil {
			errs = append(errs, err)
		}
		state.tunDevice = nil
	}
	if state.tunDevice != nil {
		if err := state.tunDevice.Close(); err != nil {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}

func (l *windowsWintunLifecycle) currentState() (*windowsHostState, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.state == nil || l.state.tunDevice == nil || strings.TrimSpace(l.state.interfaceAlias) == "" {
		return nil, fmt.Errorf("windows_wintun lifecycle does not have an active adapter")
	}
	clone := *l.state
	if len(l.state.exclusions) > 0 {
		clone.exclusions = append([]string(nil), l.state.exclusions...)
	}
	return &clone, nil
}

func isProcessElevated() (bool, error) {
	adminSID, err := windows.CreateWellKnownSid(windows.WinBuiltinAdministratorsSid)
	if err != nil {
		return false, err
	}
	token := windows.Token(0)
	return token.IsMember(adminSID)
}

func queryDefaultUnderlayRoute(ctx context.Context) (*powershellQueryResult, error) {
	script := `
$ErrorActionPreference = 'Stop'
$route = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
  Where-Object { -not [string]::IsNullOrWhiteSpace($_.NextHop) -and $_.NextHop -ne '0.0.0.0' } |
  Sort-Object RouteMetric, InterfaceMetric |
  Select-Object -First 1 InterfaceIndex, InterfaceAlias, NextHop
if ($null -eq $route) { throw 'active IPv4 default route not found' }
$dns = @(Get-DnsClientServerAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty ServerAddresses)
[pscustomobject]@{
  interface_index = [int]$route.InterfaceIndex
  interface_alias = [string]$route.InterfaceAlias
  next_hop = [string]$route.NextHop
  dns_servers = @($dns | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
} | ConvertTo-Json -Compress
`
	output, err := runPowerShellJSON(ctx, nil, script)
	if err != nil {
		return nil, err
	}
	var result powershellQueryResult
	if err := json.Unmarshal(output, &result); err != nil {
		return nil, fmt.Errorf("decode default underlay route: %w", err)
	}
	if strings.TrimSpace(result.NextHop) == "" {
		return nil, fmt.Errorf("default underlay route is missing next hop")
	}
	return &result, nil
}

func queryWindowsWintunDataplaneProbe(ctx context.Context, interfaceAlias string) (*windowsDataplaneProbeResult, error) {
	payload := map[string]any{
		"interface_alias": strings.TrimSpace(interfaceAlias),
		"probe_url":       "https://api.ipify.org",
		"timeout_seconds": 15,
	}
	script := `
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$req = $env:VKTP_PS_REQUEST | ConvertFrom-Json
function Get-WintunReceivedBytes {
  $stats = Get-NetAdapterStatistics -Name $req.interface_alias -ErrorAction Stop
  return [int64]$stats.ReceivedBytes
}
$before = Get-WintunReceivedBytes
$client = [System.Net.Http.HttpClient]::new()
try {
  $client.Timeout = [TimeSpan]::FromSeconds([int]$req.timeout_seconds)
  $remoteEgressIp = $client.GetStringAsync([string]$req.probe_url).GetAwaiter().GetResult().Trim()
} finally {
  $client.Dispose()
}
Start-Sleep -Milliseconds 250
$after = Get-WintunReceivedBytes
[pscustomobject]@{
  remote_egress_ip = [string]$remoteEgressIp
  wintun_received_bytes_before = [int64]$before
  wintun_received_bytes_after = [int64]$after
} | ConvertTo-Json -Compress
`
	output, err := runPowerShellJSON(ctx, payload, script)
	if err != nil {
		return nil, err
	}
	var result windowsDataplaneProbeResult
	if err := json.Unmarshal(output, &result); err != nil {
		return nil, fmt.Errorf("decode Wintun data-plane probe: %w", err)
	}
	if strings.TrimSpace(result.RemoteEgressIP) == "" {
		return nil, fmt.Errorf("Wintun data-plane probe returned empty remote egress IP")
	}
	return &result, nil
}

func expectedEgressIPFromEndpoint(endpoint string) string {
	host := strings.TrimSpace(endpoint)
	if parsedHost, _, err := net.SplitHostPort(host); err == nil {
		host = parsedHost
	}
	if parsed := net.ParseIP(host); parsed != nil && parsed.To4() != nil {
		return parsed.String()
	}
	return ""
}

func wireGuardHandshakeIsFresh(handshake time.Time, now time.Time) bool {
	if handshake.IsZero() {
		return false
	}
	if now.IsZero() {
		now = time.Now().UTC()
	}
	age := now.Sub(handshake.UTC())
	return age >= -5*time.Second && age <= 2*time.Minute
}

func resolveUnderlayRouteExclusions(ctx context.Context, turnServerAddress string, dnsServers []string) ([]string, error) {
	hosts := make([]string, 0, 1+len(dnsServers))
	turnHosts, err := resolveIPv4Hosts(ctx, turnServerAddress)
	if err != nil {
		return nil, fmt.Errorf("route exclusion for TURN underlay failed: %w", err)
	}
	hosts = append(hosts, turnHosts...)
	if len(dnsServers) == 0 {
		return nil, fmt.Errorf("DNS bypass requires at least one IPv4 DNS server on the active underlay")
	}
	for _, dnsServer := range dnsServers {
		if addr, err := netip.ParseAddr(strings.TrimSpace(dnsServer)); err == nil && addr.Is4() {
			hosts = append(hosts, addr.String())
		}
	}
	hosts = dedupeStrings(hosts)
	if len(hosts) == 0 {
		return nil, fmt.Errorf("route exclusion requires at least one IPv4 underlay host")
	}
	return hosts, nil
}

func resolveIPv4Hosts(ctx context.Context, address string) ([]string, error) {
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
	return dedupeStrings(out), nil
}

func filterIPv4CIDRs(values []string) []string {
	out := make([]string, 0, len(values))
	for _, value := range values {
		prefix, err := netip.ParsePrefix(strings.TrimSpace(value))
		if err != nil || !prefix.Addr().Is4() {
			continue
		}
		out = append(out, prefix.String())
	}
	return dedupeStrings(out)
}

func dedupeStrings(values []string) []string {
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

func runPowerShellJSON(ctx context.Context, payload any, script string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script)
	if payload != nil {
		encoded, err := json.Marshal(payload)
		if err != nil {
			return nil, err
		}
		cmd.Env = append(os.Environ(), "VKTP_PS_REQUEST="+string(encoded))
	}
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("%v: %s", err, strings.TrimSpace(string(output)))
	}
	return output, nil
}

func findWintunDLL() (string, error) {
	exePath, err := os.Executable()
	if err != nil {
		return "", err
	}
	dllPath := filepath.Join(filepath.Dir(exePath), "wintun.dll")
	if _, err := os.Stat(dllPath); err != nil {
		return "", err
	}
	return dllPath, nil
}
