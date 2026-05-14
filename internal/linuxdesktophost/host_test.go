package linuxdesktophost

import (
	"context"
	"errors"
	"log/slog"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func TestNewClientControlHostPublishesLinuxTunThroughDedicatedHost(t *testing.T) {
	t.Setenv(linuxTransportProfileStoreEnv, filepath.Join(t.TempDir(), "store.json"))
	withLinuxTunHostOverrides(t,
		func(clientcontrol.BuildIdentity) *linuxTunPrerequisiteFailure {
			return &linuxTunPrerequisiteFailure{
				prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
				message:      "linux_tun unavailable in test fixture",
			}
		},
		nil,
	)

	host := NewClientControlHost(nil)
	info := host.Info()
	if len(info.PlatformTunnels) != 1 {
		t.Fatalf("platform_tunnels len = %d, want 1", len(info.PlatformTunnels))
	}
	capability := info.PlatformTunnels[0]
	if capability.Mode != clientcontrol.PlatformTunnelModeLinuxTun {
		t.Fatalf("platform_tunnels[0].mode = %q, want %q", capability.Mode, clientcontrol.PlatformTunnelModeLinuxTun)
	}
	if capability.Available {
		t.Fatal("platform_tunnels[0].available = true, want false")
	}
	if capability.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"platform_tunnels[0].missing_prerequisite = %q, want %q",
			capability.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}
	if !strings.Contains(strings.ToLower(capability.Message), "test fixture") {
		t.Fatalf("platform_tunnels[0].message = %q, want test fixture detail", capability.Message)
	}
	if len(capability.ExecutionPlans) != 1 {
		t.Fatalf("platform_tunnels[0].execution_plans len = %d, want 1", len(capability.ExecutionPlans))
	}
	if capability.ExecutionPlans[0].Plan.HostAdapter != clientcontrol.RuntimeHostAdapterLinuxTun {
		t.Fatalf(
			"platform_tunnels[0].execution_plans[0].host_adapter = %q, want %q",
			capability.ExecutionPlans[0].Plan.HostAdapter,
			clientcontrol.RuntimeHostAdapterLinuxTun,
		)
	}
}

func TestNewClientControlHostPublishesSupportedLinuxTunWhenPrerequisitesPass(t *testing.T) {
	t.Setenv(linuxTransportProfileStoreEnv, filepath.Join(t.TempDir(), "store.json"))
	var lifecycleCreated bool
	withLinuxTunHostOverrides(t,
		func(clientcontrol.BuildIdentity) *linuxTunPrerequisiteFailure {
			return nil
		},
		func(*slog.Logger) LinuxTunLifecycle {
			lifecycleCreated = true
			return &fakeLinuxTunLifecycle{}
		},
	)

	host := NewClientControlHost(nil)
	info := host.Info()
	if len(info.PlatformTunnels) != 1 {
		t.Fatalf("platform_tunnels len = %d, want 1", len(info.PlatformTunnels))
	}
	capability := info.PlatformTunnels[0]
	if !capability.Available {
		t.Fatalf("platform_tunnels[0].available = false, want true: %+v", capability)
	}
	if !lifecycleCreated {
		t.Fatal("NewClientControlHost() did not create the Linux TUN lifecycle")
	}
	if !supportsLinuxUnderlayRoutePolicy(capability, clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork) {
		t.Fatalf("platform_tunnels[0] does not advertise preserve_active_local_network: %+v", capability)
	}
	for _, prerequisite := range capability.SatisfiedPrerequisites {
		if prerequisite == clientcontrol.PlatformTunnelPrerequisitePermission {
			t.Fatalf("platform_tunnels[0].satisfied_prerequisites = %v, want permission acquired only during startup", capability.SatisfiedPrerequisites)
		}
	}
	if len(capability.ExecutionPlans) != 1 {
		t.Fatalf("platform_tunnels[0].execution_plans len = %d, want 1", len(capability.ExecutionPlans))
	}
	descriptor := capability.ExecutionPlans[0]
	if descriptor.Plan.HostAdapter != clientcontrol.RuntimeHostAdapterLinuxTun {
		t.Fatalf("execution plan host_adapter = %q, want linux_tun", descriptor.Plan.HostAdapter)
	}
	if descriptor.TransportProfile == nil {
		t.Fatal("execution plan transport_profile = nil, want profile prerequisite status")
	}
}

func TestNewClientControlHostPackagedUbuntuDoesNotCreateRootLifecycle(t *testing.T) {
	t.Setenv(linuxTransportProfileStoreEnv, filepath.Join(t.TempDir(), "store.json"))
	t.Setenv(linuxTunPackagedTargetEnv, linuxTunPackagedTargetUbuntu)
	t.Setenv(linuxTunHelperPathEnv, "/tmp/relaydock-linux-tun-helper")
	var lifecycleCreated bool
	withLinuxTunHostOverrides(t,
		func(clientcontrol.BuildIdentity) *linuxTunPrerequisiteFailure {
			return nil
		},
		func(*slog.Logger) LinuxTunLifecycle {
			lifecycleCreated = true
			return &fakeLinuxTunLifecycle{}
		},
	)

	host := NewClientControlHost(nil)
	info := host.Info()

	if len(info.PlatformTunnels) != 1 || !info.PlatformTunnels[0].Available {
		t.Fatalf("platform_tunnels = %+v, want available linux_tun", info.PlatformTunnels)
	}
	if lifecycleCreated {
		t.Fatal("NewClientControlHost() created the root Linux TUN lifecycle for packaged Ubuntu")
	}
}

func TestDetectLinuxTransportProfileStorePathDefaultsToUserConfigStore(t *testing.T) {
	configDir := t.TempDir()
	t.Setenv(linuxTransportProfileStoreEnv, "")
	t.Setenv("XDG_CONFIG_HOME", configDir)

	path, err := detectLinuxTransportProfileStorePath()
	if err != nil {
		t.Fatalf("detectLinuxTransportProfileStorePath() error = %v", err)
	}
	want := filepath.Join(configDir, "vk-turn-proxy-go", "vpn-transport-profiles", "store.json")
	if path != want {
		t.Fatalf("detectLinuxTransportProfileStorePath() = %q, want %q", path, want)
	}
	if strings.Contains(path, "/var/lib/relaydock") {
		t.Fatalf("detectLinuxTransportProfileStorePath() = %q, want operator user store", path)
	}
}

