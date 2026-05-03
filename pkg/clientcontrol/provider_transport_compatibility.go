package clientcontrol

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"
)

const providerTransportCompatibilityContractVersion = "1"

type ProviderTransportCompatibilityStatus string

const (
	ProviderTransportCompatibilityStatusStartable       ProviderTransportCompatibilityStatus = "startable"
	ProviderTransportCompatibilityStatusSetupNeeded     ProviderTransportCompatibilityStatus = "setup_needed"
	ProviderTransportCompatibilityStatusUnsupported     ProviderTransportCompatibilityStatus = "unsupported"
	ProviderTransportCompatibilityStatusStale           ProviderTransportCompatibilityStatus = "stale"
	ProviderTransportCompatibilityStatusDegraded        ProviderTransportCompatibilityStatus = "degraded"
	ProviderTransportCompatibilityStatusMissingEvidence ProviderTransportCompatibilityStatus = "missing_evidence"
	ProviderTransportCompatibilityStatusUnavailable     ProviderTransportCompatibilityStatus = "unavailable"
)

type ProviderTransportCompatibilityFailingAxis string

const (
	ProviderTransportCompatibilityAxisProviderSource       ProviderTransportCompatibilityFailingAxis = "provider_source"
	ProviderTransportCompatibilityAxisProviderArtifact     ProviderTransportCompatibilityFailingAxis = "provider_artifact"
	ProviderTransportCompatibilityAxisArtifactAccessMethod ProviderTransportCompatibilityFailingAxis = "artifact_access_method"
	ProviderTransportCompatibilityAxisCarrierFamily        ProviderTransportCompatibilityFailingAxis = "carrier_family"
	ProviderTransportCompatibilityAxisEngineFamily         ProviderTransportCompatibilityFailingAxis = "engine_family"
	ProviderTransportCompatibilityAxisHostAdapter          ProviderTransportCompatibilityFailingAxis = "host_adapter"
	ProviderTransportCompatibilityAxisTransportProfile     ProviderTransportCompatibilityFailingAxis = "transport_profile"
	ProviderTransportCompatibilityAxisDegradedPolicy       ProviderTransportCompatibilityFailingAxis = "degraded_policy"
	ProviderTransportCompatibilityAxisEvidence             ProviderTransportCompatibilityFailingAxis = "evidence"
	ProviderTransportCompatibilityAxisHostCapability       ProviderTransportCompatibilityFailingAxis = "host_capability"
)

type ProviderTransportCompatibilityReasonCode string

const (
	ProviderTransportCompatibilityReasonReady                            ProviderTransportCompatibilityReasonCode = "ready"
	ProviderTransportCompatibilityReasonProviderSourceRequired           ProviderTransportCompatibilityReasonCode = "provider_source_required"
	ProviderTransportCompatibilityReasonProviderSourceNotFound           ProviderTransportCompatibilityReasonCode = "provider_source_not_found"
	ProviderTransportCompatibilityReasonProviderSourceNotResolved        ProviderTransportCompatibilityReasonCode = "provider_source_not_resolved"
	ProviderTransportCompatibilityReasonProviderArtifactMissing          ProviderTransportCompatibilityReasonCode = "provider_artifact_missing"
	ProviderTransportCompatibilityReasonProviderArtifactStale            ProviderTransportCompatibilityReasonCode = "provider_artifact_stale"
	ProviderTransportCompatibilityReasonProviderArtifactDegraded         ProviderTransportCompatibilityReasonCode = "provider_artifact_degraded"
	ProviderTransportCompatibilityReasonProviderArtifactUnavailable      ProviderTransportCompatibilityReasonCode = "provider_artifact_unavailable"
	ProviderTransportCompatibilityReasonProviderArtifactUnsupported      ProviderTransportCompatibilityReasonCode = "provider_artifact_unsupported"
	ProviderTransportCompatibilityReasonArtifactAccessMethodUnsupported  ProviderTransportCompatibilityReasonCode = "artifact_access_method_unsupported"
	ProviderTransportCompatibilityReasonCarrierFamilyUnsupported         ProviderTransportCompatibilityReasonCode = "carrier_family_unsupported"
	ProviderTransportCompatibilityReasonEngineFamilyUnsupported          ProviderTransportCompatibilityReasonCode = "engine_family_unsupported"
	ProviderTransportCompatibilityReasonHostAdapterUnsupported           ProviderTransportCompatibilityReasonCode = "host_adapter_unsupported"
	ProviderTransportCompatibilityReasonHostAdapterUnavailable           ProviderTransportCompatibilityReasonCode = "host_adapter_unavailable"
	ProviderTransportCompatibilityReasonHostCapabilityMissing            ProviderTransportCompatibilityReasonCode = "host_capability_missing"
	ProviderTransportCompatibilityReasonRuntimePlanRequired              ProviderTransportCompatibilityReasonCode = "runtime_plan_required"
	ProviderTransportCompatibilityReasonRuntimePlanUnsupported           ProviderTransportCompatibilityReasonCode = "runtime_plan_unsupported"
	ProviderTransportCompatibilityReasonRuntimePlanUnavailable           ProviderTransportCompatibilityReasonCode = "runtime_plan_unavailable"
	ProviderTransportCompatibilityReasonRuntimePlanExperimental          ProviderTransportCompatibilityReasonCode = "runtime_plan_experimental"
	ProviderTransportCompatibilityReasonTransportProfileRequired         ProviderTransportCompatibilityReasonCode = "transport_profile_required"
	ProviderTransportCompatibilityReasonTransportProfileMissing          ProviderTransportCompatibilityReasonCode = "transport_profile_missing"
	ProviderTransportCompatibilityReasonTransportProfileUnselected       ProviderTransportCompatibilityReasonCode = "transport_profile_unselected"
	ProviderTransportCompatibilityReasonTransportProfileStale            ProviderTransportCompatibilityReasonCode = "transport_profile_stale"
	ProviderTransportCompatibilityReasonTransportProfileInvalid          ProviderTransportCompatibilityReasonCode = "transport_profile_invalid"
	ProviderTransportCompatibilityReasonTransportProfileIncompatibleKind ProviderTransportCompatibilityReasonCode = "transport_profile_incompatible_kind"
	ProviderTransportCompatibilityReasonTransportProfileStoreUnavailable ProviderTransportCompatibilityReasonCode = "transport_profile_store_unavailable"
	ProviderTransportCompatibilityReasonDegradedPolicyRequired           ProviderTransportCompatibilityReasonCode = "degraded_policy_required"
	ProviderTransportCompatibilityReasonEvidenceMissing                  ProviderTransportCompatibilityReasonCode = "evidence_missing"
)

type ProviderTransportCompatibilityCapability struct {
	Version             string                                      `json:"version"`
	CandidateEndpoint   string                                      `json:"candidate_endpoint"`
	Statuses            []ProviderTransportCompatibilityStatus      `json:"statuses,omitempty"`
	FailingAxes         []ProviderTransportCompatibilityFailingAxis `json:"failing_axes,omitempty"`
	ReasonCodes         []ProviderTransportCompatibilityReasonCode  `json:"reason_codes,omitempty"`
	RedactionGuarantees []string                                    `json:"redaction_guarantees,omitempty"`
}

