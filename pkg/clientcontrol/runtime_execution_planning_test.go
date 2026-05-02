package clientcontrol

import (
	"encoding/json"
	"errors"
	"strings"
	"testing"
)

func TestRuntimeExecutionPlanJSONRoundTrip(t *testing.T) {
	plan := RuntimeExecutionPlan{
		AccessMethod:  RuntimeAccessMethodTURNCredentials,
		CarrierFamily: RuntimeCarrierFamilyTURNDTLSOverlay,
		EngineFamily:  RuntimeEngineFamilyWireGuardNative,
		HostAdapter:   RuntimeHostAdapterWindowsWintun,
	}

	body, err := json.Marshal(plan)
	if err != nil {
		t.Fatalf("Marshal(RuntimeExecutionPlan) error = %v", err)
	}

	var restored RuntimeExecutionPlan
	if err := json.Unmarshal(body, &restored); err != nil {
		t.Fatalf("Unmarshal(RuntimeExecutionPlan) error = %v", err)
	}

	if restored != plan {
		t.Fatalf("runtime execution plan round-trip = %+v, want %+v", restored, plan)
	}
}

func TestRuntimeExecutionPlanOmitsEmptyHostAdapter(t *testing.T) {
	body, err := json.Marshal(RuntimeExecutionPlan{
		AccessMethod:  RuntimeAccessMethodWebRTCCallAttach,
		CarrierFamily: RuntimeCarrierFamilyWebRTCDataChannel,
		EngineFamily:  RuntimeEngineFamilyProxyCoreAdapter,
	})
	if err != nil {
		t.Fatalf("Marshal(RuntimeExecutionPlan) error = %v", err)
	}

	if strings.Contains(string(body), "host_adapter") {
		t.Fatalf("Marshal(RuntimeExecutionPlan) body = %s, want host_adapter omitted", body)
	}
}

func TestValidateRuntimeExecutionPlanDescriptorAcceptsDocumentedCurrentOverlayPlan(t *testing.T) {
	descriptor := RuntimeExecutionPlanDescriptor{
		Plan: RuntimeExecutionPlan{
			AccessMethod:  RuntimeAccessMethodTURNCredentials,
			CarrierFamily: RuntimeCarrierFamilyTURNDTLSOverlay,
			EngineFamily:  RuntimeEngineFamilyCustomPacketOverlay,
		},
		SupportState:         RuntimeExecutionPlanSupportStateSupported,
		RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
		RemoteEndpointRole:   RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay,
		Default:              true,
	}

	if err := validateRuntimeExecutionPlanDescriptor(descriptor); err != nil {
		t.Fatalf("validateRuntimeExecutionPlanDescriptor() error = %v", err)
	}
}

func TestValidateRuntimeExecutionPlanDescriptorRejectsUndocumentedCompatibilityEdge(t *testing.T) {
	descriptor := RuntimeExecutionPlanDescriptor{
		Plan: RuntimeExecutionPlan{
			AccessMethod:  RuntimeAccessMethodTURNCredentials,
			CarrierFamily: RuntimeCarrierFamilyWebRTCDataChannel,
			EngineFamily:  RuntimeEngineFamilyWireGuardNative,
			HostAdapter:   RuntimeHostAdapterWindowsWintun,
		},
		SupportState:         RuntimeExecutionPlanSupportStateSupported,
		RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
		RemoteEndpointRole:   RuntimeRemoteEndpointRoleWireGuardRawDatagram,
	}

	if err := validateRuntimeExecutionPlanDescriptor(descriptor); err == nil {
		t.Fatal("validateRuntimeExecutionPlanDescriptor() error = nil, want compatibility matrix failure")
	}
}

func TestValidateRuntimeExecutionPlanDescriptorRejectsWireGuardPlanWithDTLSRole(t *testing.T) {
	descriptor := RuntimeExecutionPlanDescriptor{
		Plan: RuntimeExecutionPlan{
			AccessMethod:  RuntimeAccessMethodTURNCredentials,
			CarrierFamily: RuntimeCarrierFamilyTURNDatagram,
			EngineFamily:  RuntimeEngineFamilyWireGuardNative,
			HostAdapter:   RuntimeHostAdapterWindowsWintun,
		},
		SupportState:         RuntimeExecutionPlanSupportStateSupported,
		RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
		RemoteEndpointRole:   RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay,
	}

	err := validateRuntimeExecutionPlanDescriptor(descriptor)
	if err == nil {
		t.Fatal("validateRuntimeExecutionPlanDescriptor() error = nil, want protocol mismatch failure")
	}
	if !strings.Contains(err.Error(), "remote_endpoint_role") {
		t.Fatalf("validateRuntimeExecutionPlanDescriptor() error = %v, want remote_endpoint_role detail", err)
	}
}

