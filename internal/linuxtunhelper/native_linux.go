//go:build linux

package linuxtunhelper

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/netip"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"slices"
	"sort"
	"strings"
	"syscall"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/wireguardturnruntime"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
	"golang.zx2c4.com/wireguard/tun"
)

const (
	nativeInterfaceName     = "rdtun0"
	nativeDefaultMTU        = 1280
	nativeDataplaneURL      = "https://1.1.1.1/cdn-cgi/trace"
	nativeStateDirEnv       = "VKTP_LINUX_TUN_HELPER_STATE_DIR"
	defaultNativeStateDir   = "/run/relaydock/linux-tun-helper"
	nativeStateFileName     = "state.json"
	nativeLockFileName      = "lock"
	nativeCleanupTimeout    = 10 * time.Second
	nativeStatePollInterval = 200 * time.Millisecond
)

var nativeCleanupRunner nativeCommandRunner = osNativeCommandRunner{}

type nativeCommandRunner interface {
	Run(context.Context, string, ...string) ([]byte, error)
}

type osNativeCommandRunner struct{}

func (osNativeCommandRunner) Run(ctx context.Context, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return output, fmt.Errorf("%s %s: %v: %s", name, strings.Join(args, " "), err, strings.TrimSpace(string(output)))
	}
	return output, nil
}

type nativeWireGuardRuntime interface {
	PeerStats() (wireguardturnruntime.PeerStats, error)
	Close() error
}

type nativeRuntimeStarter func(context.Context, *clientcontrol.WireGuardTurnExecutionLease, tun.Device) (nativeWireGuardRuntime, error)

type nativeHostState struct {
	tunDevice       tun.Device
	interfaceName   string
	underlayDevice  string
	underlayGateway string
	exclusions      []string
	runtime         nativeWireGuardRuntime
}

type nativeStateSnapshot struct {
	InterfaceName   string   `json:"interface_name,omitempty"`
	UnderlayDevice  string   `json:"underlay_device,omitempty"`
	UnderlayGateway string   `json:"underlay_gateway,omitempty"`
	Exclusions      []string `json:"exclusions,omitempty"`
}

type nativeAttemptState struct {
	ProtocolVersion int       `json:"protocol_version"`
	HelperIdentity  string    `json:"helper_identity"`
	AttemptID       string    `json:"attempt_id"`
	AttemptNonce    string    `json:"attempt_nonce"`
	HelperPID       int       `json:"helper_pid"`
	HostPID         int       `json:"host_pid"`
	InterfaceName   string    `json:"interface_name,omitempty"`
	UnderlayDevice  string    `json:"underlay_device,omitempty"`
	UnderlayGateway string    `json:"underlay_gateway,omitempty"`
	Exclusions      []string  `json:"exclusions,omitempty"`
	UpdatedAt       time.Time `json:"updated_at"`
}

type nativeDefaultRoute struct {
	Device  string
	Gateway string
}

type nativeRoutePolicyState struct {
	UnderlayRoutePolicy clientcontrol.PlatformTunnelUnderlayRoutePolicy
	Exclusions          []string
}

type nativeLifecycle struct {
	runner         nativeCommandRunner
	tun            func(string, int) (tun.Device, error)
	resolvConfPath string
	probeURL       string
	httpClient     *http.Client
	euid           func() int
	runtimeStarter nativeRuntimeStarter
	onState        func(nativeStateSnapshot)

	state *nativeHostState
}

type nativeStartError struct {
	code         string
	stage        clientcontrol.PlatformTunnelStartupStage
	prerequisite clientcontrol.PlatformTunnelPrerequisite
	err          error
}

func (e *nativeStartError) Error() string {
	if e == nil || e.err == nil {
		return ""
	}
	return e.err.Error()
}