func TestLinuxTunControllerMaterializesWireGuardLeaseThroughHost(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeLinuxTunLifecycle{
		routeState: &linuxRoutePolicyState{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			Exclusions:          []string{"turn.example.test:3478"},
		},
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	var captured clientcontrol.WireGuardTurnMaterializeRequest
	host := clientcontrol.New(
		clientcontrol.WithBuildIdentity(clientcontrol.BuildIdentity{Target: "linux/amd64"}),
		clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{controller.Capability()}),
		clientcontrol.WithPlatformTunnelStarter(controller.Start),
		clientcontrol.WithPlatformTunnelStopper(controller.Stop),
		clientcontrol.WithWireGuardTurnMaterializer(func(
			_ context.Context,
			req clientcontrol.WireGuardTurnMaterializeRequest,
		) (*clientcontrol.WireGuardTurnExecutionLease, error) {
			captured = req
			return &clientcontrol.WireGuardTurnExecutionLease{
				ResolutionID:         req.ResolutionID,
				AccessMethod:         req.Descriptor.Plan.AccessMethod,
				CarrierFamily:        req.Descriptor.Plan.CarrierFamily,
				EngineFamily:         req.Descriptor.Plan.EngineFamily,
				RemoteEndpointFamily: req.Descriptor.RemoteEndpointFamily,
				RemoteEndpointRole:   req.Descriptor.RemoteEndpointRole,
				TURNServerAddress:    req.Credentials.Address,
				TURNUsername:         req.Credentials.Username,
				TURNPassword:         req.Credentials.Password,
				PeerEndpointAddress:  "raw-wg.example.test:56042",
				ClientPrivateKey:     "client-key",
				ClientAddresses:      []string{"10.10.0.2/32"},
				PeerPublicKey:        "peer-key",
				AllowedIPs:           []string{"0.0.0.0/0"},
			}, nil
		}),
	)
	attachLinuxWireGuardTurnLeaseProvider(controller, host)

	resolution, err := host.StartResolution(context.Background(), clientcontrol.StartResolutionRequest{
		Provider: "generic-turn",
		Input: &clientcontrol.ProviderInputEnvelope{
			Kind: clientcontrol.ProviderInputKindLink,
			Link: "generic-turn://turn-user:turn-pass@turn.example.test:3478",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}
	resolved := waitForLinuxTestResolutionState(t, host, resolution.ID, clientcontrol.ResolutionStateResolved)

	result, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: resolved.ID,
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err != nil {
		t.Fatalf("Start() error = %v", err)
	}
	if !result.Ready {
		t.Fatalf("Start().Ready = false, want true: %+v", result)
	}
	if captured.ResolutionID != resolved.ID {
		t.Fatalf("materialize resolution_id = %q, want %q", captured.ResolutionID, resolved.ID)
	}
	if captured.Descriptor.Plan.HostAdapter != clientcontrol.RuntimeHostAdapterLinuxTun {
		t.Fatalf(
			"materialize host_adapter = %q, want %q",
			captured.Descriptor.Plan.HostAdapter,
			clientcontrol.RuntimeHostAdapterLinuxTun,
		)
	}
	if captured.Credentials.Address != "turn.example.test:3478" {
		t.Fatalf("materialize credentials address = %q, want turn.example.test:3478", captured.Credentials.Address)
	}
	if captured.Defaults.ListenAddr != "127.0.0.1:7777" {
		t.Fatalf("materialize defaults listen_addr = %q, want 127.0.0.1:7777", captured.Defaults.ListenAddr)
	}
}

func TestLinuxTunControllerReturnsTypedFailClosedStartupResult(t *testing.T) {
	t.Parallel()

	controller := newLinuxTunController(
		unavailableLinuxTunCapability(
			clientcontrol.BuildIdentity{Target: "linux/amd64"},
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			"linux_tun unavailable in test fixture",
		),
		nil,
	)
	result, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode: clientcontrol.PlatformTunnelModeLinuxTun,
	})
	if err != nil {
		t.Fatalf("Start() error = %v, want nil typed capability result", err)
	}
	if result.Ready {
		t.Fatalf("Start().Ready = true, want false: %+v", result)
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageCapabilityCheck {
		t.Fatalf("Start().Stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageCapabilityCheck)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"Start().MissingPrerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}
	if result.ExecutionPlan == nil {
		t.Fatal("Start().ExecutionPlan = nil, want documented plan")
	}
	if result.ExecutionPlan.HostAdapter != clientcontrol.RuntimeHostAdapterLinuxTun {
		t.Fatalf("Start().ExecutionPlan.HostAdapter = %q, want linux_tun", result.ExecutionPlan.HostAdapter)
	}
}

func TestLinuxTunControllerPermissionDeniedReturnsTypedStartFailure(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeLinuxTunLifecycle{
		permissionErr: errors.New("pkexec authorization was denied"),
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)

	_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err == nil {
		t.Fatal("Start() error = nil, want typed permission failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("Start() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStagePermissionAcquire {
		t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, clientcontrol.PlatformTunnelStartupStagePermissionAcquire)
	}
	if startErr.Result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisitePermission {
		t.Fatalf(
			"typed failure prerequisite = %q, want %q",
			startErr.Result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisitePermission,
		)
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanupCalls = %d, want 0", lifecycle.cleanupCalls)
	}
}

func TestLinuxTunHostPermissionDeniedKeepsLocalHostNegotiable(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeLinuxTunLifecycle{
		permissionErr: errors.New("pkexec authorization was denied"),
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)
	host := clientcontrol.New(
		clientcontrol.WithBuildIdentity(clientcontrol.BuildIdentity{Target: "linux/amd64"}),
		clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{controller.Capability()}),
		clientcontrol.WithPlatformTunnelStarter(controller.Start),
		clientcontrol.WithPlatformTunnelStopper(controller.Stop),
		clientcontrol.WithWireGuardTurnMaterializer(func(context.Context, clientcontrol.WireGuardTurnMaterializeRequest) (*clientcontrol.WireGuardTurnExecutionLease, error) {
			t.Fatal("materializer should not run before permission acquisition succeeds")
			return nil, nil
		}),
	)

	before := host.Info()
	if len(before.PlatformTunnels) != 1 || !before.PlatformTunnels[0].Available {
		t.Fatalf("host.Info().PlatformTunnels before start = %+v, want available linux_tun capability", before.PlatformTunnels)
	}
	_, err := host.StartPlatformTunnel(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err == nil {
		t.Fatal("StartPlatformTunnel() error = nil, want typed permission failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("StartPlatformTunnel() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStagePermissionAcquire {
		t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, clientcontrol.PlatformTunnelStartupStagePermissionAcquire)
	}
	if startErr.Result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisitePermission {
		t.Fatalf(
			"typed failure missing_prerequisite = %q, want %q",
			startErr.Result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisitePermission,
		)
	}
	after := host.Info()
	if after.ContractVersion != before.ContractVersion {
		t.Fatalf("host.Info() contract_version after permission failure = %q, want %q", after.ContractVersion, before.ContractVersion)
	}
	if len(after.PlatformTunnels) != 1 || !after.PlatformTunnels[0].Available {
		t.Fatalf("host.Info().PlatformTunnels after permission failure = %+v, want local host still negotiable", after.PlatformTunnels)
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanupCalls = %d, want 0 before native state exists", lifecycle.cleanupCalls)
	}
}

func TestLinuxTunControllerMaterializesLeaseBeforePermissionAcquire(t *testing.T) {
	t.Parallel()

	var order []string
	lifecycle := &fakeLinuxTunLifecycle{
		permissionErr: errors.New("pkexec authorization was denied"),
		onAcquirePermission: func() {
			order = append(order, "permission")
		},
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(func(
		ctx context.Context,
		req clientcontrol.PlatformTunnelStartRequest,
		plan *clientcontrol.RuntimeExecutionPlan,
	) (*clientcontrol.WireGuardTurnExecutionLease, error) {
		order = append(order, "lease")
		if req.ResolutionID != "resolution-1" {
			t.Fatalf("lease provider resolution_id = %q, want resolution-1", req.ResolutionID)
		}
		if plan == nil || plan.HostAdapter != clientcontrol.RuntimeHostAdapterLinuxTun {
			t.Fatalf("lease provider plan = %+v, want linux_tun host adapter", plan)
		}
		return fakeLinuxTunLeaseProvider(ctx, req, plan)
	})

	_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})

	if err == nil {
		t.Fatal("Start() error = nil, want typed permission failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("Start() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStagePermissionAcquire {
		t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, clientcontrol.PlatformTunnelStartupStagePermissionAcquire)
	}
	if got := strings.Join(order, " -> "); got != "lease -> permission" {
		t.Fatalf("orchestration order = %s, want lease -> permission", got)
	}
	if got := strings.Join(lifecycle.calls, " -> "); got != "permission_acquire" {
		t.Fatalf("lifecycle calls = %s, want only permission_acquire", got)
	}
}

func TestLinuxTunControllerPassesMaterializedAttemptToNativeClient(t *testing.T) {
	t.Parallel()

	var captured LinuxTunNativeStartRequest
	native := &fakeLinuxTunNativeClient{
		start: func(_ context.Context, req LinuxTunNativeStartRequest) (LinuxTunNativeStartResult, error) {
			captured = req
			return LinuxTunNativeStartResult{
				UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
				UnderlayExclusions:  []string{"203.0.113.10"},
				Dataplane: &clientcontrol.PlatformTunnelDataplaneEvidence{
					HostAttached:                 true,
					WireGuardHandshakeFresh:      true,
					WireGuardRxBytesDelta:        2048,
					WireGuardTxBytesDelta:        1024,
					BidirectionalTrafficVerified: true,
				},
			}, nil
		},
	}
	controller := newLinuxTunControllerWithNativeClient(supportedLinuxTunCapability(""), native)
	controller.setWireGuardTurnLeaseProvider(func(
		context.Context,
		clientcontrol.PlatformTunnelStartRequest,
		*clientcontrol.RuntimeExecutionPlan,
	) (*clientcontrol.WireGuardTurnExecutionLease, error) {
		lease, err := fakeLinuxTunLeaseProvider(context.Background(), clientcontrol.PlatformTunnelStartRequest{}, nil)
		if err != nil {
			return nil, err
		}
		lease.ResolutionID = "resolution-secret"
		return lease, nil
	})

	result, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-secret",
		TransportProfile: &clientcontrol.TransportProfileReference{
			ProfileID: "profile-secret",
		},
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})

	if err != nil {
		t.Fatalf("Start() error = %v", err)
	}
	if !result.Ready {
		t.Fatalf("Start().Ready = false, want true: %+v", result)
	}
	if captured.Mode != clientcontrol.PlatformTunnelModeLinuxTun {
		t.Fatalf("native request mode = %q, want linux_tun", captured.Mode)
	}
	if strings.TrimSpace(captured.AttemptID) == "" {
		t.Fatal("native request attempt_id is empty")
	}
	if strings.TrimSpace(captured.AttemptNonce) == "" {
		t.Fatal("native request attempt_nonce is empty")
	}
	if captured.AttemptID == captured.AttemptNonce {
		t.Fatalf("native request attempt_id and attempt_nonce are equal: %q", captured.AttemptID)
	}
	if captured.ExecutionPlan.HostAdapter != clientcontrol.RuntimeHostAdapterLinuxTun {
		t.Fatalf("native request host_adapter = %q, want linux_tun", captured.ExecutionPlan.HostAdapter)
	}
	if captured.Lease.ResolutionID != "" {
		t.Fatalf("native request lease resolution_id = %q, want omitted host-owned resolution state", captured.Lease.ResolutionID)
	}
	if captured.Lease.TURNServerAddress != "203.0.113.10:3478" {
		t.Fatalf("native request turn server = %q, want materialized lease", captured.Lease.TURNServerAddress)
	}
	if captured.PolicyDirectives.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		t.Fatalf("native request underlay policy = %q, want preserve_active_local_network", captured.PolicyDirectives.UnderlayRoutePolicy)
	}
	if got := strings.Join(captured.PolicyDirectives.UnderlayExclusions, ","); got != "203.0.113.10:3478" {
		t.Fatalf("native request underlay exclusions = %q, want TURN endpoint exclusion", got)
	}
	if !captured.PolicyDirectives.DNSBypassRequired {
		t.Fatal("native request DNSBypassRequired = false, want true")
	}
}

func TestLinuxTunControllerRejectsOverlappingNativeAttempt(t *testing.T) {
	t.Parallel()

	started := make(chan struct{})
	release := make(chan struct{})
	done := make(chan error, 1)
	nativeStartCalls := make(chan LinuxTunNativeStartRequest, 2)
	native := &fakeLinuxTunNativeClient{
		start: func(_ context.Context, req LinuxTunNativeStartRequest) (LinuxTunNativeStartResult, error) {
			nativeStartCalls <- req
			close(started)
			<-release
			return LinuxTunNativeStartResult{
				UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
				UnderlayExclusions:  []string{"203.0.113.10"},
				Dataplane: &clientcontrol.PlatformTunnelDataplaneEvidence{
					HostAttached:                 true,
					WireGuardHandshakeFresh:      true,
					BidirectionalTrafficVerified: true,
				},
			}, nil
		},
	}
	controller := newLinuxTunControllerWithNativeClient(supportedLinuxTunCapability(""), native)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)
	startReq := clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	}

	go func() {
		_, err := controller.Start(context.Background(), startReq)
		done <- err
	}()
	<-started

	_, err := controller.Start(context.Background(), startReq)

	if err == nil {
		t.Fatal("overlapping Start() error = nil, want typed failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("overlapping Start() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Ready {
		t.Fatalf("overlapping Start() ready = true, want false: %+v", startErr.Result)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStageCapabilityCheck {
		t.Fatalf("overlapping Start() stage = %q, want capability_check", startErr.Result.Stage)
	}
	if !strings.Contains(startErr.Result.Message, "active attempt") {
		t.Fatalf("overlapping Start() message = %q, want active attempt", startErr.Result.Message)
	}
	if len(nativeStartCalls) != 1 {
		t.Fatalf("native start calls = %d, want 1", len(nativeStartCalls))
	}
	close(release)
	if err := <-done; err != nil {
		t.Fatalf("first Start() error = %v", err)
	}
}

func TestLinuxTunControllerKeepsActiveAttemptUntilStop(t *testing.T) {
	t.Parallel()

	var startCalls int
	var activeAttemptID string
	var activeAttemptNonce string
	native := &fakeLinuxTunNativeClient{
		start: func(_ context.Context, req LinuxTunNativeStartRequest) (LinuxTunNativeStartResult, error) {
			startCalls++
			activeAttemptID = req.AttemptID
			activeAttemptNonce = req.AttemptNonce
			return LinuxTunNativeStartResult{
				UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
				UnderlayExclusions:  []string{"203.0.113.10"},
				Dataplane: &clientcontrol.PlatformTunnelDataplaneEvidence{
					HostAttached:                 true,
					WireGuardHandshakeFresh:      true,
					BidirectionalTrafficVerified: true,
				},
			}, nil
		},
		cleanup: func(_ context.Context, req LinuxTunNativeCleanupRequest) error {
			if req.AttemptID != activeAttemptID {
				t.Fatalf("cleanup attempt_id = %q, want active attempt %q", req.AttemptID, activeAttemptID)
			}
			if req.AttemptNonce != activeAttemptNonce {
				t.Fatalf("cleanup attempt_nonce = %q, want active attempt nonce", req.AttemptNonce)
			}
			return nil
		},
	}
	controller := newLinuxTunControllerWithNativeClient(supportedLinuxTunCapability(""), native)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)
	startReq := clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	}

	if result, err := controller.Start(context.Background(), startReq); err != nil || !result.Ready {
		t.Fatalf("first Start() = %+v, %v; want ready", result, err)
	}
	if _, err := controller.Start(context.Background(), startReq); err == nil {
		t.Fatal("second Start() error = nil, want active-attempt failure")
	}
	if startCalls != 1 {
		t.Fatalf("startCalls after rejected second start = %d, want 1", startCalls)
	}
	if _, err := controller.Stop(context.Background(), clientcontrol.PlatformTunnelStopRequest{
		Mode: clientcontrol.PlatformTunnelModeLinuxTun,
	}); err != nil {
		t.Fatalf("Stop() error = %v", err)
	}
	if result, err := controller.Start(context.Background(), startReq); err != nil || !result.Ready {
		t.Fatalf("third Start() after Stop = %+v, %v; want ready", result, err)
	}
	if startCalls != 2 {
		t.Fatalf("startCalls after third start = %d, want 2", startCalls)
	}
}

