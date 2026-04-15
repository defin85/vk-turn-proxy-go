//go:build !android

package androidplatformbridge

import (
	"context"
	"fmt"
	"unsafe"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

type VPNServiceLifecycle struct{}

func NewVPNServiceLifecycle() *VPNServiceLifecycle {
	return &VPNServiceLifecycle{}
}

func Register(_ unsafe.Pointer, _ unsafe.Pointer) {}

func Clear(_ unsafe.Pointer) {}

func (l *VPNServiceLifecycle) AcquirePermission(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest) error {
	return fmt.Errorf("android platform tunnel bridge is unavailable on this build")
}

func (l *VPNServiceLifecycle) ResumeAfterPermission(_ context.Context, _ string, _ clientcontrol.PlatformTunnelStartRequest) error {
	return fmt.Errorf("android platform tunnel bridge is unavailable on this build")
}

func (l *VPNServiceLifecycle) ValidateRoutePolicy(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest) error {
	return fmt.Errorf("android platform tunnel bridge is unavailable on this build")
}

func (l *VPNServiceLifecycle) BringupHost(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest, _ *clientcontrol.RuntimeExecutionPlan, _ *clientcontrol.WireGuardTurnExecutionLease) error {
	return fmt.Errorf("android platform tunnel bridge is unavailable on this build")
}

func (l *VPNServiceLifecycle) AttachRuntime(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest, _ *clientcontrol.RuntimeExecutionPlan, _ *clientcontrol.WireGuardTurnExecutionLease) error {
	return fmt.Errorf("android platform tunnel bridge is unavailable on this build")
}

func (l *VPNServiceLifecycle) Cleanup(_ context.Context) error {
	return nil
}