func defaultStartNativeAttempt(stdout io.Writer, req StartRequest) int {
	if os.Geteuid() != 0 {
		writeNativeError(stdout, req, &nativeStartError{
			code:         "permission_denied",
			stage:        clientcontrol.PlatformTunnelStartupStagePermissionAcquire,
			prerequisite: clientcontrol.PlatformTunnelPrerequisitePermission,
			err:          fmt.Errorf("linux_tun helper requires root privileges"),
		})
		return exitNativeFailure
	}

	manager := newNativeStateManager()
	if err := manager.prepareStart(req); err != nil {
		writeNativeError(stdout, req, err)
		return exitNativeFailure
	}

	lifecycle := newNativeLifecycle(func(snapshot nativeStateSnapshot) {
		_ = manager.update(req, snapshot)
	})
	result, err := lifecycle.Start(context.Background(), req)
	if err != nil {
		cleanupCtx, cancel := context.WithTimeout(context.Background(), nativeCleanupTimeout)
		_ = lifecycle.Cleanup(cleanupCtx)
		cancel()
		_ = manager.removeIfAttempt(req.AttemptID, req.AttemptNonce)
		writeNativeError(stdout, req, err)
		return exitNativeFailure
	}
	if err := manager.update(req, lifecycle.snapshot()); err != nil {
		cleanupCtx, cancel := context.WithTimeout(context.Background(), nativeCleanupTimeout)
		cleanupErr := lifecycle.Cleanup(cleanupCtx)
		cancel()
		_ = manager.removeIfAttempt(req.AttemptID, req.AttemptNonce)
		writeNativeError(stdout, req, &nativeStartError{
			code:         "cleanup_failed",
			stage:        clientcontrol.PlatformTunnelStartupStageHostBringup,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			err:          errors.Join(fmt.Errorf("persist helper native state: %w", err), cleanupErr),
		})
		return exitNativeFailure
	}

	writeResponse(stdout, successResponse(result))
	flushResponse(stdout)

	shutdownCtx, stopSignals := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	waitForHelperShutdown(shutdownCtx, req.HostPID)
	stopSignals()
	cleanupCtx, cancel := context.WithTimeout(context.Background(), nativeCleanupTimeout)
	cleanupErr := lifecycle.Cleanup(cleanupCtx)
	cancel()
	removeErr := manager.removeIfAttempt(req.AttemptID, req.AttemptNonce)
	if cleanupErr != nil || removeErr != nil {
		return exitNativeFailure
	}
	return exitOK
}

func defaultStatusNativeAttempt(stdout io.Writer, req AttemptRequest) int {
	manager := newNativeStateManager()
	state, err := manager.read()
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		writeResponse(stdout, errorResponse("stale_native_state", err, req.diagnosticSecrets()...))
		return exitNativeFailure
	}
	response := Response{
		ProtocolVersion: ProtocolVersion,
		HelperIdentity:  HelperIdentity,
		OK:              true,
		Message:         "linux_tun helper has no matching active native state",
	}
	if err == nil && state.matches(req.AttemptID, req.AttemptNonce) && pidAlive(state.HelperPID) {
		response.Message = "linux_tun helper has matching active native state"
	}
	writeResponse(stdout, response)
	return exitOK
}

func defaultCleanupNativeAttempt(stdout io.Writer, req AttemptRequest) int {
	manager := newNativeStateManager()
	if err := manager.cleanup(req); err != nil {
		writeResponse(stdout, errorResponseWithStage(
			nativeErrorCode(err, "cleanup_failed"),
			clientcontrol.PlatformTunnelStartupStageHostBringup,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			err,
			req.diagnosticSecrets()...,
		))
		return exitNativeFailure
	}
	writeResponse(stdout, Response{
		ProtocolVersion: ProtocolVersion,
		HelperIdentity:  HelperIdentity,
		OK:              true,
		Message:         "linux_tun helper cleanup completed",
	})
	return exitOK
}

func newNativeLifecycle(onState func(nativeStateSnapshot)) *nativeLifecycle {
	return &nativeLifecycle{
		runner:         osNativeCommandRunner{},
		tun:            tun.CreateTUN,
		resolvConfPath: "/etc/resolv.conf",
		probeURL:       nativeDataplaneURL,
		euid:           os.Geteuid,
		runtimeStarter: startNativeWireGuardRuntime,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
		onState: onState,
	}
}

func startNativeWireGuardRuntime(
	ctx context.Context,
	lease *clientcontrol.WireGuardTurnExecutionLease,
	tunDevice tun.Device,
) (nativeWireGuardRuntime, error) {
	return wireguardturnruntime.Start(ctx, wireguardturnruntime.Config{
		Lease:     lease,
		TUNDevice: tunDevice,
	})
}