func TestLinuxTunControllerMapsNativeFailuresToTypedResults(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name       string
		kind       LinuxTunNativeFailureKind
		wantStage  clientcontrol.PlatformTunnelStartupStage
		wantPrereq clientcontrol.PlatformTunnelPrerequisite
	}{
		{
			name:       "helper permission denied",
			kind:       LinuxTunNativeFailurePermissionDenied,
			wantStage:  clientcontrol.PlatformTunnelStartupStagePermissionAcquire,
			wantPrereq: clientcontrol.PlatformTunnelPrerequisitePermission,
		},
		{
			name:       "malformed helper payload",
			kind:       LinuxTunNativeFailureMalformedPayload,
			wantStage:  clientcontrol.PlatformTunnelStartupStageHostBringup,
			wantPrereq: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		},
		{
			name:       "helper exit",
			kind:       LinuxTunNativeFailureHelperExit,
			wantStage:  clientcontrol.PlatformTunnelStartupStageHostBringup,
			wantPrereq: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		},
		{
			name:       "native startup",
			kind:       LinuxTunNativeFailureNativeStart,
			wantStage:  clientcontrol.PlatformTunnelStartupStageHostBringup,
			wantPrereq: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		},
		{
			name:       "runtime attach",
			kind:       LinuxTunNativeFailureRuntimeAttach,
			wantStage:  clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			wantPrereq: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		},
		{
			name:       "dataplane",
			kind:       LinuxTunNativeFailureDataplane,
			wantStage:  clientcontrol.PlatformTunnelStartupStageDataplaneVerify,
			wantPrereq: clientcontrol.PlatformTunnelPrerequisiteDataplaneEvidence,
		},
		{
			name:       "cleanup surfaced during startup reconciliation",
			kind:       LinuxTunNativeFailureCleanup,
			wantStage:  clientcontrol.PlatformTunnelStartupStageHostBringup,
			wantPrereq: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		},
	}
	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			native := &fakeLinuxTunNativeClient{
				start: func(context.Context, LinuxTunNativeStartRequest) (LinuxTunNativeStartResult, error) {
					return LinuxTunNativeStartResult{}, &LinuxTunNativeFailure{
						Kind:    tt.kind,
						Message: "typed native failure " + string(tt.kind),
					}
				},
			}
			controller := newLinuxTunControllerWithNativeClient(supportedLinuxTunCapability(""), native)
			controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)

			_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
				Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
				ResolutionID: "resolution-1",
				RuntimeDefaults: &clientcontrol.RuntimeDefaults{
					ListenAddr: "127.0.0.1:7777",
					PeerAddr:   "relay.example.test:3478",
				},
			})

			if err == nil {
				t.Fatal("Start() error = nil, want typed native failure")
			}
			startErr := new(clientcontrol.PlatformTunnelStartError)
			if !errors.As(err, &startErr) {
				t.Fatalf("Start() error = %v, want PlatformTunnelStartError", err)
			}
			if startErr.Result.Ready {
				t.Fatalf("typed failure ready = true, want false: %+v", startErr.Result)
			}
			if startErr.Result.Stage != tt.wantStage {
				t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, tt.wantStage)
			}
			if startErr.Result.MissingPrerequisite != tt.wantPrereq {
				t.Fatalf(
					"typed failure missing_prerequisite = %q, want %q",
					startErr.Result.MissingPrerequisite,
					tt.wantPrereq,
				)
			}
			if !strings.Contains(startErr.Result.Message, string(tt.kind)) {
				t.Fatalf("typed failure message = %q, want kind %q", startErr.Result.Message, tt.kind)
			}
		})
	}
}