type ProviderTransportSourceReference struct {
	ProviderID   string `json:"provider_id,omitempty"`
	SourceID     string `json:"source_id,omitempty"`
	ResolutionID string `json:"resolution_id,omitempty"`
}

type ProviderTransportArtifactReference struct {
	ProviderID    string                `json:"provider_id,omitempty"`
	ResolutionID  string                `json:"resolution_id,omitempty"`
	Family        ArtifactFamily        `json:"family,omitempty"`
	AccessMethods []RuntimeAccessMethod `json:"access_methods,omitempty"`
	ExpiresAt     *time.Time            `json:"expires_at,omitempty"`
}

type ProviderTransportCompatibilityStartupReference struct {
	CandidateID      string                              `json:"candidate_id,omitempty"`
	Source           *ProviderTransportSourceReference   `json:"source,omitempty"`
	Artifact         *ProviderTransportArtifactReference `json:"artifact,omitempty"`
	ExecutionPlan    *RuntimeExecutionPlan               `json:"execution_plan,omitempty"`
	TransportProfile *TransportProfileReference          `json:"transport_profile,omitempty"`
}

type ProviderTransportCompatibilityRequest struct {
	ResolutionID      string                              `json:"resolution_id,omitempty"`
	CandidateID       string                              `json:"candidate_id,omitempty"`
	Source            *ProviderTransportSourceReference   `json:"source,omitempty"`
	Artifact          *ProviderTransportArtifactReference `json:"artifact,omitempty"`
	ExecutionPlan     *RuntimeExecutionPlan               `json:"execution_plan,omitempty"`
	TransportProfile  *TransportProfileReference          `json:"transport_profile,omitempty"`
	RequireEvidence   bool                                `json:"require_evidence,omitempty"`
	AllowDegradedPlan bool                                `json:"allow_degraded_plan,omitempty"`
}

type ProviderTransportCompatibilityResponse struct {
	Version     string                                    `json:"version"`
	GeneratedAt time.Time                                 `json:"generated_at"`
	Candidates  []ProviderTransportCompatibilityCandidate `json:"candidates,omitempty"`
}

type ProviderTransportCompatibilityCandidate struct {
	ID                            string                                    `json:"id"`
	Source                        *ProviderTransportSourceReference         `json:"source,omitempty"`
	Artifact                      *ProviderTransportArtifactReference       `json:"artifact,omitempty"`
	ExecutionPlan                 RuntimeExecutionPlanDescriptor            `json:"execution_plan"`
	RequiredTransportProfileKinds []TransportProfileKind                    `json:"required_transport_profile_kinds,omitempty"`
	SelectedTransportProfile      *TransportProfileReference                `json:"selected_transport_profile,omitempty"`
	Status                        ProviderTransportCompatibilityStatus      `json:"status"`
	Startable                     bool                                      `json:"startable"`
	FailingAxis                   ProviderTransportCompatibilityFailingAxis `json:"failing_axis,omitempty"`
	ReasonCode                    ProviderTransportCompatibilityReasonCode  `json:"reason_code,omitempty"`
	Message                       string                                    `json:"message,omitempty"`
}

type ProviderTransportCompatibilityFailure struct {
	CandidateID string                                    `json:"candidate_id,omitempty"`
	Status      ProviderTransportCompatibilityStatus      `json:"status"`
	FailingAxis ProviderTransportCompatibilityFailingAxis `json:"failing_axis,omitempty"`
	ReasonCode  ProviderTransportCompatibilityReasonCode  `json:"reason_code,omitempty"`
	Message     string                                    `json:"message,omitempty"`
}

func defaultProviderTransportCompatibilityCapability() ProviderTransportCompatibilityCapability {
	return ProviderTransportCompatibilityCapability{
		Version:           providerTransportCompatibilityContractVersion,
		CandidateEndpoint: "/v1/provider-transport-compatibility/candidates",
		Statuses: []ProviderTransportCompatibilityStatus{
			ProviderTransportCompatibilityStatusStartable,
			ProviderTransportCompatibilityStatusSetupNeeded,
			ProviderTransportCompatibilityStatusUnsupported,
			ProviderTransportCompatibilityStatusStale,
			ProviderTransportCompatibilityStatusDegraded,
			ProviderTransportCompatibilityStatusMissingEvidence,
			ProviderTransportCompatibilityStatusUnavailable,
		},
		FailingAxes: []ProviderTransportCompatibilityFailingAxis{
			ProviderTransportCompatibilityAxisProviderSource,
			ProviderTransportCompatibilityAxisProviderArtifact,
			ProviderTransportCompatibilityAxisArtifactAccessMethod,
			ProviderTransportCompatibilityAxisCarrierFamily,
			ProviderTransportCompatibilityAxisEngineFamily,
			ProviderTransportCompatibilityAxisHostAdapter,
			ProviderTransportCompatibilityAxisTransportProfile,
			ProviderTransportCompatibilityAxisDegradedPolicy,
			ProviderTransportCompatibilityAxisEvidence,
			ProviderTransportCompatibilityAxisHostCapability,
		},
		ReasonCodes: []ProviderTransportCompatibilityReasonCode{
			ProviderTransportCompatibilityReasonReady,
			ProviderTransportCompatibilityReasonProviderSourceRequired,
			ProviderTransportCompatibilityReasonProviderSourceNotFound,
			ProviderTransportCompatibilityReasonProviderSourceNotResolved,
			ProviderTransportCompatibilityReasonProviderArtifactMissing,
			ProviderTransportCompatibilityReasonProviderArtifactStale,
			ProviderTransportCompatibilityReasonProviderArtifactDegraded,
			ProviderTransportCompatibilityReasonProviderArtifactUnavailable,
			ProviderTransportCompatibilityReasonProviderArtifactUnsupported,
			ProviderTransportCompatibilityReasonArtifactAccessMethodUnsupported,
			ProviderTransportCompatibilityReasonCarrierFamilyUnsupported,
			ProviderTransportCompatibilityReasonEngineFamilyUnsupported,
			ProviderTransportCompatibilityReasonHostAdapterUnsupported,
			ProviderTransportCompatibilityReasonHostAdapterUnavailable,
			ProviderTransportCompatibilityReasonHostCapabilityMissing,
			ProviderTransportCompatibilityReasonRuntimePlanRequired,
			ProviderTransportCompatibilityReasonRuntimePlanUnsupported,
			ProviderTransportCompatibilityReasonRuntimePlanUnavailable,
			ProviderTransportCompatibilityReasonRuntimePlanExperimental,
			ProviderTransportCompatibilityReasonTransportProfileRequired,
			ProviderTransportCompatibilityReasonTransportProfileMissing,
			ProviderTransportCompatibilityReasonTransportProfileUnselected,
			ProviderTransportCompatibilityReasonTransportProfileStale,
			ProviderTransportCompatibilityReasonTransportProfileInvalid,
			ProviderTransportCompatibilityReasonTransportProfileIncompatibleKind,
			ProviderTransportCompatibilityReasonTransportProfileStoreUnavailable,
			ProviderTransportCompatibilityReasonDegradedPolicyRequired,
			ProviderTransportCompatibilityReasonEvidenceMissing,
		},
		RedactionGuarantees: []string{
			"provider_secrets_redacted",
			"transport_profile_secrets_redacted",
			"host_private_paths_redacted",
		},
	}
}