func (l *nativeLifecycle) Start(ctx context.Context, req StartRequest) (nativeStartResult, error) {
	lease := req.Lease.toClientControlLease()
	if err := l.acquirePermission(); err != nil {
		return nativeStartResult{}, &nativeStartError{
			code:         "permission_denied",
			stage:        clientcontrol.PlatformTunnelStartupStagePermissionAcquire,
			prerequisite: clientcontrol.PlatformTunnelPrerequisitePermission,
			err:          err,
		}
	}
	routeState, err := l.validateRoutePolicy(ctx, req, &lease)
	if err != nil {
		return nativeStartResult{}, err
	}
	if err := l.bringupHost(ctx, &lease, routeState); err != nil {
		return nativeStartResult{}, &nativeStartError{
			code:         "native_start_failed",
			stage:        clientcontrol.PlatformTunnelStartupStageHostBringup,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			err:          err,
		}
	}
	if err := l.attachRuntime(ctx, &lease); err != nil {
		return nativeStartResult{}, &nativeStartError{
			code:         "runtime_attach_failed",
			stage:        clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			err:          err,
		}
	}
	dataplane, err := l.verifyDataplane(ctx, &lease)
	if err != nil {
		return nativeStartResult{}, &nativeStartError{
			code:         "dataplane_failed",
			stage:        clientcontrol.PlatformTunnelStartupStageDataplaneVerify,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteDataplaneEvidence,
			err:          err,
		}
	}
	return nativeStartResult{
		UnderlayRoutePolicy: routeState.UnderlayRoutePolicy,
		UnderlayExclusions:  append([]string(nil), routeState.Exclusions...),
		Dataplane:           dataplane,
	}, nil
}

func (l *nativeLifecycle) acquirePermission() error {
	euid := os.Geteuid
	if l.euid != nil {
		euid = l.euid
	}
	if euid() != 0 {
		return fmt.Errorf("linux_tun helper requires root privileges")
	}
	if l.tun == nil {
		return fmt.Errorf("linux_tun TUN factory is not configured")
	}
	tunDevice, err := l.tun(nativeInterfaceName, nativeDefaultMTU)
	if err != nil {
		return fmt.Errorf("create Linux TUN device: %w", err)
	}
	interfaceName, err := tunDevice.Name()
	if err != nil {
		_ = tunDevice.Close()
		return fmt.Errorf("query Linux TUN interface name: %w", err)
	}
	if l.state != nil {
		_ = l.Cleanup(context.Background())
	}
	l.state = &nativeHostState{
		tunDevice:     tunDevice,
		interfaceName: strings.TrimSpace(interfaceName),
	}
	l.publishState()
	return nil
}

func (l *nativeLifecycle) validateRoutePolicy(
	ctx context.Context,
	req StartRequest,
	lease *clientcontrol.WireGuardTurnExecutionLease,
) (*nativeRoutePolicyState, error) {
	if req.PolicyDirectives.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		return nil, &nativeStartError{
			code:         "route_validate_failed",
			stage:        clientcontrol.PlatformTunnelStartupStageRouteValidate,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			err: fmt.Errorf(
				"linux_tun requires underlay_route_policy %s",
				clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			),
		}
	}
	underlay, err := l.queryDefaultUnderlayRoute(ctx)
	if err != nil {
		return nil, &nativeStartError{
			code:         "route_validate_failed",
			stage:        clientcontrol.PlatformTunnelStartupStageRouteValidate,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			err:          err,
		}
	}
	dnsServers, dnsErr := l.queryDNSServers(ctx, underlay.Device)
	if dnsErr != nil {
		return nil, &nativeStartError{
			code:         "route_validate_failed",
			stage:        clientcontrol.PlatformTunnelStartupStageRouteValidate,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
			err:          dnsErr,
		}
	}
	exclusions, err := resolveNativeUnderlayRouteExclusions(ctx, lease.TURNServerAddress, dnsServers)
	if err != nil {
		prerequisite := clientcontrol.PlatformTunnelPrerequisiteRouteExclusion
		if strings.Contains(strings.ToLower(err.Error()), "dns") {
			prerequisite = clientcontrol.PlatformTunnelPrerequisiteDNSBypass
		}
		return nil, &nativeStartError{
			code:         "route_validate_failed",
			stage:        clientcontrol.PlatformTunnelStartupStageRouteValidate,
			prerequisite: prerequisite,
			err:          err,
		}
	}
	if len(exclusions) == 0 {
		return nil, &nativeStartError{
			code:         "route_validate_failed",
			stage:        clientcontrol.PlatformTunnelStartupStageRouteValidate,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			err:          fmt.Errorf("linux_tun route validation produced no underlay exclusions"),
		}
	}
	if l.state != nil {
		l.state.underlayDevice = underlay.Device
		l.state.underlayGateway = underlay.Gateway
		l.state.exclusions = append([]string(nil), exclusions...)
	}
	l.publishState()
	return &nativeRoutePolicyState{
		UnderlayRoutePolicy: req.PolicyDirectives.UnderlayRoutePolicy,
		Exclusions:          exclusions,
	}, nil
}