func TestLinuxTunControllerStopReturnsNativeCleanupFailure(t *testing.T) {
	t.Parallel()

	native := &fakeLinuxTunNativeClient{
		cleanup: func(context.Context, LinuxTunNativeCleanupRequest) error {
			return &LinuxTunNativeFailure{
				Kind:    LinuxTunNativeFailureCleanup,
				Message: "helper cleanup failed",
			}
		},
	}
	controller := newLinuxTunControllerWithNativeClient(supportedLinuxTunCapability(""), native)

	_, err := controller.Stop(context.Background(), clientcontrol.PlatformTunnelStopRequest{
		Mode: clientcontrol.PlatformTunnelModeLinuxTun,
	})

	if err == nil {
		t.Fatal("Stop() error = nil, want cleanup failure")
	}
	if !strings.Contains(err.Error(), "helper cleanup failed") {
		t.Fatalf("Stop() error = %v, want cleanup message", err)
	}
	if native.cleanupCalls != 1 {
		t.Fatalf("cleanupCalls = %d, want 1", native.cleanupCalls)
	}
}

func TestLinuxTunHostCleansUpHelperAttemptAfterPartialStartupFailure(t *testing.T) {
	t.Parallel()

	var startedAttempt LinuxTunNativeStartRequest
	var cleanupAttempt LinuxTunNativeCleanupRequest
	native := &fakeLinuxTunNativeClient{
		start: func(_ context.Context, req LinuxTunNativeStartRequest) (LinuxTunNativeStartResult, error) {
			startedAttempt = req
			return LinuxTunNativeStartResult{}, &LinuxTunNativeFailure{
				Kind:    LinuxTunNativeFailureNativeStart,
				Message: "helper created partial native state and failed",
			}
		},
		cleanup: func(_ context.Context, req LinuxTunNativeCleanupRequest) error {
			cleanupAttempt = req
			return nil
		},
	}
	controller := newLinuxTunControllerWithNativeClient(supportedLinuxTunCapability(""), native)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)
	host := clientcontrol.New(
		clientcontrol.WithBuildIdentity(clientcontrol.BuildIdentity{Target: "linux/amd64"}),
		clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{controller.Capability()}),
		clientcontrol.WithPlatformTunnelStarter(controller.Start),
		clientcontrol.WithPlatformTunnelStopper(controller.Stop),
		clientcontrol.WithWireGuardTurnMaterializer(func(context.Context, clientcontrol.WireGuardTurnMaterializeRequest) (*clientcontrol.WireGuardTurnExecutionLease, error) {
			return fakeLinuxTunLeaseProvider(context.Background(), clientcontrol.PlatformTunnelStartRequest{}, nil)
		}),
	)

	_, err := host.StartPlatformTunnel(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})

	if err == nil {
		t.Fatal("StartPlatformTunnel() error = nil, want partial startup failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("StartPlatformTunnel() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStageHostBringup {
		t.Fatalf("typed failure stage = %q, want host_bringup", startErr.Result.Stage)
	}
	if strings.TrimSpace(startedAttempt.AttemptID) == "" || strings.TrimSpace(startedAttempt.AttemptNonce) == "" {
		t.Fatalf("started attempt = %q/%q, want id and nonce", startedAttempt.AttemptID, startedAttempt.AttemptNonce)
	}
	if cleanupAttempt.AttemptID != startedAttempt.AttemptID {
		t.Fatalf("cleanup attempt_id = %q, want %q", cleanupAttempt.AttemptID, startedAttempt.AttemptID)
	}
	if cleanupAttempt.AttemptNonce != startedAttempt.AttemptNonce {
		t.Fatalf("cleanup attempt_nonce = %q, want startup attempt nonce", cleanupAttempt.AttemptNonce)
	}
	if native.cleanupCalls != 1 {
		t.Fatalf("cleanupCalls = %d, want 1", native.cleanupCalls)
	}
}

func TestLinuxTunHostKeepsLocalHostReachableAfterHelperCrash(t *testing.T) {
	t.Parallel()

	native := &fakeLinuxTunNativeClient{
		start: func(context.Context, LinuxTunNativeStartRequest) (LinuxTunNativeStartResult, error) {
			return LinuxTunNativeStartResult{}, &LinuxTunNativeFailure{
				Kind:    LinuxTunNativeFailureHelperExit,
				Message: "helper exited before returning a response",
			}
		},
	}
	controller := newLinuxTunControllerWithNativeClient(supportedLinuxTunCapability(""), native)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)
	host := clientcontrol.New(
		clientcontrol.WithBuildIdentity(clientcontrol.BuildIdentity{Target: "linux/amd64"}),
		clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{controller.Capability()}),
		clientcontrol.WithPlatformTunnelStarter(controller.Start),
		clientcontrol.WithPlatformTunnelStopper(controller.Stop),
		clientcontrol.WithWireGuardTurnMaterializer(func(context.Context, clientcontrol.WireGuardTurnMaterializeRequest) (*clientcontrol.WireGuardTurnExecutionLease, error) {
			return fakeLinuxTunLeaseProvider(context.Background(), clientcontrol.PlatformTunnelStartRequest{}, nil)
		}),
	)
	before := host.Info()

	_, err := host.StartPlatformTunnel(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})

	if err == nil {
		t.Fatal("StartPlatformTunnel() error = nil, want helper crash failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("StartPlatformTunnel() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStageHostBringup {
		t.Fatalf("typed failure stage = %q, want host_bringup", startErr.Result.Stage)
	}
	after := host.Info()
	if after.ContractVersion != before.ContractVersion {
		t.Fatalf("host.Info() contract_version after helper crash = %q, want %q", after.ContractVersion, before.ContractVersion)
	}
	if len(after.PlatformTunnels) != 1 || !after.PlatformTunnels[0].Available {
		t.Fatalf("host.Info().PlatformTunnels after helper crash = %+v, want local host still negotiable", after.PlatformTunnels)
	}
}

func TestLinuxTunHostReportsCleanupFailureWithoutBlockingHost(t *testing.T) {
	t.Parallel()

	native := &fakeLinuxTunNativeClient{
		start: func(context.Context, LinuxTunNativeStartRequest) (LinuxTunNativeStartResult, error) {
			return LinuxTunNativeStartResult{}, &LinuxTunNativeFailure{
				Kind:    LinuxTunNativeFailureStaleState,
				Message: "stale rdtun0 state blocks startup",
			}
		},
		cleanup: func(context.Context, LinuxTunNativeCleanupRequest) error {
			return &LinuxTunNativeFailure{
				Kind:    LinuxTunNativeFailureCleanup,
				Message: "stale rdtun0 cleanup failed",
			}
		},
	}
	controller := newLinuxTunControllerWithNativeClient(supportedLinuxTunCapability(""), native)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)
	host := clientcontrol.New(
		clientcontrol.WithBuildIdentity(clientcontrol.BuildIdentity{Target: "linux/amd64"}),
		clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{controller.Capability()}),
		clientcontrol.WithPlatformTunnelStarter(controller.Start),
		clientcontrol.WithPlatformTunnelStopper(controller.Stop),
	)

	_, err := host.StartPlatformTunnel(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})

	if err == nil {
		t.Fatal("StartPlatformTunnel() error = nil, want stale native state failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("StartPlatformTunnel() error = %v, want PlatformTunnelStartError", err)
	}
	if !strings.Contains(startErr.Result.Message, "cleanup after startup failure also failed") {
		t.Fatalf("typed failure message = %q, want cleanup failure detail", startErr.Result.Message)
	}
	if len(host.Info().PlatformTunnels) != 1 {
		t.Fatalf("host.Info().PlatformTunnels lost after cleanup failure: %+v", host.Info().PlatformTunnels)
	}
}