func cloneProviderTransportCompatibilityCapability(
	capability *ProviderTransportCompatibilityCapability,
) *ProviderTransportCompatibilityCapability {
	if capability == nil {
		return nil
	}
	clone := *capability
	clone.Statuses = append([]ProviderTransportCompatibilityStatus(nil), capability.Statuses...)
	clone.FailingAxes = append([]ProviderTransportCompatibilityFailingAxis(nil), capability.FailingAxes...)
	clone.ReasonCodes = append([]ProviderTransportCompatibilityReasonCode(nil), capability.ReasonCodes...)
	clone.RedactionGuarantees = append([]string(nil), capability.RedactionGuarantees...)
	return &clone
}

func cloneProviderTransportCompatibilityFailure(
	failure *ProviderTransportCompatibilityFailure,
) *ProviderTransportCompatibilityFailure {
	if failure == nil {
		return nil
	}
	clone := *failure
	return &clone
}

func cloneProviderTransportSourceReference(
	ref *ProviderTransportSourceReference,
) *ProviderTransportSourceReference {
	if ref == nil {
		return nil
	}
	clone := *ref
	return &clone
}

func cloneProviderTransportArtifactReference(
	ref *ProviderTransportArtifactReference,
) *ProviderTransportArtifactReference {
	if ref == nil {
		return nil
	}
	clone := *ref
	clone.AccessMethods = append([]RuntimeAccessMethod(nil), ref.AccessMethods...)
	if ref.ExpiresAt != nil {
		expiresAt := ref.ExpiresAt.UTC()
		clone.ExpiresAt = &expiresAt
	}
	return &clone
}

func cloneProviderTransportCompatibilityStartupReference(
	ref *ProviderTransportCompatibilityStartupReference,
) *ProviderTransportCompatibilityStartupReference {
	if ref == nil {
		return nil
	}
	clone := *ref
	clone.Source = cloneProviderTransportSourceReference(ref.Source)
	clone.Artifact = cloneProviderTransportArtifactReference(ref.Artifact)
	clone.ExecutionPlan = cloneRuntimeExecutionPlan(ref.ExecutionPlan)
	clone.TransportProfile = cloneTransportProfileReference(ref.TransportProfile)
	return &clone
}

func ProviderTransportCompatibilityCandidateStartable(
	candidate ProviderTransportCompatibilityCandidate,
) bool {
	if !isKnownProviderTransportCompatibilityStatus(candidate.Status) {
		return false
	}
	if strings.TrimSpace(string(candidate.FailingAxis)) != "" {
		return false
	}
	return candidate.Status == ProviderTransportCompatibilityStatusStartable
}

func (h *Host) ProviderTransportCompatibilityCandidates(
	req ProviderTransportCompatibilityRequest,
) ProviderTransportCompatibilityResponse {
	now := h.now().UTC()
	h.mu.Lock()
	response, event := h.providerTransportCompatibilityCandidatesLocked(req, now)
	h.mu.Unlock()
	if event != nil {
		h.publishEvent(*event)
	}
	return response
}

func (h *Host) providerTransportCompatibilityCandidatesLocked(
	req ProviderTransportCompatibilityRequest,
	now time.Time,
) (ProviderTransportCompatibilityResponse, *Event) {
	req = normalizeProviderTransportCompatibilityRequest(req)
	response := ProviderTransportCompatibilityResponse{
		Version:     providerTransportCompatibilityContractVersion,
		GeneratedAt: now,
	}

	resolutionID := providerTransportCompatibilityResolutionID(req)
	source := cloneProviderTransportSourceReference(req.Source)
	if source == nil {
		source = &ProviderTransportSourceReference{}
	}
	source.ResolutionID = firstNonEmpty(source.ResolutionID, resolutionID)
	if resolutionID == "" {
		response.Candidates = append(response.Candidates, providerTransportFailureCandidate(
			req,
			source,
			nil,
			RuntimeExecutionPlanDescriptor{},
			ProviderTransportCompatibilityStatusSetupNeeded,
			ProviderTransportCompatibilityAxisProviderSource,
			ProviderTransportCompatibilityReasonProviderSourceRequired,
			"provider source or resolved artifact reference is required",
		))
		return response, nil
	}

	managed, ok := h.resolutions[resolutionID]
	if !ok {
		response.Candidates = append(response.Candidates, providerTransportFailureCandidate(
			req,
			source,
			cloneProviderTransportArtifactReference(req.Artifact),
			RuntimeExecutionPlanDescriptor{},
			ProviderTransportCompatibilityStatusStale,
			ProviderTransportCompatibilityAxisProviderSource,
			ProviderTransportCompatibilityReasonProviderSourceNotFound,
			fmt.Sprintf("provider resolution %s was not found", resolutionID),
		))
		return response, nil
	}
	event := h.expireResolutionLocked(managed)
	snapshot := managed.snapshot
	source.ProviderID = firstNonEmpty(source.ProviderID, snapshot.Provider)
	artifact := providerTransportArtifactReferenceFromResolution(snapshot)
	if req.Artifact != nil {
		artifact.ProviderID = firstNonEmpty(req.Artifact.ProviderID, artifact.ProviderID)
		artifact.ResolutionID = firstNonEmpty(req.Artifact.ResolutionID, artifact.ResolutionID)
	}

	switch snapshot.State {
	case ResolutionStateResolved:
	case ResolutionStateExpired:
		response.Candidates = append(response.Candidates, providerTransportFailureCandidate(
			req,
			source,
			artifact,
			RuntimeExecutionPlanDescriptor{},
			ProviderTransportCompatibilityStatusStale,
			ProviderTransportCompatibilityAxisProviderArtifact,
			ProviderTransportCompatibilityReasonProviderArtifactStale,
			fmt.Sprintf("provider resolution %s is expired", resolutionID),
		))
		return response, event
	default:
		response.Candidates = append(response.Candidates, providerTransportFailureCandidate(
			req,
			source,
			artifact,
			RuntimeExecutionPlanDescriptor{},
			ProviderTransportCompatibilityStatusSetupNeeded,
			ProviderTransportCompatibilityAxisProviderSource,
			ProviderTransportCompatibilityReasonProviderSourceNotResolved,
			fmt.Sprintf("provider resolution %s is %s", resolutionID, snapshot.State),
		))
		return response, event
	}
	if mismatch := providerTransportSourceMismatch(req.Source, snapshot); mismatch != "" {
		response.Candidates = append(response.Candidates, providerTransportFailureCandidate(
			req,
			source,
			artifact,
			RuntimeExecutionPlanDescriptor{},
			ProviderTransportCompatibilityStatusStale,
			ProviderTransportCompatibilityAxisProviderSource,
			ProviderTransportCompatibilityReasonProviderSourceNotFound,
			mismatch,
		))
		return response, event
	}
	if mismatch := providerTransportArtifactMismatch(req.Artifact, providerTransportArtifactReferenceFromResolution(snapshot)); mismatch != "" {
		response.Candidates = append(response.Candidates, providerTransportFailureCandidate(
			req,
			source,
			artifact,
			RuntimeExecutionPlanDescriptor{},
			ProviderTransportCompatibilityStatusStale,
			ProviderTransportCompatibilityAxisProviderArtifact,
			ProviderTransportCompatibilityReasonProviderArtifactStale,
			mismatch,
		))
		return response, event
	}
	if snapshot.Artifact == nil {
		response.Candidates = append(response.Candidates, providerTransportFailureCandidate(
			req,
			source,
			artifact,
			RuntimeExecutionPlanDescriptor{},
			ProviderTransportCompatibilityStatusUnsupported,
			ProviderTransportCompatibilityAxisProviderArtifact,
			ProviderTransportCompatibilityReasonProviderArtifactMissing,
			fmt.Sprintf("provider resolution %s has no runtime artifact", resolutionID),
		))
		return response, event
	}
	if failure := providerTransportRemoteVPSArtifactFailure(snapshot, now); failure != nil {
		response.Candidates = append(response.Candidates, providerTransportFailureCandidate(
			req,
			source,
			artifact,
			RuntimeExecutionPlanDescriptor{},
			failure.Status,
			failure.FailingAxis,
			failure.ReasonCode,
			failure.Message,
		))
		return response, event
	}

	descriptors := providerTransportExecutionPlanDescriptors(snapshot, req.ExecutionPlan)
	if len(descriptors) == 0 {
		descriptor := RuntimeExecutionPlanDescriptor{}
		if req.ExecutionPlan != nil {
			descriptor.Plan = *req.ExecutionPlan
		}
		response.Candidates = append(response.Candidates, providerTransportFailureCandidate(
			req,
			source,
			artifact,
			descriptor,
			ProviderTransportCompatibilityStatusUnsupported,
			ProviderTransportCompatibilityAxisEngineFamily,
			ProviderTransportCompatibilityReasonRuntimePlanUnsupported,
			"provider artifact does not advertise the requested runtime execution plan",
		))
		return response, event
	}
	for _, descriptor := range descriptors {
		response.Candidates = append(
			response.Candidates,
			h.providerTransportCompatibilityCandidateForDescriptorLocked(req, source, artifact, descriptor),
		)
	}
	if candidateID := strings.TrimSpace(req.CandidateID); candidateID != "" {
		filtered := response.Candidates[:0]
		for _, candidate := range response.Candidates {
			if candidate.ID == candidateID {
				filtered = append(filtered, candidate)
			}
		}
		response.Candidates = filtered
	}
	return response, event
}

