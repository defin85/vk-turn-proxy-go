//go:build linux

package linuxtunhelper

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/wireguardturnruntime"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
	"golang.zx2c4.com/wireguard/tun"
)

func TestCleanupReconcilesDeadStaleNativeState(t *testing.T) {
	dir := t.TempDir()
	t.Setenv(nativeStateDirEnv, dir)
	runner := &recordingNativeCommandRunner{}
	restore := overrideNativeCleanupRunnerForTest(t, runner)
	defer restore()

	manager := newNativeStateManager()
	deadPID := deadPIDForTest()
	if err := manager.withLock(func() error {
		return manager.writeUnlocked(nativeAttemptState{
			ProtocolVersion: ProtocolVersion,
			HelperIdentity:  HelperIdentity,
			AttemptID:       "old-attempt",
			AttemptNonce:    "old-nonce",
			HelperPID:       deadPID,
			HostPID:         deadPID,
			InterfaceName:   nativeInterfaceName,
			UnderlayDevice:  "eth0",
			UnderlayGateway: "192.0.2.1",
			Exclusions:      []string{"203.0.113.10"},
			UpdatedAt:       time.Now().UTC(),
		})
	}); err != nil {
		t.Fatalf("write stale state: %v", err)
	}

	var stdout bytes.Buffer
	code := Run(
		strings.NewReader(`{"protocol_version":1,"attempt_id":"new-attempt","attempt_nonce":"new-nonce"}`),
		&stdout,
		&bytes.Buffer{},
		[]string{"cleanup"},
	)

	if code != exitOK {
		t.Fatalf("Run(cleanup) code = %d, want %d; response=%s", code, exitOK, stdout.String())
	}
	response := decodeResponse(t, stdout.Bytes())
	if !response.OK {
		t.Fatalf("cleanup response.OK = false: %+v", response)
	}
	if _, err := os.Stat(manager.statePath()); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("state file after cleanup err = %v, want not exist", err)
	}
	for _, command := range []string{
		"ip route del 0.0.0.0/1 dev rdtun0",
		"ip route del 128.0.0.0/1 dev rdtun0",
		"ip route del 203.0.113.10/32 via 192.0.2.1 dev eth0",
		"ip address flush dev rdtun0",
		"ip link set dev rdtun0 down",
	} {
		if !runner.has(command) {
			t.Fatalf("cleanup commands = %v, want %q", runner.commands, command)
		}
	}
}

func TestCleanupRejectsDifferentActiveAttemptFailClosed(t *testing.T) {
	dir := t.TempDir()
	t.Setenv(nativeStateDirEnv, dir)
	runner := &recordingNativeCommandRunner{}
	restore := overrideNativeCleanupRunnerForTest(t, runner)
	defer restore()

	manager := newNativeStateManager()
	if err := manager.withLock(func() error {
		return manager.writeUnlocked(nativeAttemptState{
			ProtocolVersion: ProtocolVersion,
			HelperIdentity:  HelperIdentity,
			AttemptID:       "active-attempt",
			AttemptNonce:    "active-nonce",
			HelperPID:       os.Getpid(),
			HostPID:         os.Getpid(),
			InterfaceName:   nativeInterfaceName,
			UpdatedAt:       time.Now().UTC(),
		})
	}); err != nil {
		t.Fatalf("write active state: %v", err)
	}

	var stdout bytes.Buffer
	code := Run(
		strings.NewReader(`{"protocol_version":1,"attempt_id":"other-attempt","attempt_nonce":"other-nonce"}`),
		&stdout,
		&bytes.Buffer{},
		[]string{"cleanup"},
	)

	if code != exitNativeFailure {
		t.Fatalf("Run(cleanup) code = %d, want %d", code, exitNativeFailure)
	}
	response := decodeResponse(t, stdout.Bytes())
	if response.ErrorCode != "stale_native_state" {
		t.Fatalf("cleanup response.ErrorCode = %q, want stale_native_state", response.ErrorCode)
	}
	if _, err := os.Stat(manager.statePath()); err != nil {
		t.Fatalf("state file after rejected cleanup err = %v, want retained", err)
	}
	if len(runner.commands) != 0 {
		t.Fatalf("cleanup commands = %v, want no native cleanup for another active attempt", runner.commands)
	}
}