func TestLinuxTunControllerRunsUbuntuReadyLifecycleAndPublishesEvidence(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeLinuxTunLifecycle{
		routeState: &linuxRoutePolicyState{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			Exclusions:          []string{"203.0.113.10", "1.1.1.1"},
		},
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)

	result, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:                clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID:        "resolution-1",
		UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err != nil {
		t.Fatalf("Start() error = %v", err)
	}
	if !result.Ready {
		t.Fatalf("Start().Ready = false, want true: %+v", result)
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageDataplaneVerify {
		t.Fatalf("Start().Stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageDataplaneVerify)
	}
	if result.RemoteIngress == nil {
		t.Fatal("Start().RemoteIngress = nil, want raw WireGuard ingress diagnostics")
	}
	if result.RemoteIngress.Protocol != clientcontrol.RuntimeRemoteIngressProtocolRawWireGuard ||
		result.RemoteIngress.Address != "raw-wg.example.test:56042" ||
		result.RemoteIngress.Isolation != clientcontrol.RuntimeRemoteIngressIsolationDedicated {
		t.Fatalf("Start().RemoteIngress = %+v, want raw WireGuard dedicated ingress", result.RemoteIngress)
	}
	if result.Dataplane == nil {
		t.Fatal("Start().Dataplane = nil, want verified data-plane evidence")
	}
	if !result.Dataplane.HostAttached ||
		!result.Dataplane.WireGuardHandshakeFresh ||
		!result.Dataplane.BidirectionalTrafficVerified {
		t.Fatalf("Start().Dataplane = %+v, want attached fresh bidirectional evidence", result.Dataplane)
	}
	if result.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		t.Fatalf(
			"Start().UnderlayRoutePolicy = %q, want %q",
			result.UnderlayRoutePolicy,
			clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		)
	}
	if len(result.UnderlayRouteExclusions) != 2 {
		t.Fatalf("Start().UnderlayRouteExclusions len = %d, want 2", len(result.UnderlayRouteExclusions))
	}
	if got := strings.Join(lifecycle.calls, ","); got != "permission_acquire,route_validate,host_bringup,runtime_attach,dataplane_verify" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"permission_acquire,route_validate,host_bringup,runtime_attach,dataplane_verify",
		)
	}
}