func (h *Host) providerTransportCompatibilityCandidateForDescriptorLocked(
	req ProviderTransportCompatibilityRequest,
	source *ProviderTransportSourceReference,
	artifact *ProviderTransportArtifactReference,
	descriptor RuntimeExecutionPlanDescriptor,
) ProviderTransportCompatibilityCandidate {
	descriptor = cloneRuntimeExecutionPlanDescriptor(descriptor)
	requiredKinds := descriptor.RequiredTransportProfileKinds
	if len(requiredKinds) == 0 {
		requiredKinds = h.requiredTransportProfileKindsForPlanLocked(descriptor.Plan)
		descriptor.RequiredTransportProfileKinds = append([]TransportProfileKind(nil), requiredKinds...)
	}
	candidate := ProviderTransportCompatibilityCandidate{
		Source:                        cloneProviderTransportSourceReference(source),
		Artifact:                      cloneProviderTransportArtifactReference(artifact),
		ExecutionPlan:                 descriptor,
		RequiredTransportProfileKinds: append([]TransportProfileKind(nil), requiredKinds...),
		Status:                        ProviderTransportCompatibilityStatusStartable,
		ReasonCode:                    ProviderTransportCompatibilityReasonReady,
	}

	if !providerTransportArtifactSupportsAccessMethod(artifact, descriptor.Plan.AccessMethod) {
		return providerTransportSetCandidateFailure(
			req,
			candidate,
			ProviderTransportCompatibilityStatusUnsupported,
			ProviderTransportCompatibilityAxisArtifactAccessMethod,
			ProviderTransportCompatibilityReasonArtifactAccessMethodUnsupported,
			fmt.Sprintf("provider artifact does not expose access method %s", descriptor.Plan.AccessMethod),
		)
	}
	if !isKnownRuntimeCarrierFamily(descriptor.Plan.CarrierFamily) {
		return providerTransportSetCandidateFailure(
			req,
			candidate,
			ProviderTransportCompatibilityStatusUnsupported,
			ProviderTransportCompatibilityAxisCarrierFamily,
			ProviderTransportCompatibilityReasonCarrierFamilyUnsupported,
			fmt.Sprintf("carrier family %s is not supported by this shell contract", descriptor.Plan.CarrierFamily),
		)
	}
	if !isKnownRuntimeEngineFamily(descriptor.Plan.EngineFamily) {
		return providerTransportSetCandidateFailure(
			req,
			candidate,
			ProviderTransportCompatibilityStatusUnsupported,
			ProviderTransportCompatibilityAxisEngineFamily,
			ProviderTransportCompatibilityReasonEngineFamilyUnsupported,
			fmt.Sprintf("engine family %s is not supported by this shell contract", descriptor.Plan.EngineFamily),
		)
	}
	if strings.TrimSpace(string(descriptor.Plan.HostAdapter)) != "" &&
		!isKnownRuntimeHostAdapter(descriptor.Plan.HostAdapter) {
		return providerTransportSetCandidateFailure(
			req,
			candidate,
			ProviderTransportCompatibilityStatusUnsupported,
			ProviderTransportCompatibilityAxisHostAdapter,
			ProviderTransportCompatibilityReasonHostAdapterUnsupported,
			fmt.Sprintf("host adapter %s is not supported by this shell contract", descriptor.Plan.HostAdapter),
		)
	}
	switch descriptor.SupportState {
	case RuntimeExecutionPlanSupportStateSupported:
	case RuntimeExecutionPlanSupportStateExperimental:
		if !req.AllowDegradedPlan {
			return providerTransportSetCandidateFailure(
				req,
				candidate,
				ProviderTransportCompatibilityStatusDegraded,
				ProviderTransportCompatibilityAxisDegradedPolicy,
				ProviderTransportCompatibilityReasonRuntimePlanExperimental,
				runtimeExecutionPlanUnavailableMessage(descriptor),
			)
		}
	default:
		axis := ProviderTransportCompatibilityAxisHostCapability
		reason := ProviderTransportCompatibilityReasonRuntimePlanUnavailable
		if strings.TrimSpace(string(descriptor.Plan.HostAdapter)) != "" {
			axis = ProviderTransportCompatibilityAxisHostAdapter
			reason = ProviderTransportCompatibilityReasonHostAdapterUnavailable
		}
		return providerTransportSetCandidateFailure(
			req,
			candidate,
			ProviderTransportCompatibilityStatusUnavailable,
			axis,
			reason,
			runtimeExecutionPlanUnavailableMessage(descriptor),
		)
	}
	if req.RequireEvidence {
		return providerTransportSetCandidateFailure(
			req,
			candidate,
			ProviderTransportCompatibilityStatusMissingEvidence,
			ProviderTransportCompatibilityAxisEvidence,
			ProviderTransportCompatibilityReasonEvidenceMissing,
			"readiness evidence is required before this candidate can be claimed ready",
		)
	}
	if len(requiredKinds) == 0 {
		return providerTransportFinalizeCandidate(req, candidate)
	}
	if !h.transportProfileStoreEnabled {
		return providerTransportSetCandidateFailure(
			req,
			candidate,
			ProviderTransportCompatibilityStatusUnavailable,
			ProviderTransportCompatibilityAxisHostCapability,
			ProviderTransportCompatibilityReasonTransportProfileStoreUnavailable,
			"host does not advertise VPN transport profile store support",
		)
	}

	if req.TransportProfile != nil && strings.TrimSpace(req.TransportProfile.ProfileID) != "" {
		ref, err := h.validateTransportProfileRefLocked(*req.TransportProfile, descriptor.Plan, requiredKinds)
		if err != nil {
			return providerTransportCandidateForTransportProfileError(req, candidate, err, true)
		}
		candidate.SelectedTransportProfile = ref
		candidate.ExecutionPlan.TransportProfile = &TransportProfilePrerequisiteStatus{
			RequiredKinds:   append([]TransportProfileKind(nil), requiredKinds...),
			State:           TransportProfileCompatibilityStateCompatible,
			SelectedProfile: cloneTransportProfileReference(ref),
		}
		return providerTransportFinalizeCandidate(req, candidate)
	}

	status := h.transportProfilePrerequisiteStatusLocked(descriptor.Plan, requiredKinds)
	candidate.ExecutionPlan.TransportProfile = cloneTransportProfilePrerequisiteStatus(status)
	ref := firstTransportProfileReference(status.SelectedProfile, status.DefaultProfile)
	if ref == nil {
		reason := ProviderTransportCompatibilityReasonTransportProfileRequired
		if status.MissingKind == "" {
			reason = ProviderTransportCompatibilityReasonTransportProfileUnselected
		}
		message := firstNonEmpty(status.Message, fmt.Sprintf("select a %s transport profile for this execution plan", requiredKinds[0]))
		return providerTransportSetCandidateFailure(
			req,
			candidate,
			ProviderTransportCompatibilityStatusSetupNeeded,
			ProviderTransportCompatibilityAxisTransportProfile,
			reason,
			message,
		)
	}
	candidate.SelectedTransportProfile = cloneTransportProfileReference(ref)
	return providerTransportFinalizeCandidate(req, candidate)
}