func TestValidateRuntimeExecutionPlanDescriptorRejectsExperimentalWebRTCPlanWithoutCapabilityGate(t *testing.T) {
	descriptor := RuntimeExecutionPlanDescriptor{
		Plan: RuntimeExecutionPlan{
			AccessMethod:  RuntimeAccessMethodWebRTCCallAttach,
			CarrierFamily: RuntimeCarrierFamilyWebRTCDataChannel,
			EngineFamily:  RuntimeEngineFamilyCustomPacketOverlay,
		},
		SupportState:         RuntimeExecutionPlanSupportStateExperimental,
		RemoteEndpointFamily: RuntimeRemoteEndpointFamilyWebRTCCallEndpoint,
	}

	if err := validateRuntimeExecutionPlanDescriptor(descriptor); err == nil {
		t.Fatal("validateRuntimeExecutionPlanDescriptor() error = nil, want capability-gate failure")
	}
}

func TestSelectRuntimeExecutionPlanDescriptorDefaultsToSupportedPlan(t *testing.T) {
	selected, err := selectRuntimeExecutionPlanDescriptor([]RuntimeExecutionPlanDescriptor{
		{
			Plan: RuntimeExecutionPlan{
				AccessMethod:  RuntimeAccessMethodTURNCredentials,
				CarrierFamily: RuntimeCarrierFamilyTURNDTLSOverlay,
				EngineFamily:  RuntimeEngineFamilyCustomPacketOverlay,
			},
			SupportState:         RuntimeExecutionPlanSupportStateSupported,
			RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay,
			Default:              true,
		},
		{
			Plan: RuntimeExecutionPlan{
				AccessMethod:  RuntimeAccessMethodTURNCredentials,
				CarrierFamily: RuntimeCarrierFamilyTURNDatagram,
				EngineFamily:  RuntimeEngineFamilyWireGuardNative,
				HostAdapter:   RuntimeHostAdapterLinuxTun,
			},
			SupportState:         RuntimeExecutionPlanSupportStateUnavailable,
			RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   RuntimeRemoteEndpointRoleWireGuardRawDatagram,
		},
	}, nil)
	if err != nil {
		t.Fatalf("selectRuntimeExecutionPlanDescriptor() error = %v", err)
	}
	if selected.Plan.EngineFamily != RuntimeEngineFamilyCustomPacketOverlay {
		t.Fatalf("selectRuntimeExecutionPlanDescriptor().plan.engine_family = %q, want %q", selected.Plan.EngineFamily, RuntimeEngineFamilyCustomPacketOverlay)
	}
}

func TestSelectRuntimeExecutionPlanDescriptorRejectsUnavailableRequestedPlan(t *testing.T) {
	requested := &RuntimeExecutionPlan{
		AccessMethod:  RuntimeAccessMethodTURNCredentials,
		CarrierFamily: RuntimeCarrierFamilyTURNDatagram,
		EngineFamily:  RuntimeEngineFamilyWireGuardNative,
		HostAdapter:   RuntimeHostAdapterLinuxTun,
	}
	_, err := selectRuntimeExecutionPlanDescriptor([]RuntimeExecutionPlanDescriptor{{
		Plan:                 *requested,
		SupportState:         RuntimeExecutionPlanSupportStateUnavailable,
		RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
		RemoteEndpointRole:   RuntimeRemoteEndpointRoleWireGuardRawDatagram,
	}}, requested)
	if !errors.Is(err, errRuntimeExecutionPlanUnavailable) {
		t.Fatalf("selectRuntimeExecutionPlanDescriptor() error = %v, want unavailable", err)
	}
}

func TestSelectRuntimeExecutionPlanDescriptorRequiresSelectionForMultipleDefaultSupportedPlans(t *testing.T) {
	_, err := selectRuntimeExecutionPlanDescriptor([]RuntimeExecutionPlanDescriptor{
		{
			Plan: RuntimeExecutionPlan{
				AccessMethod:  RuntimeAccessMethodTURNCredentials,
				CarrierFamily: RuntimeCarrierFamilyTURNDTLSOverlay,
				EngineFamily:  RuntimeEngineFamilyCustomPacketOverlay,
			},
			SupportState:         RuntimeExecutionPlanSupportStateSupported,
			RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay,
			Default:              true,
		},
		{
			Plan: RuntimeExecutionPlan{
				AccessMethod:  RuntimeAccessMethodTURNCredentials,
				CarrierFamily: RuntimeCarrierFamilyTURNDatagram,
				EngineFamily:  RuntimeEngineFamilyWireGuardNative,
				HostAdapter:   RuntimeHostAdapterLinuxTun,
			},
			SupportState:         RuntimeExecutionPlanSupportStateSupported,
			RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   RuntimeRemoteEndpointRoleWireGuardRawDatagram,
			Default:              true,
		},
	}, nil)
	if !errors.Is(err, errRuntimeExecutionPlanSelectionRequired) {
		t.Fatalf("selectRuntimeExecutionPlanDescriptor() error = %v, want selection required", err)
	}
}