func TestLinuxTunControllerRouteValidationFailureIsTyped(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeLinuxTunLifecycle{
		routeErr: &linuxTunRoutePolicyError{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
			message:      "DNS bypass cannot be prepared safely",
		},
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)

	_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err == nil {
		t.Fatal("Start() error = nil, want typed route_validate failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("Start() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStageRouteValidate {
		t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, clientcontrol.PlatformTunnelStartupStageRouteValidate)
	}
	if startErr.Result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteDNSBypass {
		t.Fatalf(
			"typed failure missing_prerequisite = %q, want %q",
			startErr.Result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
		)
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanupCalls = %d, want 0 before host-owned stop cleanup", lifecycle.cleanupCalls)
	}
}

func TestLinuxTunHostCleansUpTypedPartialStartupFailures(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name       string
		lifecycle  fakeLinuxTunLifecycle
		wantStage  clientcontrol.PlatformTunnelStartupStage
		wantPrereq clientcontrol.PlatformTunnelPrerequisite
	}{
		{
			name: "route validation",
			lifecycle: fakeLinuxTunLifecycle{
				routeErr: &linuxTunRoutePolicyError{
					prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
					message:      "control route cannot be preserved safely",
				},
			},
			wantStage:  clientcontrol.PlatformTunnelStartupStageRouteValidate,
			wantPrereq: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
		},
		{
			name: "host bringup",
			lifecycle: fakeLinuxTunLifecycle{
				routeState: &linuxRoutePolicyState{
					UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
					Exclusions:          []string{"203.0.113.10"},
				},
				bringupErr: errors.New("tun device creation failed"),
			},
			wantStage:  clientcontrol.PlatformTunnelStartupStageHostBringup,
			wantPrereq: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		},
		{
			name: "runtime attach",
			lifecycle: fakeLinuxTunLifecycle{
				routeState: &linuxRoutePolicyState{
					UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
					Exclusions:          []string{"203.0.113.10"},
				},
				attachErr: errors.New("runtime attach failed after partial Linux bring-up"),
			},
			wantStage:  clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			wantPrereq: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		},
	}
	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			lifecycle := &tt.lifecycle
			controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
			controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)
			host := clientcontrol.New(
				clientcontrol.WithBuildIdentity(clientcontrol.BuildIdentity{Target: "linux/amd64"}),
				clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{controller.Capability()}),
				clientcontrol.WithPlatformTunnelStarter(controller.Start),
				clientcontrol.WithPlatformTunnelStopper(controller.Stop),
			)

			_, err := host.StartPlatformTunnel(context.Background(), clientcontrol.PlatformTunnelStartRequest{
				Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
				ResolutionID: "resolution-1",
				RuntimeDefaults: &clientcontrol.RuntimeDefaults{
					ListenAddr: "127.0.0.1:7777",
					PeerAddr:   "relay.example.test:3478",
				},
			})
			if err == nil {
				t.Fatal("StartPlatformTunnel() error = nil, want typed startup failure")
			}
			startErr := new(clientcontrol.PlatformTunnelStartError)
			if !errors.As(err, &startErr) {
				t.Fatalf("StartPlatformTunnel() error = %v, want PlatformTunnelStartError", err)
			}
			if startErr.Result.Stage != tt.wantStage {
				t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, tt.wantStage)
			}
			if startErr.Result.MissingPrerequisite != tt.wantPrereq {
				t.Fatalf(
					"typed failure missing_prerequisite = %q, want %q",
					startErr.Result.MissingPrerequisite,
					tt.wantPrereq,
				)
			}
			if lifecycle.cleanupCalls != 1 {
				t.Fatalf("cleanupCalls = %d, want 1 host-owned cleanup after partial failure", lifecycle.cleanupCalls)
			}
		})
	}
}