func (h *Host) validateProviderTransportCompatibilityForStartup(
	req PlatformTunnelStartRequest,
) (PlatformTunnelStartResult, bool) {
	if strings.TrimSpace(req.ResolutionID) == "" && req.ProviderTransportCompatibility == nil {
		return PlatformTunnelStartResult{}, false
	}

	h.mu.Lock()
	transportProfileStoreEnabled := h.transportProfileStoreEnabled
	descriptor, descriptorErr := h.selectedStartupExecutionPlanDescriptorLocked(req)
	requiredKinds := []TransportProfileKind(nil)
	if descriptor != nil {
		requiredKinds = descriptor.RequiredTransportProfileKinds
		if len(requiredKinds) == 0 {
			requiredKinds = h.requiredTransportProfileKindsForPlanLocked(descriptor.Plan)
		}
	} else if req.ExecutionPlan != nil {
		requiredKinds = h.requiredTransportProfileKindsForPlanLocked(*req.ExecutionPlan)
	}
	h.mu.Unlock()

	if !transportProfileStoreEnabled &&
		req.ProviderTransportCompatibility == nil &&
		req.TransportProfile == nil {
		return PlatformTunnelStartResult{}, false
	}
	if descriptorErr != nil && req.ExecutionPlan == nil {
		return PlatformTunnelStartResult{}, false
	}
	if len(requiredKinds) == 0 && req.TransportProfile == nil {
		return PlatformTunnelStartResult{}, false
	}
	if strings.TrimSpace(req.ResolutionID) == "" {
		return providerTransportStartupFailure(
			req,
			ProviderTransportCompatibilityFailure{
				Status:      ProviderTransportCompatibilityStatusSetupNeeded,
				FailingAxis: ProviderTransportCompatibilityAxisProviderSource,
				ReasonCode:  ProviderTransportCompatibilityReasonProviderSourceRequired,
				Message:     "provider resolution is required for combined provider/transport startup",
			},
		), true
	}
	if req.ExecutionPlan == nil {
		return providerTransportStartupFailure(
			req,
			ProviderTransportCompatibilityFailure{
				Status:      ProviderTransportCompatibilityStatusSetupNeeded,
				FailingAxis: ProviderTransportCompatibilityAxisHostAdapter,
				ReasonCode:  ProviderTransportCompatibilityReasonRuntimePlanRequired,
				Message:     "explicit runtime execution plan is required for combined provider/transport startup",
			},
		), true
	}
	if req.TransportProfile == nil || strings.TrimSpace(req.TransportProfile.ProfileID) == "" {
		return providerTransportStartupFailure(
			req,
			ProviderTransportCompatibilityFailure{
				Status:      ProviderTransportCompatibilityStatusSetupNeeded,
				FailingAxis: ProviderTransportCompatibilityAxisTransportProfile,
				ReasonCode:  ProviderTransportCompatibilityReasonTransportProfileRequired,
				Message:     "explicit VPN transport profile reference is required for combined provider/transport startup",
			},
		), true
	}
	if failure, failed := providerTransportStartupReferenceFailure(req); failed {
		return providerTransportStartupFailure(req, failure), true
	}

	compatReq := ProviderTransportCompatibilityRequest{
		ResolutionID:     req.ResolutionID,
		ExecutionPlan:    cloneRuntimeExecutionPlan(req.ExecutionPlan),
		TransportProfile: cloneTransportProfileReference(req.TransportProfile),
	}
	if ref := req.ProviderTransportCompatibility; ref != nil {
		compatReq.CandidateID = ref.CandidateID
		compatReq.Source = cloneProviderTransportSourceReference(ref.Source)
		compatReq.Artifact = cloneProviderTransportArtifactReference(ref.Artifact)
		if compatReq.ExecutionPlan == nil {
			compatReq.ExecutionPlan = cloneRuntimeExecutionPlan(ref.ExecutionPlan)
		}
		if compatReq.TransportProfile == nil {
			compatReq.TransportProfile = cloneTransportProfileReference(ref.TransportProfile)
		}
	}
	response := h.ProviderTransportCompatibilityCandidates(compatReq)
	if len(response.Candidates) == 0 {
		return providerTransportStartupFailure(
			req,
			ProviderTransportCompatibilityFailure{
				Status:      ProviderTransportCompatibilityStatusUnsupported,
				FailingAxis: ProviderTransportCompatibilityAxisEngineFamily,
				ReasonCode:  ProviderTransportCompatibilityReasonRuntimePlanUnsupported,
				Message:     "no provider/transport compatibility candidate matched the startup request",
			},
		), true
	}
	candidate := response.Candidates[0]
	if !ProviderTransportCompatibilityCandidateStartable(candidate) {
		return providerTransportStartupFailure(req, providerTransportFailureFromCandidate(candidate)), true
	}
	return PlatformTunnelStartResult{}, false
}