func (l *nativeLifecycle) bringupHost(
	ctx context.Context,
	lease *clientcontrol.WireGuardTurnExecutionLease,
	routeState *nativeRoutePolicyState,
) error {
	state, err := l.currentState()
	if err != nil {
		return err
	}
	if routeState == nil {
		return fmt.Errorf("linux_tun host bring-up requires route policy state")
	}
	ipv4Addresses := filterNativeIPv4CIDRs(lease.ClientAddresses)
	if len(ipv4Addresses) == 0 {
		return fmt.Errorf("linux_tun requires at least one IPv4 client address")
	}
	if err := l.runIP(ctx, "link", "set", "dev", state.interfaceName, "up", "mtu", fmt.Sprintf("%d", effectiveNativeMTU(lease.MTU))); err != nil {
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
	l.publishState()
	return nil
}

func (l *nativeLifecycle) attachRuntime(ctx context.Context, lease *clientcontrol.WireGuardTurnExecutionLease) error {
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
	if l.state != nil {
		l.state.runtime = runtime
	}
	return nil
}

func (l *nativeLifecycle) verifyDataplane(
	ctx context.Context,
	lease *clientcontrol.WireGuardTurnExecutionLease,
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
	if probeErr != nil && afterStatsErr == nil && shouldRetryNativeProbeAfterHandshake(beforeStats, afterStats) {
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
	expectedEgressIP := expectedNativeEgressIPFromEndpoint(lease.PeerEndpointAddress)
	wgRxDelta := afterStats.RxBytes - beforeStats.RxBytes
	wgTxDelta := afterStats.TxBytes - beforeStats.TxBytes
	handshakeFresh := nativeWireGuardHandshakeIsFresh(afterStats.LastHandshakeTime, time.Now().UTC())
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

func (l *nativeLifecycle) Cleanup(ctx context.Context) error {
	if l.state == nil {
		return nil
	}
	state := l.state
	l.state = nil
	return cleanupNativeHostState(ctx, l.runner, nativeStateSnapshot{
		InterfaceName:   state.interfaceName,
		UnderlayDevice:  state.underlayDevice,
		UnderlayGateway: state.underlayGateway,
		Exclusions:      append([]string(nil), state.exclusions...),
	}, state.runtime, state.tunDevice)
}

func cleanupNativeHostState(
	ctx context.Context,
	runner nativeCommandRunner,
	snapshot nativeStateSnapshot,
	runtime nativeWireGuardRuntime,
	tunDevice tun.Device,
) error {
	if runner == nil {
		runner = osNativeCommandRunner{}
	}
	var errs []error
	interfaceName := firstNonEmpty(strings.TrimSpace(snapshot.InterfaceName), nativeInterfaceName)
	if strings.TrimSpace(interfaceName) != "" {
		for _, destination := range []string{"0.0.0.0/1", "128.0.0.0/1"} {
			if err := runNativeIP(ctx, runner, "route", "del", destination, "dev", interfaceName); err != nil {
				errs = append(errs, fmt.Errorf("remove Linux TUN route %s: %w", destination, err))
			}
		}
		for _, excludedHost := range snapshot.Exclusions {
			args := []string{"route", "del", excludedHost + "/32"}
			if strings.TrimSpace(snapshot.UnderlayGateway) != "" {
				args = append(args, "via", snapshot.UnderlayGateway)
			}
			if strings.TrimSpace(snapshot.UnderlayDevice) != "" {
				args = append(args, "dev", snapshot.UnderlayDevice)
			}
			if err := runNativeIP(ctx, runner, args...); err != nil {
				errs = append(errs, fmt.Errorf("remove Linux underlay route exclusion %s: %w", excludedHost, err))
			}
		}
		if err := runNativeIP(ctx, runner, "address", "flush", "dev", interfaceName); err != nil {
			errs = append(errs, fmt.Errorf("flush Linux TUN addresses: %w", err))
		}
		if err := runNativeIP(ctx, runner, "link", "set", "dev", interfaceName, "down"); err != nil {
			errs = append(errs, fmt.Errorf("set Linux TUN interface down: %w", err))
		}
	}
	if runtime != nil {
		if err := runtime.Close(); err != nil {
			errs = append(errs, err)
		}
	}
	if tunDevice != nil {
		if err := tunDevice.Close(); err != nil && !errors.Is(err, os.ErrClosed) {
			errs = append(errs, err)
		}
	}
	return errors.Join(filterNativeCleanupErrors(errs)...)
}

func (l *nativeLifecycle) snapshot() nativeStateSnapshot {
	if l.state == nil {
		return nativeStateSnapshot{}
	}
	return nativeStateSnapshot{
		InterfaceName:   l.state.interfaceName,
		UnderlayDevice:  l.state.underlayDevice,
		UnderlayGateway: l.state.underlayGateway,
		Exclusions:      append([]string(nil), l.state.exclusions...),
	}
}

func (l *nativeLifecycle) publishState() {
	if l.onState != nil {
		l.onState(l.snapshot())
	}
}

func (l *nativeLifecycle) currentState() (*nativeHostState, error) {
	if l.state == nil || l.state.tunDevice == nil || strings.TrimSpace(l.state.interfaceName) == "" {
		return nil, fmt.Errorf("linux_tun lifecycle does not have an active TUN interface")
	}
	clone := *l.state
	if len(l.state.exclusions) > 0 {
		clone.exclusions = append([]string(nil), l.state.exclusions...)
	}
	return &clone, nil
}

func (l *nativeLifecycle) queryDefaultUnderlayRoute(ctx context.Context) (*nativeDefaultRoute, error) {
	output, err := l.runIPOutput(ctx, "-4", "route", "show", "default")
	if err != nil {
		return nil, err
	}
	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	for scanner.Scan() {
		route, ok := parseNativeDefaultRoute(scanner.Text())
		if ok {
			return route, nil
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return nil, fmt.Errorf("active IPv4 default route not found")
}

func parseNativeDefaultRoute(line string) (*nativeDefaultRoute, bool) {
	fields := strings.Fields(line)
	if len(fields) == 0 || fields[0] != "default" {
		return nil, false
	}
	route := &nativeDefaultRoute{}
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

func (l *nativeLifecycle) queryDNSServers(ctx context.Context, device string) ([]string, error) {
	var servers []string
	if strings.TrimSpace(device) != "" {
		if output, err := l.runCommandOutput(ctx, "resolvectl", "dns", device); err == nil {
			servers = append(servers, parseNativeResolvectlDNSServers(string(output))...)
		}
	}
	fromFile, err := parseNativeResolvConf(l.resolvConfPath)
	servers = append(servers, fromFile...)
	servers = dedupeNativeStrings(filterNonLoopbackNativeIPv4Strings(servers))
	if len(servers) == 0 {
		if err != nil {
			return nil, err
		}
		return nil, fmt.Errorf("DNS bypass requires at least one non-loopback IPv4 DNS server")
	}
	return servers, nil
}

func parseNativeResolvectlDNSServers(output string) []string {
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

func parseNativeResolvConf(path string) ([]string, error) {
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

func resolveNativeUnderlayRouteExclusions(ctx context.Context, turnServerAddress string, dnsServers []string) ([]string, error) {
	hosts := make([]string, 0, 1+len(dnsServers))
	turnHosts, err := resolveNativeIPv4Hosts(ctx, turnServerAddress)
	if err != nil {
		return nil, fmt.Errorf("route exclusion for TURN underlay failed: %w", err)
	}
	hosts = append(hosts, turnHosts...)
	for _, dnsServer := range dnsServers {
		if addr, err := netip.ParseAddr(strings.TrimSpace(dnsServer)); err == nil && addr.Is4() {
			hosts = append(hosts, addr.String())
		}
	}
	hosts = dedupeNativeStrings(hosts)
	if len(hosts) == 0 {
		return nil, fmt.Errorf("route exclusion requires at least one IPv4 underlay host")
	}
	return hosts, nil
}

func resolveNativeIPv4Hosts(ctx context.Context, address string) ([]string, error) {
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
	return dedupeNativeStrings(out), nil
}

func (l *nativeLifecycle) queryRemoteEgressIP(ctx context.Context) (string, error) {
	if l.httpClient == nil {
		return "", fmt.Errorf("linux_tun dataplane HTTP client is not configured")
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, firstNonEmpty(l.probeURL, nativeDataplaneURL), nil)
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

func (l *nativeLifecycle) runIP(ctx context.Context, args ...string) error {
	_, err := l.runIPOutput(ctx, args...)
	return err
}

func (l *nativeLifecycle) runIPOutput(ctx context.Context, args ...string) ([]byte, error) {
	return l.runCommandOutput(ctx, "ip", args...)
}

func (l *nativeLifecycle) runCommandOutput(ctx context.Context, name string, args ...string) ([]byte, error) {
	if l.runner == nil {
		return nil, fmt.Errorf("linux_tun command runner is not configured")
	}
	return l.runner.Run(ctx, name, args...)
}

type nativeStateManager struct {
	dir string
}

func newNativeStateManager() nativeStateManager {
	dir := strings.TrimSpace(os.Getenv(nativeStateDirEnv))
	if dir == "" {
		dir = defaultNativeStateDir
	}
	return nativeStateManager{dir: dir}
}

func (m nativeStateManager) prepareStart(req StartRequest) error {
	return m.withLock(func() error {
		state, err := m.readUnlocked()
		if err == nil {
			if pidAlive(state.HelperPID) {
				return &nativeStartError{
					code:         "stale_native_state",
					stage:        clientcontrol.PlatformTunnelStartupStageHostBringup,
					prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
					err:          fmt.Errorf("linux_tun native state is already owned by helper pid %d attempt %s", state.HelperPID, state.AttemptID),
				}
			}
			if err := cleanupNativeHostState(context.Background(), nativeCleanupRunner, state.snapshot(), nil, nil); err != nil {
				return &nativeStartError{
					code:         "stale_native_state",
					stage:        clientcontrol.PlatformTunnelStartupStageHostBringup,
					prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
					err:          fmt.Errorf("cleanup stale linux_tun native state before start: %w", err),
				}
			}
			_ = os.Remove(m.statePath())
		} else if !errors.Is(err, os.ErrNotExist) {
			return &nativeStartError{
				code:         "stale_native_state",
				stage:        clientcontrol.PlatformTunnelStartupStageHostBringup,
				prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
				err:          err,
			}
		}
		return m.writeUnlocked(nativeAttemptState{
			ProtocolVersion: ProtocolVersion,
			HelperIdentity:  HelperIdentity,
			AttemptID:       strings.TrimSpace(req.AttemptID),
			AttemptNonce:    strings.TrimSpace(req.AttemptNonce),
			HelperPID:       os.Getpid(),
			HostPID:         req.HostPID,
			InterfaceName:   nativeInterfaceName,
			UpdatedAt:       time.Now().UTC(),
		})
	})
}

func (m nativeStateManager) update(req StartRequest, snapshot nativeStateSnapshot) error {
	return m.withLock(func() error {
		state, err := m.readUnlocked()
		if err != nil {
			return err
		}
		if !state.matches(req.AttemptID, req.AttemptNonce) {
			return fmt.Errorf("linux_tun helper state belongs to a different attempt")
		}
		state.InterfaceName = firstNonEmpty(strings.TrimSpace(snapshot.InterfaceName), nativeInterfaceName)
		state.UnderlayDevice = strings.TrimSpace(snapshot.UnderlayDevice)
		state.UnderlayGateway = strings.TrimSpace(snapshot.UnderlayGateway)
		state.Exclusions = append([]string(nil), snapshot.Exclusions...)
		state.UpdatedAt = time.Now().UTC()
		return m.writeUnlocked(state)
	})
}

func (m nativeStateManager) cleanup(req AttemptRequest) error {
	var active nativeAttemptState
	needsSignal := false
	if err := m.withLock(func() error {
		state, err := m.readUnlocked()
		if errors.Is(err, os.ErrNotExist) {
			err := cleanupNativeHostState(context.Background(), nativeCleanupRunner, nativeStateSnapshot{InterfaceName: nativeInterfaceName}, nil, nil)
			if err != nil {
				return fmt.Errorf("cleanup stale default linux_tun state: %w", err)
			}
			return nil
		}
		if err != nil {
			return err
		}
		if !state.matches(req.AttemptID, req.AttemptNonce) {
			if pidAlive(state.HelperPID) {
				return &nativeStartError{
					code:         "stale_native_state",
					stage:        clientcontrol.PlatformTunnelStartupStageHostBringup,
					prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
					err:          fmt.Errorf("linux_tun native state belongs to another active attempt"),
				}
			}
			if err := cleanupNativeHostState(context.Background(), nativeCleanupRunner, state.snapshot(), nil, nil); err != nil {
				return fmt.Errorf("cleanup stale linux_tun native state: %w", err)
			}
			return os.Remove(m.statePath())
		}
		if pidAlive(state.HelperPID) && state.HelperPID != os.Getpid() {
			active = state
			needsSignal = true
			return nil
		}
		if err := cleanupNativeHostState(context.Background(), nativeCleanupRunner, state.snapshot(), nil, nil); err != nil {
			return fmt.Errorf("cleanup stale linux_tun native state: %w", err)
		}
		return os.Remove(m.statePath())
	}); err != nil {
		return err
	}
	if !needsSignal {
		return nil
	}
	if err := syscall.Kill(active.HelperPID, syscall.SIGTERM); err != nil && !errors.Is(err, syscall.ESRCH) {
		return fmt.Errorf("signal linux_tun helper pid %d: %w", active.HelperPID, err)
	}
	return m.waitForRemoval(active)
}

func (m nativeStateManager) removeIfAttempt(attemptID string, attemptNonce string) error {
	return m.withLock(func() error {
		state, err := m.readUnlocked()
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		if err != nil {
			return err
		}
		if !state.matches(attemptID, attemptNonce) {
			return nil
		}
		return os.Remove(m.statePath())
	})
}

func (m nativeStateManager) read() (nativeAttemptState, error) {
	var state nativeAttemptState
	err := m.withLock(func() error {
		var readErr error
		state, readErr = m.readUnlocked()
		return readErr
	})
	return state, err
}

func (m nativeStateManager) readUnlocked() (nativeAttemptState, error) {
	body, err := os.ReadFile(m.statePath())
	if err != nil {
		return nativeAttemptState{}, err
	}
	var state nativeAttemptState
	if err := json.Unmarshal(body, &state); err != nil {
		return nativeAttemptState{}, err
	}
	return state, nil
}

func (m nativeStateManager) writeUnlocked(state nativeAttemptState) error {
	if err := os.MkdirAll(m.dir, 0o700); err != nil {
		return err
	}
	body, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(m.statePath(), append(body, '\n'), 0o600)
}

func (m nativeStateManager) withLock(fn func() error) error {
	if err := os.MkdirAll(m.dir, 0o700); err != nil {
		return err
	}
	lock, err := os.OpenFile(m.lockPath(), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return err
	}
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	return fn()
}

func (m nativeStateManager) waitForRemoval(state nativeAttemptState) error {
	deadline := time.Now().Add(nativeCleanupTimeout)
	for time.Now().Before(deadline) {
		current, err := m.read()
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		if err != nil {
			return err
		}
		if !current.matches(state.AttemptID, state.AttemptNonce) {
			return nil
		}
		if !pidAlive(state.HelperPID) {
			if err := cleanupNativeHostState(context.Background(), nativeCleanupRunner, current.snapshot(), nil, nil); err != nil {
				return fmt.Errorf("cleanup stale linux_tun native state after helper exit: %w", err)
			}
			return os.Remove(m.statePath())
		}
		time.Sleep(nativeStatePollInterval)
	}
	return fmt.Errorf("linux_tun helper pid %d did not release native state", state.HelperPID)
}

func (m nativeStateManager) statePath() string {
	return filepath.Join(m.dir, nativeStateFileName)
}

func (m nativeStateManager) lockPath() string {
	return filepath.Join(m.dir, nativeLockFileName)
}

func (s nativeAttemptState) matches(attemptID string, attemptNonce string) bool {
	return strings.TrimSpace(s.AttemptID) == strings.TrimSpace(attemptID) &&
		strings.TrimSpace(s.AttemptNonce) == strings.TrimSpace(attemptNonce)
}

func (s nativeAttemptState) snapshot() nativeStateSnapshot {
	return nativeStateSnapshot{
		InterfaceName:   firstNonEmpty(strings.TrimSpace(s.InterfaceName), nativeInterfaceName),
		UnderlayDevice:  strings.TrimSpace(s.UnderlayDevice),
		UnderlayGateway: strings.TrimSpace(s.UnderlayGateway),
		Exclusions:      append([]string(nil), s.Exclusions...),
	}
}

func writeNativeError(stdout io.Writer, req StartRequest, err error) {
	var nativeErr *nativeStartError
	if !errors.As(err, &nativeErr) {
		nativeErr = &nativeStartError{
			code:         "native_start_failed",
			stage:        clientcontrol.PlatformTunnelStartupStageHostBringup,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			err:          err,
		}
	}
	writeResponse(stdout, errorResponseWithStage(
		nativeErr.code,
		nativeErr.stage,
		nativeErr.prerequisite,
		nativeErr.err,
		req.diagnosticSecrets()...,
	))
}

func nativeErrorCode(err error, fallback string) string {
	var nativeErr *nativeStartError
	if errors.As(err, &nativeErr) && strings.TrimSpace(nativeErr.code) != "" {
		return nativeErr.code
	}
	return fallback
}

func waitForHelperShutdown(ctx context.Context, hostPID int) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if !pidAlive(hostPID) {
				return
			}
		}
	}
}

func pidAlive(pid int) bool {
	if pid <= 0 {
		return false
	}
	err := syscall.Kill(pid, 0)
	return err == nil || errors.Is(err, syscall.EPERM)
}

func flushResponse(w io.Writer) {
	if flusher, ok := w.(interface{ Flush() error }); ok {
		_ = flusher.Flush()
	}
}

func runNativeIP(ctx context.Context, runner nativeCommandRunner, args ...string) error {
	_, err := runner.Run(ctx, "ip", args...)
	return err
}

func effectiveNativeMTU(value int) int {
	if value > 0 {
		return value
	}
	return nativeDefaultMTU
}

func filterNativeIPv4CIDRs(values []string) []string {
	out := make([]string, 0, len(values))
	for _, value := range values {
		prefix, err := netip.ParsePrefix(strings.TrimSpace(value))
		if err != nil || !prefix.Addr().Is4() {
			continue
		}
		out = append(out, prefix.String())
	}
	return dedupeNativeStrings(out)
}

func filterNonLoopbackNativeIPv4Strings(values []string) []string {
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

func dedupeNativeStrings(values []string) []string {
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

func expectedNativeEgressIPFromEndpoint(endpoint string) string {
	host := strings.TrimSpace(endpoint)
	if parsedHost, _, err := net.SplitHostPort(host); err == nil {
		host = parsedHost
	}
	if parsed := net.ParseIP(host); parsed != nil && parsed.To4() != nil {
		return parsed.String()
	}
	return ""
}

func shouldRetryNativeProbeAfterHandshake(
	before wireguardturnruntime.PeerStats,
	after wireguardturnruntime.PeerStats,
) bool {
	if nativeWireGuardHandshakeIsFresh(before.LastHandshakeTime, time.Now().UTC()) {
		return false
	}
	if !nativeWireGuardHandshakeIsFresh(after.LastHandshakeTime, time.Now().UTC()) {
		return false
	}
	return after.TxBytes > before.TxBytes || after.RxBytes > before.RxBytes
}

func nativeWireGuardHandshakeIsFresh(handshake time.Time, now time.Time) bool {
	if handshake.IsZero() {
		return false
	}
	if now.IsZero() {
		now = time.Now().UTC()
	}
	age := now.Sub(handshake.UTC())
	return age >= -5*time.Second && age <= 2*time.Minute
}

func filterNativeCleanupErrors(errs []error) []error {
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

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}