func TestDefaultStartReportsPermissionBeforeStateDir(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("permission-denial ordering is a non-root helper smoke")
	}
	t.Setenv(nativeStateDirEnv, filepath.Join(t.TempDir(), "state"))
	request := validStartRequestForTest()
	body := mustJSON(t, request)

	var stdout bytes.Buffer
	code := Run(bytes.NewReader(body), &stdout, &bytes.Buffer{}, []string{"start"})

	if code != exitNativeFailure {
		t.Fatalf("Run(start) code = %d, want %d", code, exitNativeFailure)
	}
	response := decodeResponse(t, stdout.Bytes())
	if response.ErrorCode != "permission_denied" {
		t.Fatalf("response.ErrorCode = %q, want permission_denied", response.ErrorCode)
	}
	if response.Stage != clientcontrol.PlatformTunnelStartupStagePermissionAcquire {
		t.Fatalf("response.Stage = %q, want %q", response.Stage, clientcontrol.PlatformTunnelStartupStagePermissionAcquire)
	}
	if response.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisitePermission {
		t.Fatalf("response.MissingPrerequisite = %q, want %q", response.MissingPrerequisite, clientcontrol.PlatformTunnelPrerequisitePermission)
	}
}

func TestNativeLifecycleReadyPathOwnsTunRoutesRuntimeAndDataplane(t *testing.T) {
	ctx := context.Background()
	resolvConfPath := filepath.Join(t.TempDir(), "resolv.conf")
	if err := os.WriteFile(resolvConfPath, []byte("nameserver 9.9.9.9\nnameserver 127.0.0.53\n"), 0o600); err != nil {
		t.Fatalf("write resolv.conf fixture: %v", err)
	}
	runner := &scriptedNativeCommandRunner{
		outputs: map[string]string{
			"ip -4 route show default": "default via 192.0.2.1 dev eth0 proto dhcp src 192.0.2.55 metric 100\n",
			"resolvectl dns eth0":      "Link 2 (eth0): 1.1.1.1\n",
		},
	}
	tunDevice := newFakeNativeTunDevice(nativeInterfaceName, nativeDefaultMTU)
	runtime := &fakeNativeRuntime{
		stats: []wireguardturnruntime.PeerStats{
			{
				LastHandshakeTime: time.Now().UTC().Add(-10 * time.Second),
				RxBytes:           100,
				TxBytes:           200,
			},
			{
				LastHandshakeTime: time.Now().UTC(),
				RxBytes:           900,
				TxBytes:           700,
			},
		},
	}
	var snapshots []nativeStateSnapshot
	lifecycle := &nativeLifecycle{
		runner:         runner,
		resolvConfPath: resolvConfPath,
		probeURL:       "http://probe.test/cdn-cgi/trace",
		euid:           func() int { return 0 },
		tun: func(name string, mtu int) (tun.Device, error) {
			if name != nativeInterfaceName {
				t.Fatalf("created TUN name = %q, want %q", name, nativeInterfaceName)
			}
			if mtu != nativeDefaultMTU {
				t.Fatalf("created TUN MTU = %d, want %d", mtu, nativeDefaultMTU)
			}
			return tunDevice, nil
		},
		runtimeStarter: func(_ context.Context, lease *clientcontrol.WireGuardTurnExecutionLease, device tun.Device) (nativeWireGuardRuntime, error) {
			if lease == nil {
				t.Fatal("runtime starter lease = nil")
			}
			if lease.TURNServerAddress != "203.0.113.10:3478" {
				t.Fatalf("runtime lease TURN = %q, want materialized helper lease", lease.TURNServerAddress)
			}
			if device != tunDevice {
				t.Fatalf("runtime starter device = %p, want %p", device, tunDevice)
			}
			return runtime, nil
		},
		httpClient: &http.Client{
			Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
				if req.URL.String() != "http://probe.test/cdn-cgi/trace" {
					t.Fatalf("probe URL = %q, want fixture URL", req.URL.String())
				}
				return &http.Response{
					StatusCode: http.StatusOK,
					Status:     "200 OK",
					Body:       io.NopCloser(strings.NewReader("ip=198.51.100.7\n")),
					Header:     make(http.Header),
					Request:    req,
				}, nil
			}),
		},
		onState: func(snapshot nativeStateSnapshot) {
			snapshots = append(snapshots, snapshot)
		},
	}
	request := validStartRequestForTest()
	request.Lease.TURNServerAddress = "203.0.113.10:3478"
	request.Lease.PeerEndpointAddress = "198.51.100.7:56042"
	request.Lease.ClientAddresses = []string{"10.10.0.2/32", "fd00::2/128"}
	request.Lease.MTU = 1420

	result, err := lifecycle.Start(ctx, request)
	if err != nil {
		t.Fatalf("Start() error = %v", err)
	}
	for _, excluded := range []string{"1.1.1.1", "9.9.9.9", "203.0.113.10"} {
		if !containsNativeString(result.UnderlayExclusions, excluded) {
			t.Fatalf("UnderlayExclusions = %v, want %s", result.UnderlayExclusions, excluded)
		}
	}
	for _, command := range []string{
		"ip link set dev rdtun0 up mtu 1420",
		"ip address replace 10.10.0.2/32 dev rdtun0",
		"ip route replace 0.0.0.0/1 dev rdtun0 metric 0",
		"ip route replace 128.0.0.0/1 dev rdtun0 metric 0",
		"ip route replace 203.0.113.10/32 via 192.0.2.1 dev eth0 metric 1",
	} {
		if !runner.has(command) {
			t.Fatalf("commands = %v, want %q", runner.commands, command)
		}
	}
	if result.Dataplane == nil || !result.Dataplane.BidirectionalTrafficVerified {
		t.Fatalf("Dataplane = %+v, want verified bidirectional evidence", result.Dataplane)
	}
	if len(snapshots) == 0 || snapshots[len(snapshots)-1].InterfaceName != nativeInterfaceName {
		t.Fatalf("state snapshots = %+v, want native interface snapshot", snapshots)
	}

	if err := lifecycle.Cleanup(ctx); err != nil {
		t.Fatalf("Cleanup() error = %v", err)
	}
	if !runtime.closed {
		t.Fatal("runtime closed = false, want true")
	}
	if !tunDevice.closed {
		t.Fatal("tun device closed = false, want true")
	}
}