func providerTransportStartupReferenceFailure(
	req PlatformTunnelStartRequest,
) (ProviderTransportCompatibilityFailure, bool) {
	ref := req.ProviderTransportCompatibility
	if ref == nil {
		return providerTransportStartupReferenceProviderArtifactFailure(
			"",
			"provider/transport compatibility source and artifact references are required for combined startup",
		), true
	}
	if ref.Source == nil || strings.TrimSpace(ref.Source.ResolutionID) == "" {
		return ProviderTransportCompatibilityFailure{
			CandidateID: strings.TrimSpace(ref.CandidateID),
			Status:      ProviderTransportCompatibilityStatusSetupNeeded,
			FailingAxis: ProviderTransportCompatibilityAxisProviderSource,
			ReasonCode:  ProviderTransportCompatibilityReasonProviderSourceRequired,
			Message:     "provider/transport compatibility source resolution reference is required for combined startup",
		}, true
	}
	if ref.Artifact == nil ||
		strings.TrimSpace(ref.Artifact.ResolutionID) == "" ||
		strings.TrimSpace(string(ref.Artifact.Family)) == "" ||
		len(ref.Artifact.AccessMethods) == 0 {
		return providerTransportStartupReferenceProviderArtifactFailure(
			ref.CandidateID,
			"provider/transport compatibility artifact reference is required for combined startup",
		), true
	}
	return ProviderTransportCompatibilityFailure{}, false
}

func providerTransportStartupReferenceProviderArtifactFailure(
	candidateID string,
	message string,
) ProviderTransportCompatibilityFailure {
	return ProviderTransportCompatibilityFailure{
		CandidateID: strings.TrimSpace(candidateID),
		Status:      ProviderTransportCompatibilityStatusSetupNeeded,
		FailingAxis: ProviderTransportCompatibilityAxisProviderArtifact,
		ReasonCode:  ProviderTransportCompatibilityReasonProviderArtifactMissing,
		Message:     message,
	}
}

func (h *Host) selectedStartupExecutionPlanDescriptorLocked(
	req PlatformTunnelStartRequest,
) (*RuntimeExecutionPlanDescriptor, error) {
	for _, capability := range h.platformTunnels {
		if capability.Mode != req.Mode {
			continue
		}
		descriptor, err := selectPlatformTunnelExecutionPlanDescriptor(capability.ExecutionPlans, req.ExecutionPlan)
		if err != nil {
			return nil, err
		}
		return descriptor, nil
	}
	if req.ExecutionPlan != nil {
		return &RuntimeExecutionPlanDescriptor{Plan: *req.ExecutionPlan}, nil
	}
	return nil, errRuntimeExecutionPlanUnavailable
}

func providerTransportStartupFailure(
	req PlatformTunnelStartRequest,
	failure ProviderTransportCompatibilityFailure,
) PlatformTunnelStartResult {
	stage := PlatformTunnelStartupStageCapabilityCheck
	prerequisite := PlatformTunnelPrerequisiteHostImplementation
	switch failure.FailingAxis {
	case ProviderTransportCompatibilityAxisTransportProfile:
		stage = PlatformTunnelStartupStageProfileValidate
		prerequisite = PlatformTunnelPrerequisiteTransportProfile
	case ProviderTransportCompatibilityAxisProviderSource,
		ProviderTransportCompatibilityAxisProviderArtifact,
		ProviderTransportCompatibilityAxisArtifactAccessMethod:
		stage = PlatformTunnelStartupStageRuntimeAttach
	case ProviderTransportCompatibilityAxisEvidence:
		stage = PlatformTunnelStartupStageDataplaneVerify
		prerequisite = PlatformTunnelPrerequisiteDataplaneEvidence
	}
	return PlatformTunnelStartResult{
		Mode:                           req.Mode,
		ExecutionPlan:                  cloneRuntimeExecutionPlan(req.ExecutionPlan),
		TransportProfile:               cloneTransportProfileReference(req.TransportProfile),
		ProviderTransportCompatibility: cloneProviderTransportCompatibilityFailure(&failure),
		Ready:                          false,
		Stage:                          stage,
		MissingPrerequisite:            prerequisite,
		UnderlayRoutePolicy:            req.UnderlayRoutePolicy,
		Message:                        firstNonEmpty(failure.Message, string(failure.ReasonCode)),
	}
}

func providerTransportFailureCandidate(
	req ProviderTransportCompatibilityRequest,
	source *ProviderTransportSourceReference,
	artifact *ProviderTransportArtifactReference,
	descriptor RuntimeExecutionPlanDescriptor,
	status ProviderTransportCompatibilityStatus,
	axis ProviderTransportCompatibilityFailingAxis,
	reason ProviderTransportCompatibilityReasonCode,
	message string,
) ProviderTransportCompatibilityCandidate {
	candidate := ProviderTransportCompatibilityCandidate{
		Source:        cloneProviderTransportSourceReference(source),
		Artifact:      cloneProviderTransportArtifactReference(artifact),
		ExecutionPlan: cloneRuntimeExecutionPlanDescriptor(descriptor),
		Status:        status,
		FailingAxis:   axis,
		ReasonCode:    reason,
		Message:       strings.TrimSpace(message),
	}
	return providerTransportFinalizeCandidate(req, candidate)
}

func providerTransportSetCandidateFailure(
	req ProviderTransportCompatibilityRequest,
	candidate ProviderTransportCompatibilityCandidate,
	status ProviderTransportCompatibilityStatus,
	axis ProviderTransportCompatibilityFailingAxis,
	reason ProviderTransportCompatibilityReasonCode,
	message string,
) ProviderTransportCompatibilityCandidate {
	candidate.Status = status
	candidate.FailingAxis = axis
	candidate.ReasonCode = reason
	candidate.Message = strings.TrimSpace(message)
	return providerTransportFinalizeCandidate(req, candidate)
}

func providerTransportCandidateForTransportProfileError(
	req ProviderTransportCompatibilityRequest,
	candidate ProviderTransportCompatibilityCandidate,
	err error,
	explicit bool,
) ProviderTransportCompatibilityCandidate {
	status := ProviderTransportCompatibilityStatusSetupNeeded
	reason := ProviderTransportCompatibilityReasonTransportProfileMissing
	if explicit && errors.Is(err, ErrTransportProfileNotFound) {
		status = ProviderTransportCompatibilityStatusStale
		reason = ProviderTransportCompatibilityReasonTransportProfileStale
	}
	switch {
	case errors.Is(err, ErrTransportProfileInvalid):
		reason = ProviderTransportCompatibilityReasonTransportProfileInvalid
	case errors.Is(err, ErrTransportProfileIncompatible):
		status = ProviderTransportCompatibilityStatusUnsupported
		reason = ProviderTransportCompatibilityReasonTransportProfileIncompatibleKind
	case errors.Is(err, ErrTransportProfileStoreUnavailable):
		status = ProviderTransportCompatibilityStatusUnavailable
		reason = ProviderTransportCompatibilityReasonTransportProfileStoreUnavailable
	}
	return providerTransportSetCandidateFailure(
		req,
		candidate,
		status,
		ProviderTransportCompatibilityAxisTransportProfile,
		reason,
		err.Error(),
	)
}

func providerTransportFinalizeCandidate(
	req ProviderTransportCompatibilityRequest,
	candidate ProviderTransportCompatibilityCandidate,
) ProviderTransportCompatibilityCandidate {
	if candidate.ID == "" {
		candidate.ID = providerTransportCompatibilityCandidateID(req, candidate)
	}
	candidate.Startable = ProviderTransportCompatibilityCandidateStartable(candidate)
	return candidate
}

func providerTransportFailureFromCandidate(
	candidate ProviderTransportCompatibilityCandidate,
) ProviderTransportCompatibilityFailure {
	return ProviderTransportCompatibilityFailure{
		CandidateID: candidate.ID,
		Status:      candidate.Status,
		FailingAxis: candidate.FailingAxis,
		ReasonCode:  candidate.ReasonCode,
		Message:     candidate.Message,
	}
}