func TestLinuxTunControllerRejectsUnsupportedRoutePolicy(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeLinuxTunLifecycle{}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)

	result, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:                clientcontrol.PlatformTunnelModeLinuxTun,
		UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard,
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err != nil {
		t.Fatalf("Start() error = %v, want typed capability result", err)
	}
	if result.Ready {
		t.Fatalf("Start().Ready = true, want false: %+v", result)
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageCapabilityCheck {
		t.Fatalf("Start().Stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageCapabilityCheck)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteRouteExclusion {
		t.Fatalf(
			"Start().MissingPrerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
		)
	}
	if len(lifecycle.calls) != 0 {
		t.Fatalf("lifecycle calls = %v, want none before route policy support failure", lifecycle.calls)
	}
}

func TestLinuxTunHostRejectsUnsafeRoutePolicyBeforeLifecycle(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeLinuxTunLifecycle{}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)
	host := clientcontrol.New(
		clientcontrol.WithBuildIdentity(clientcontrol.BuildIdentity{Target: "linux/amd64"}),
		clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{controller.Capability()}),
		clientcontrol.WithPlatformTunnelStarter(controller.Start),
		clientcontrol.WithPlatformTunnelStopper(controller.Stop),
	)

	result, err := host.StartPlatformTunnel(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:                clientcontrol.PlatformTunnelModeLinuxTun,
		UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard,
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel() error = %v, want fail-closed startup result", err)
	}
	if result.Ready {
		t.Fatalf("StartPlatformTunnel().Ready = true, want false: %+v", result)
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageCapabilityCheck {
		t.Fatalf("StartPlatformTunnel().Stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageCapabilityCheck)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteRouteExclusion {
		t.Fatalf(
			"StartPlatformTunnel().MissingPrerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
		)
	}
	if len(lifecycle.calls) != 0 {
		t.Fatalf("lifecycle calls = %v, want none before unsafe route policy failure", lifecycle.calls)
	}
}

func TestLinuxTunControllerRuntimeAttachFailureIsTyped(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeLinuxTunLifecycle{
		routeState: &linuxRoutePolicyState{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			Exclusions:          []string{"203.0.113.10"},
		},
		attachErr: errors.New("runtime attach failed after partial Linux bring-up"),
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)

	_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err == nil {
		t.Fatal("Start() error = nil, want typed runtime_attach failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("Start() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStageRuntimeAttach {
		t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, clientcontrol.PlatformTunnelStartupStageRuntimeAttach)
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanupCalls = %d, want 0 before host-owned stop cleanup", lifecycle.cleanupCalls)
	}
}

func TestLinuxTunControllerDataplaneFailureIsTyped(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeLinuxTunLifecycle{
		routeState: &linuxRoutePolicyState{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			Exclusions:          []string{"203.0.113.10"},
		},
		dataplaneErr: errors.New("no fresh WireGuard handshake"),
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)

	_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err == nil {
		t.Fatal("Start() error = nil, want typed dataplane_verify failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("Start() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStageDataplaneVerify {
		t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, clientcontrol.PlatformTunnelStartupStageDataplaneVerify)
	}
	if startErr.Result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteDataplaneEvidence {
		t.Fatalf(
			"typed failure missing_prerequisite = %q, want %q",
			startErr.Result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteDataplaneEvidence,
		)
	}
}

func TestLinuxTunHostRejectsIncompleteDataplaneEvidenceAndCleansUp(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeLinuxTunLifecycle{
		routeState: &linuxRoutePolicyState{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			Exclusions:          []string{"203.0.113.10"},
		},
		dataplane: &clientcontrol.PlatformTunnelDataplaneEvidence{
			HostAttached:                 true,
			WireGuardHandshakeFresh:      true,
			BidirectionalTrafficVerified: false,
		},
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)
	host := clientcontrol.New(
		clientcontrol.WithBuildIdentity(clientcontrol.BuildIdentity{Target: "linux/amd64"}),
		clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{controller.Capability()}),
		clientcontrol.WithPlatformTunnelStarter(controller.Start),
		clientcontrol.WithPlatformTunnelStopper(controller.Stop),
	)

	_, err := host.StartPlatformTunnel(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err == nil {
		t.Fatal("StartPlatformTunnel() error = nil, want typed dataplane evidence failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("StartPlatformTunnel() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStageDataplaneVerify {
		t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, clientcontrol.PlatformTunnelStartupStageDataplaneVerify)
	}
	if startErr.Result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteDataplaneEvidence {
		t.Fatalf(
			"typed failure missing_prerequisite = %q, want %q",
			startErr.Result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteDataplaneEvidence,
		)
	}
	if lifecycle.cleanupCalls != 1 {
		t.Fatalf("cleanupCalls = %d, want 1 host-owned cleanup after dataplane failure", lifecycle.cleanupCalls)
	}
}

type fakeLinuxTunLifecycle struct {
	permissionErr error
	routeErr      error
	routeState    *linuxRoutePolicyState
	bringupErr    error
	attachErr     error
	dataplane     *clientcontrol.PlatformTunnelDataplaneEvidence
	dataplaneErr  error

	onAcquirePermission func()
	calls               []string
	cleanupCalls        int
}

type fakeLinuxTunNativeClient struct {
	start        func(context.Context, LinuxTunNativeStartRequest) (LinuxTunNativeStartResult, error)
	cleanup      func(context.Context, LinuxTunNativeCleanupRequest) error
	cleanupCalls int
}

func (f *fakeLinuxTunNativeClient) Start(
	ctx context.Context,
	req LinuxTunNativeStartRequest,
) (LinuxTunNativeStartResult, error) {
	if f.start != nil {
		return f.start(ctx, req)
	}
	return LinuxTunNativeStartResult{}, nil
}

func (f *fakeLinuxTunNativeClient) Cleanup(ctx context.Context, req LinuxTunNativeCleanupRequest) error {
	f.cleanupCalls++
	if f.cleanup != nil {
		return f.cleanup(ctx, req)
	}
	return nil
}

func withLinuxTunHostOverrides(
	t *testing.T,
	prerequisiteCheck func(clientcontrol.BuildIdentity) *linuxTunPrerequisiteFailure,
	lifecycleFactory func(*slog.Logger) LinuxTunLifecycle,
) {
	t.Helper()
	previousPrerequisiteCheck := linuxTunPrerequisiteCheck
	previousLifecycleFactory := newLinuxTunLifecycleForHost
	if prerequisiteCheck != nil {
		linuxTunPrerequisiteCheck = prerequisiteCheck
	}
	if lifecycleFactory != nil {
		newLinuxTunLifecycleForHost = lifecycleFactory
	}
	t.Cleanup(func() {
		linuxTunPrerequisiteCheck = previousPrerequisiteCheck
		newLinuxTunLifecycleForHost = previousLifecycleFactory
	})
}

func (f *fakeLinuxTunLifecycle) AcquirePermission(context.Context, clientcontrol.PlatformTunnelStartRequest) error {
	if f.onAcquirePermission != nil {
		f.onAcquirePermission()
	}
	f.calls = append(f.calls, "permission_acquire")
	return f.permissionErr
}

func (f *fakeLinuxTunLifecycle) ValidateRoutePolicy(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
	*clientcontrol.WireGuardTurnExecutionLease,
) (*linuxRoutePolicyState, error) {
	f.calls = append(f.calls, "route_validate")
	if f.routeErr != nil {
		return nil, f.routeErr
	}
	if f.routeState == nil {
		f.routeState = &linuxRoutePolicyState{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			Exclusions:          []string{"203.0.113.10"},
		}
	}
	return f.routeState, nil
}

func (f *fakeLinuxTunLifecycle) BringupHost(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
	*clientcontrol.WireGuardTurnExecutionLease,
	*linuxRoutePolicyState,
) error {
	f.calls = append(f.calls, "host_bringup")
	return f.bringupErr
}

func (f *fakeLinuxTunLifecycle) AttachRuntime(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
	*clientcontrol.WireGuardTurnExecutionLease,
	*linuxRoutePolicyState,
) error {
	f.calls = append(f.calls, "runtime_attach")
	return f.attachErr
}

func (f *fakeLinuxTunLifecycle) VerifyDataplane(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
	*clientcontrol.WireGuardTurnExecutionLease,
	*linuxRoutePolicyState,
) (*clientcontrol.PlatformTunnelDataplaneEvidence, error) {
	f.calls = append(f.calls, "dataplane_verify")
	if f.dataplaneErr != nil {
		return f.dataplane, f.dataplaneErr
	}
	if f.dataplane != nil {
		return f.dataplane, nil
	}
	return &clientcontrol.PlatformTunnelDataplaneEvidence{
		HostAttached:                 true,
		WireGuardHandshakeFresh:      true,
		WireGuardRxBytesDelta:        2048,
		WireGuardTxBytesDelta:        1024,
		RemoteEgressIP:               "203.0.113.10",
		ExpectedRemoteEgressIP:       "203.0.113.10",
		BidirectionalTrafficVerified: true,
	}, nil
}

func (f *fakeLinuxTunLifecycle) Cleanup(context.Context) error {
	f.cleanupCalls++
	f.calls = append(f.calls, "cleanup")
	return nil
}

func fakeLinuxTunLeaseProvider(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
) (*clientcontrol.WireGuardTurnExecutionLease, error) {
	return &clientcontrol.WireGuardTurnExecutionLease{
		ResolutionID:         "resolution-1",
		AccessMethod:         clientcontrol.RuntimeAccessMethodTURNCredentials,
		CarrierFamily:        clientcontrol.RuntimeCarrierFamilyTURNDatagram,
		EngineFamily:         clientcontrol.RuntimeEngineFamilyWireGuardNative,
		RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
		RemoteEndpointRole:   clientcontrol.WireGuardTurnRemoteEndpointRoleDatagramTermination,
		TURNServerAddress:    "203.0.113.10:3478",
		TURNUsername:         "user",
		TURNPassword:         "pass",
		PeerEndpointAddress:  "raw-wg.example.test:56042",
		ClientPrivateKey:     "key",
		ClientAddresses:      []string{"10.10.0.2/32"},
		PeerPublicKey:        "peer",
		AllowedIPs:           []string{"0.0.0.0/0"},
	}, nil
}

func waitForLinuxTestResolutionState(
	t *testing.T,
	host *clientcontrol.Host,
	resolutionID string,
	want clientcontrol.ResolutionState,
) clientcontrol.Resolution {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		resolution, err := host.Resolution(resolutionID)
		if err != nil {
			t.Fatalf("Resolution(%q) error = %v", resolutionID, err)
		}
		if resolution.State == want {
			return resolution
		}
		if resolution.State == clientcontrol.ResolutionStateFailed {
			message := ""
			if resolution.Failure != nil {
				message = resolution.Failure.Message
			}
			t.Fatalf("Resolution(%q).State = failed, want %q: %s", resolutionID, want, message)
		}
		time.Sleep(10 * time.Millisecond)
	}
	resolution, err := host.Resolution(resolutionID)
	if err != nil {
		t.Fatalf("Resolution(%q) error after timeout = %v", resolutionID, err)
	}
	t.Fatalf("Resolution(%q).State = %q, want %q", resolutionID, resolution.State, want)
	return clientcontrol.Resolution{}
}