type recordingNativeCommandRunner struct {
	commands []string
}

func (r *recordingNativeCommandRunner) Run(_ context.Context, name string, args ...string) ([]byte, error) {
	r.commands = append(r.commands, strings.TrimSpace(name+" "+strings.Join(args, " ")))
	return nil, nil
}

func (r *recordingNativeCommandRunner) has(command string) bool {
	for _, got := range r.commands {
		if got == command {
			return true
		}
	}
	return false
}

type scriptedNativeCommandRunner struct {
	outputs  map[string]string
	commands []string
}

func (s *scriptedNativeCommandRunner) Run(_ context.Context, name string, args ...string) ([]byte, error) {
	command := strings.TrimSpace(name + " " + strings.Join(args, " "))
	s.commands = append(s.commands, command)
	return []byte(s.outputs[command]), nil
}

func (s *scriptedNativeCommandRunner) has(command string) bool {
	for _, got := range s.commands {
		if got == command {
			return true
		}
	}
	return false
}

type fakeNativeRuntime struct {
	stats  []wireguardturnruntime.PeerStats
	calls  int
	closed bool
}

func (f *fakeNativeRuntime) PeerStats() (wireguardturnruntime.PeerStats, error) {
	if len(f.stats) == 0 {
		return wireguardturnruntime.PeerStats{}, nil
	}
	if f.calls >= len(f.stats) {
		return f.stats[len(f.stats)-1], nil
	}
	stats := f.stats[f.calls]
	f.calls++
	return stats, nil
}

func (f *fakeNativeRuntime) Close() error {
	f.closed = true
	return nil
}

type fakeNativeTunDevice struct {
	name   string
	mtu    int
	events chan tun.Event
	closed bool
}

func newFakeNativeTunDevice(name string, mtu int) *fakeNativeTunDevice {
	return &fakeNativeTunDevice{
		name:   name,
		mtu:    mtu,
		events: make(chan tun.Event),
	}
}

func (f *fakeNativeTunDevice) File() *os.File {
	return nil
}

func (f *fakeNativeTunDevice) Read(_ [][]byte, _ []int, _ int) (int, error) {
	return 0, io.EOF
}

func (f *fakeNativeTunDevice) Write(bufs [][]byte, _ int) (int, error) {
	return len(bufs), nil
}

func (f *fakeNativeTunDevice) MTU() (int, error) {
	return f.mtu, nil
}

func (f *fakeNativeTunDevice) Name() (string, error) {
	return f.name, nil
}

func (f *fakeNativeTunDevice) Events() <-chan tun.Event {
	return f.events
}

func (f *fakeNativeTunDevice) Close() error {
	if !f.closed {
		close(f.events)
	}
	f.closed = true
	return nil
}

func (f *fakeNativeTunDevice) BatchSize() int {
	return 1
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return f(req)
}

func containsNativeString(values []string, needle string) bool {
	for _, value := range values {
		if value == needle {
			return true
		}
	}
	return false
}

func mustJSON(t *testing.T, value any) []byte {
	t.Helper()
	body, err := json.Marshal(value)
	if err != nil {
		t.Fatalf("marshal fixture: %v", err)
	}
	return body
}

func overrideNativeCleanupRunnerForTest(t *testing.T, runner nativeCommandRunner) func() {
	t.Helper()
	previous := nativeCleanupRunner
	nativeCleanupRunner = runner
	return func() {
		nativeCleanupRunner = previous
	}
}

func deadPIDForTest() int {
	for pid := 99999999; pid < 100000999; pid++ {
		if !pidAlive(pid) {
			return pid
		}
	}
	return 99999999
}