func providerTransportCompatibilityCandidateID(
	req ProviderTransportCompatibilityRequest,
	candidate ProviderTransportCompatibilityCandidate,
) string {
	if id := strings.TrimSpace(req.CandidateID); id != "" {
		return id
	}
	source := candidate.Source
	if source == nil {
		source = &ProviderTransportSourceReference{}
	}
	artifact := candidate.Artifact
	if artifact == nil {
		artifact = &ProviderTransportArtifactReference{}
	}
	parts := []string{
		firstNonEmpty(source.ProviderID, ""),
		firstNonEmpty(source.ResolutionID, providerTransportCompatibilityResolutionID(req)),
		string(artifact.Family),
		string(candidate.ExecutionPlan.Plan.AccessMethod),
		string(candidate.ExecutionPlan.Plan.CarrierFamily),
		string(candidate.ExecutionPlan.Plan.EngineFamily),
		string(candidate.ExecutionPlan.Plan.HostAdapter),
	}
	if candidate.SelectedTransportProfile != nil {
		parts = append(parts, candidate.SelectedTransportProfile.ProfileID, string(candidate.SelectedTransportProfile.Kind))
	}
	sum := sha256.Sum256([]byte(strings.Join(parts, "|")))
	return "ptc-" + hex.EncodeToString(sum[:8])
}

func providerTransportExecutionPlanDescriptors(
	snapshot Resolution,
	requested *RuntimeExecutionPlan,
) []RuntimeExecutionPlanDescriptor {
	if snapshot.Artifact == nil {
		return nil
	}
	out := make([]RuntimeExecutionPlanDescriptor, 0)
	for _, action := range snapshot.Artifact.Actions {
		if action.ID != ArtifactActionStartOnThisDevice {
			continue
		}
		for _, descriptor := range action.ExecutionPlans {
			if requested != nil && !runtimeExecutionPlanEquals(descriptor.Plan, *requested) {
				continue
			}
			out = append(out, cloneRuntimeExecutionPlanDescriptor(descriptor))
		}
	}
	return out
}

func providerTransportArtifactReferenceFromResolution(
	snapshot Resolution,
) *ProviderTransportArtifactReference {
	ref := &ProviderTransportArtifactReference{
		ProviderID:   snapshot.Provider,
		ResolutionID: snapshot.ID,
	}
	if snapshot.Artifact != nil {
		ref.Family = snapshot.Artifact.Family
		ref.AccessMethods = append([]RuntimeAccessMethod(nil), snapshot.Artifact.AccessMethods...)
	}
	if snapshot.Export.ExpiresAt != nil {
		expiresAt := snapshot.Export.ExpiresAt.UTC()
		ref.ExpiresAt = &expiresAt
	}
	return ref
}

func providerTransportArtifactSupportsAccessMethod(
	artifact *ProviderTransportArtifactReference,
	method RuntimeAccessMethod,
) bool {
	if strings.TrimSpace(string(method)) == "" {
		return false
	}
	if artifact == nil || len(artifact.AccessMethods) == 0 {
		return false
	}
	for _, candidate := range artifact.AccessMethods {
		if candidate == method {
			return true
		}
	}
	return false
}

func providerTransportRemoteVPSArtifactFailure(
	snapshot Resolution,
	now time.Time,
) *ProviderTransportCompatibilityFailure {
	remote := snapshot.RemoteVPS
	if remote == nil && snapshot.Artifact != nil {
		remote = snapshot.Artifact.Summary.RemoteVPS
	}
	if remote == nil {
		return nil
	}
	if remote.ExpiresAt != nil && !remote.ExpiresAt.UTC().After(now) {
		return &ProviderTransportCompatibilityFailure{
			Status:      ProviderTransportCompatibilityStatusStale,
			FailingAxis: ProviderTransportCompatibilityAxisProviderArtifact,
			ReasonCode:  ProviderTransportCompatibilityReasonProviderArtifactStale,
			Message:     "VPS-issued provider artifact is expired or stale",
		}
	}
	status := strings.TrimSpace(remote.ValidationStatus)
	switch status {
	case "", "valid":
	case "missing_evidence":
		return &ProviderTransportCompatibilityFailure{
			Status:      ProviderTransportCompatibilityStatusMissingEvidence,
			FailingAxis: ProviderTransportCompatibilityAxisEvidence,
			ReasonCode:  ProviderTransportCompatibilityReasonEvidenceMissing,
			Message:     "VPS-issued provider artifact has no fresh readiness evidence",
		}
	case "stale":
		return &ProviderTransportCompatibilityFailure{
			Status:      ProviderTransportCompatibilityStatusStale,
			FailingAxis: ProviderTransportCompatibilityAxisProviderArtifact,
			ReasonCode:  ProviderTransportCompatibilityReasonProviderArtifactStale,
			Message:     "VPS-issued provider artifact readiness evidence is stale",
		}
	case "degraded":
		return &ProviderTransportCompatibilityFailure{
			Status:      ProviderTransportCompatibilityStatusDegraded,
			FailingAxis: ProviderTransportCompatibilityAxisEvidence,
			ReasonCode:  ProviderTransportCompatibilityReasonProviderArtifactDegraded,
			Message:     "VPS-issued provider artifact readiness is degraded",
		}
	case "unavailable":
		return &ProviderTransportCompatibilityFailure{
			Status:      ProviderTransportCompatibilityStatusUnavailable,
			FailingAxis: ProviderTransportCompatibilityAxisProviderArtifact,
			ReasonCode:  ProviderTransportCompatibilityReasonProviderArtifactUnavailable,
			Message:     "VPS-issued provider artifact is unavailable",
		}
	default:
		return &ProviderTransportCompatibilityFailure{
			Status:      ProviderTransportCompatibilityStatusUnsupported,
			FailingAxis: ProviderTransportCompatibilityAxisProviderArtifact,
			ReasonCode:  ProviderTransportCompatibilityReasonProviderArtifactUnsupported,
			Message:     fmt.Sprintf("VPS-issued provider artifact validation status %q is not startable", status),
		}
	}

	evidenceStatus := strings.TrimSpace(remote.EvidenceStatus)
	switch evidenceStatus {
	case "", "fresh":
		return nil
	case "missing", "unknown_limit":
		return &ProviderTransportCompatibilityFailure{
			Status:      ProviderTransportCompatibilityStatusMissingEvidence,
			FailingAxis: ProviderTransportCompatibilityAxisEvidence,
			ReasonCode:  ProviderTransportCompatibilityReasonEvidenceMissing,
			Message:     "VPS-issued provider artifact evidence is missing",
		}
	case "stale":
		return &ProviderTransportCompatibilityFailure{
			Status:      ProviderTransportCompatibilityStatusStale,
			FailingAxis: ProviderTransportCompatibilityAxisProviderArtifact,
			ReasonCode:  ProviderTransportCompatibilityReasonProviderArtifactStale,
			Message:     "VPS-issued provider artifact evidence is stale",
		}
	case "degraded":
		return &ProviderTransportCompatibilityFailure{
			Status:      ProviderTransportCompatibilityStatusDegraded,
			FailingAxis: ProviderTransportCompatibilityAxisEvidence,
			ReasonCode:  ProviderTransportCompatibilityReasonProviderArtifactDegraded,
			Message:     "VPS-issued provider artifact evidence is degraded",
		}
	case "unavailable":
		return &ProviderTransportCompatibilityFailure{
			Status:      ProviderTransportCompatibilityStatusUnavailable,
			FailingAxis: ProviderTransportCompatibilityAxisProviderArtifact,
			ReasonCode:  ProviderTransportCompatibilityReasonProviderArtifactUnavailable,
			Message:     "VPS-issued provider artifact evidence is unavailable",
		}
	default:
		return &ProviderTransportCompatibilityFailure{
			Status:      ProviderTransportCompatibilityStatusUnsupported,
			FailingAxis: ProviderTransportCompatibilityAxisProviderArtifact,
			ReasonCode:  ProviderTransportCompatibilityReasonProviderArtifactUnsupported,
			Message:     fmt.Sprintf("VPS-issued provider artifact evidence status %q is not startable", evidenceStatus),
		}
	}
}

func providerTransportSourceMismatch(
	ref *ProviderTransportSourceReference,
	snapshot Resolution,
) string {
	if ref == nil {
		return ""
	}
	if ref.ResolutionID != "" && ref.ResolutionID != snapshot.ID {
		return fmt.Sprintf("provider source references resolution %s but current resolution is %s", ref.ResolutionID, snapshot.ID)
	}
	if ref.ProviderID != "" && ref.ProviderID != snapshot.Provider {
		return fmt.Sprintf("provider source references provider %s but current resolution provider is %s", ref.ProviderID, snapshot.Provider)
	}
	return ""
}

func providerTransportArtifactMismatch(
	ref *ProviderTransportArtifactReference,
	actual *ProviderTransportArtifactReference,
) string {
	if ref == nil || actual == nil {
		return ""
	}
	if ref.ResolutionID != "" && ref.ResolutionID != actual.ResolutionID {
		return fmt.Sprintf("provider artifact references resolution %s but current resolution is %s", ref.ResolutionID, actual.ResolutionID)
	}
	if ref.ProviderID != "" && ref.ProviderID != actual.ProviderID {
		return fmt.Sprintf("provider artifact references provider %s but current resolution provider is %s", ref.ProviderID, actual.ProviderID)
	}
	if ref.Family != "" && ref.Family != actual.Family {
		return fmt.Sprintf("provider artifact family %s no longer matches current family %s", ref.Family, actual.Family)
	}
	if ref.ExpiresAt != nil {
		if actual.ExpiresAt == nil || !ref.ExpiresAt.UTC().Equal(actual.ExpiresAt.UTC()) {
			return "provider artifact expiry no longer matches the current resolution"
		}
	}
	for _, method := range ref.AccessMethods {
		if !providerTransportArtifactSupportsAccessMethod(actual, method) {
			return fmt.Sprintf("provider artifact no longer exposes access method %s", method)
		}
	}
	return ""
}

func normalizeProviderTransportCompatibilityRequest(
	req ProviderTransportCompatibilityRequest,
) ProviderTransportCompatibilityRequest {
	req.ResolutionID = strings.TrimSpace(req.ResolutionID)
	req.CandidateID = strings.TrimSpace(req.CandidateID)
	if req.Source != nil {
		source := *req.Source
		source.ProviderID = strings.TrimSpace(source.ProviderID)
		source.SourceID = strings.TrimSpace(source.SourceID)
		source.ResolutionID = strings.TrimSpace(source.ResolutionID)
		req.Source = &source
	}
	if req.Artifact != nil {
		artifact := *req.Artifact
		artifact.ProviderID = strings.TrimSpace(artifact.ProviderID)
		artifact.ResolutionID = strings.TrimSpace(artifact.ResolutionID)
		artifact.AccessMethods = append([]RuntimeAccessMethod(nil), artifact.AccessMethods...)
		req.Artifact = &artifact
	}
	req.ExecutionPlan = cloneRuntimeExecutionPlan(req.ExecutionPlan)
	req.TransportProfile = cloneTransportProfileReference(req.TransportProfile)
	return req
}

func validateProviderTransportCompatibilityFailure(
	failure ProviderTransportCompatibilityFailure,
) error {
	if !isKnownProviderTransportCompatibilityStatus(failure.Status) {
		return fmt.Errorf("status %q is unknown", failure.Status)
	}
	if strings.TrimSpace(string(failure.FailingAxis)) != "" &&
		!isKnownProviderTransportCompatibilityFailingAxis(failure.FailingAxis) {
		return fmt.Errorf("failing_axis %q is unknown", failure.FailingAxis)
	}
	if failure.Status == ProviderTransportCompatibilityStatusStartable {
		return fmt.Errorf("failure cannot report startable status")
	}
	if strings.TrimSpace(string(failure.ReasonCode)) == "" {
		return fmt.Errorf("reason_code is required")
	}
	return nil
}

func providerTransportCompatibilityResolutionID(req ProviderTransportCompatibilityRequest) string {
	if strings.TrimSpace(req.ResolutionID) != "" {
		return strings.TrimSpace(req.ResolutionID)
	}
	if req.Source != nil && strings.TrimSpace(req.Source.ResolutionID) != "" {
		return strings.TrimSpace(req.Source.ResolutionID)
	}
	if req.Artifact != nil && strings.TrimSpace(req.Artifact.ResolutionID) != "" {
		return strings.TrimSpace(req.Artifact.ResolutionID)
	}
	return ""
}

func cloneRuntimeExecutionPlanDescriptor(
	descriptor RuntimeExecutionPlanDescriptor,
) RuntimeExecutionPlanDescriptor {
	clone := descriptor
	clone.RequiredTransportProfileKinds = append([]TransportProfileKind(nil), descriptor.RequiredTransportProfileKinds...)
	clone.TransportProfile = cloneTransportProfilePrerequisiteStatus(descriptor.TransportProfile)
	return clone
}

func isKnownProviderTransportCompatibilityStatus(
	status ProviderTransportCompatibilityStatus,
) bool {
	switch status {
	case ProviderTransportCompatibilityStatusStartable,
		ProviderTransportCompatibilityStatusSetupNeeded,
		ProviderTransportCompatibilityStatusUnsupported,
		ProviderTransportCompatibilityStatusStale,
		ProviderTransportCompatibilityStatusDegraded,
		ProviderTransportCompatibilityStatusMissingEvidence,
		ProviderTransportCompatibilityStatusUnavailable:
		return true
	default:
		return false
	}
}

func isKnownProviderTransportCompatibilityFailingAxis(
	axis ProviderTransportCompatibilityFailingAxis,
) bool {
	switch axis {
	case ProviderTransportCompatibilityAxisProviderSource,
		ProviderTransportCompatibilityAxisProviderArtifact,
		ProviderTransportCompatibilityAxisArtifactAccessMethod,
		ProviderTransportCompatibilityAxisCarrierFamily,
		ProviderTransportCompatibilityAxisEngineFamily,
		ProviderTransportCompatibilityAxisHostAdapter,
		ProviderTransportCompatibilityAxisTransportProfile,
		ProviderTransportCompatibilityAxisDegradedPolicy,
		ProviderTransportCompatibilityAxisEvidence,
		ProviderTransportCompatibilityAxisHostCapability:
		return true
	default:
		return false
	}
}
