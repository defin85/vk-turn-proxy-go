package clientcontrol

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/wireguardprofile"
)

var (
	ErrTransportProfileStoreUnavailable = errors.New("transport profile store is unavailable")
	ErrTransportProfileNotFound         = errors.New("transport profile was not found")
	ErrTransportProfileInvalid          = errors.New("transport profile is invalid")
	ErrTransportProfileIncompatible     = errors.New("transport profile is incompatible with the selected execution plan")
)

type managedTransportProfile struct {
	status    TransportProfileStatus
	wireguard *wireguardprofile.Profile
}

type transportProfileStoreDisk struct {
	Version  int                          `json:"version"`
	Profiles []transportProfileDiskRecord `json:"profiles,omitempty"`
	Defaults map[string]string            `json:"defaults,omitempty"`
}

type transportProfileDiskRecord struct {
	Status    TransportProfileStatus         `json:"status"`
	WireGuard *transportProfileDiskWireGuard `json:"wireguard_native_v1,omitempty"`
}

type transportProfileDiskWireGuard struct {
	PrivateKey                 string   `json:"private_key"`
	Addresses                  []string `json:"addresses,omitempty"`
	DNSServers                 []string `json:"dns_servers,omitempty"`
	MTU                        int      `json:"mtu,omitempty"`
	PeerPublicKey              string   `json:"peer_public_key"`
	PresharedKey               string   `json:"preshared_key,omitempty"`
	AllowedIPs                 []string `json:"allowed_ips,omitempty"`
	Endpoint                   string   `json:"endpoint,omitempty"`
	PersistentKeepaliveSeconds int      `json:"persistent_keepalive_seconds,omitempty"`
}

func WithVPNTransportProfileStore() Option {
	return func(cfg *hostConfig) {
		cfg.transportProfileStoreEnabled = true
	}
}

func WithVPNTransportProfileStorePath(path string) Option {
	return func(cfg *hostConfig) {
		cfg.transportProfileStoreEnabled = true
		cfg.transportProfileStorePath = strings.TrimSpace(path)
	}
}

func defaultTransportProfileStoreCapability() TransportProfileStoreCapability {
	return TransportProfileStoreCapability{
		SupportedKinds: []TransportProfileKind{
			TransportProfileKindWireGuardNativeV1,
		},
		ImportAdapters: []TransportProfileImportAdapterDescriptor{{
			ID:                        TransportProfileImportAdapterWireGuardConf,
			ProfileKind:               TransportProfileKindWireGuardNativeV1,
			DisplayName:               "WireGuard .conf",
			Extensions:                []string{"conf"},
			MaterialAcquisitionMethod: TransportProfileMaterialAcquisitionMethodPlainText,
		}},
		LifecycleActions: []TransportProfileLifecycleAction{
			TransportProfileLifecycleActionList,
			TransportProfileLifecycleActionImport,
			TransportProfileLifecycleActionReplace,
			TransportProfileLifecycleActionForget,
			TransportProfileLifecycleActionValidate,
			TransportProfileLifecycleActionSelectForStartup,
			TransportProfileLifecycleActionCreateStructured,
			TransportProfileLifecycleActionUpdateStructured,
			TransportProfileLifecycleActionValidateDraft,
			TransportProfileLifecycleActionGenerateKey,
		},
		RedactionGuarantees: []string{
			"ordinary_reads_exclude_raw_material",
			"ordinary_reads_exclude_private_keys",
			"ordinary_reads_exclude_host_private_paths",
		},
		EditableKinds: defaultTransportProfileEditableKindSchemas(),
		PortableTransfer: &TransportProfilePortableTransferCapability{
			EnvelopeType:    portableTransportProfileEnvelopeType,
			EnvelopeVersion: portableTransportProfileEnvelopeVersion,
			SupportedKinds: []TransportProfileKind{
				TransportProfileKindWireGuardNativeV1,
			},
			ExportPaths: []TransportProfilePortableTransferPath{
				TransportProfilePortableTransferPathTextPayload,
				TransportProfilePortableTransferPathFilePayload,
				TransportProfilePortableTransferPathQRPayload,
			},
			ImportPaths: []TransportProfilePortableTransferPath{
				TransportProfilePortableTransferPathTextPayload,
				TransportProfilePortableTransferPathFilePayload,
				TransportProfilePortableTransferPathQRPayload,
			},
			QRMaxPayloadBytes: portableTransportProfileQRMaxPayloadBytes,
			QRMode:            TransportProfilePortableTransferQRModeSinglePayload,
		},
	}
}

func cloneTransportProfileStoreCapability(capability *TransportProfileStoreCapability) *TransportProfileStoreCapability {
	if capability == nil {
		return nil
	}
	clone := *capability
	clone.SupportedKinds = append([]TransportProfileKind(nil), capability.SupportedKinds...)
	clone.ImportAdapters = append([]TransportProfileImportAdapterDescriptor(nil), capability.ImportAdapters...)
	for index := range clone.ImportAdapters {
		clone.ImportAdapters[index].Extensions = append([]string(nil), capability.ImportAdapters[index].Extensions...)
	}
	clone.LifecycleActions = append([]TransportProfileLifecycleAction(nil), capability.LifecycleActions...)
	clone.RedactionGuarantees = append([]string(nil), capability.RedactionGuarantees...)
	clone.EditableKinds = cloneTransportProfileEditableKindSchemas(capability.EditableKinds)
	clone.PortableTransfer = cloneTransportProfilePortableTransferCapability(capability.PortableTransfer)
	return &clone
}

func cloneTransportProfilePortableTransferCapability(
	capability *TransportProfilePortableTransferCapability,
) *TransportProfilePortableTransferCapability {
	if capability == nil {
		return nil
	}
	clone := *capability
	clone.SupportedKinds = append([]TransportProfileKind(nil), capability.SupportedKinds...)
	clone.ExportPaths = append([]TransportProfilePortableTransferPath(nil), capability.ExportPaths...)
	clone.ImportPaths = append([]TransportProfilePortableTransferPath(nil), capability.ImportPaths...)
	return &clone
}

func cloneTransportProfileStatus(status TransportProfileStatus) TransportProfileStatus {
	clone := status
	clone.Actions = append([]TransportProfileLifecycleAction(nil), status.Actions...)
	clone.DefaultFor = cloneTransportProfileDefaultBindings(status.DefaultFor)
	clone.Compatibility.CompatibleExecutionPlans = append([]RuntimeExecutionPlan(nil), status.Compatibility.CompatibleExecutionPlans...)
	clone.StructuredDraft = cloneTransportProfileStructuredDraft(status.StructuredDraft)
	return clone
}

func cloneTransportProfileStatuses(statuses []TransportProfileStatus) []TransportProfileStatus {
	if len(statuses) == 0 {
		return nil
	}
	out := make([]TransportProfileStatus, 0, len(statuses))
	for _, status := range statuses {
		out = append(out, cloneTransportProfileStatus(status))
	}
	return out
}

func cloneTransportProfileDefaultBindings(bindings []TransportProfileDefaultBinding) []TransportProfileDefaultBinding {
	if len(bindings) == 0 {
		return nil
	}
	out := make([]TransportProfileDefaultBinding, 0, len(bindings))
	for _, binding := range bindings {
		copyBinding := binding
		out = append(out, copyBinding)
	}
	return out
}

func cloneTransportProfileStructuredDraft(draft *TransportProfileStructuredDraft) *TransportProfileStructuredDraft {
	if draft == nil {
		return nil
	}
	clone := *draft
	if draft.Fields != nil {
		clone.Fields = make(map[TransportProfileStructuredFieldID]any, len(draft.Fields))
		for field, value := range draft.Fields {
			clone.Fields[field] = cloneStructuredDraftFieldValue(value)
		}
	}
	if draft.SecretActions != nil {
		clone.SecretActions = make(map[TransportProfileStructuredFieldID]TransportProfileSecretUpdateAction, len(draft.SecretActions))
		for field, action := range draft.SecretActions {
			clone.SecretActions[field] = action
		}
	}
	clone.InterfaceAddresses = append([]string(nil), draft.InterfaceAddresses...)
	clone.DNSServers = append([]string(nil), draft.DNSServers...)
	clone.AllowedIPs = append([]string(nil), draft.AllowedIPs...)
	clone.DefaultFor = cloneRuntimeExecutionPlan(draft.DefaultFor)
	return &clone
}

func cloneStructuredDraftFieldValue(value any) any {
	switch typed := value.(type) {
	case []string:
		return append([]string(nil), typed...)
	case []any:
		return append([]any(nil), typed...)
	default:
		return typed
	}
}

func cloneTransportProfileReference(ref *TransportProfileReference) *TransportProfileReference {
	if ref == nil {
		return nil
	}
	clone := *ref
	return &clone
}

func cloneTransportProfilePrerequisiteStatus(status *TransportProfilePrerequisiteStatus) *TransportProfilePrerequisiteStatus {
	if status == nil {
		return nil
	}
	clone := *status
	clone.RequiredKinds = append([]TransportProfileKind(nil), status.RequiredKinds...)
	clone.SelectedProfile = cloneTransportProfileReference(status.SelectedProfile)
	clone.DefaultProfile = cloneTransportProfileReference(status.DefaultProfile)
	clone.ImportAdapters = append([]TransportProfileImportAdapter(nil), status.ImportAdapters...)
	return &clone
}

func (h *Host) transportProfileStoreCapabilityLocked() *TransportProfileStoreCapability {
	if !h.transportProfileStoreEnabled {
		return nil
	}
	capability := defaultTransportProfileStoreCapability()
	return &capability
}

func (h *Host) platformTunnelCapabilitiesWithTransportProfileStateLocked() []PlatformTunnelCapability {
	snapshot := clonePlatformTunnelCapabilities(h.platformTunnels)
	if !h.transportProfileStoreEnabled {
		return snapshot
	}
	for capabilityIndex := range snapshot {
		capability := &snapshot[capabilityIndex]
		for planIndex := range capability.ExecutionPlans {
			descriptor := &capability.ExecutionPlans[planIndex]
			required := descriptor.RequiredTransportProfileKinds
			if len(required) == 0 {
				required = requiredTransportProfileKindsForPlan(descriptor.Plan)
				descriptor.RequiredTransportProfileKinds = append([]TransportProfileKind(nil), required...)
			}
			if len(required) == 0 {
				continue
			}
			status := h.transportProfilePrerequisiteStatusLocked(descriptor.Plan, required)
			descriptor.TransportProfile = status
			if status.State != TransportProfileCompatibilityStateCompatible ||
				firstTransportProfileReference(status.SelectedProfile, status.DefaultProfile) == nil {
				descriptor.SupportState = RuntimeExecutionPlanSupportStateUnavailable
				descriptor.Message = firstNonEmpty(
					status.Message,
					descriptor.Message,
					fmt.Sprintf("VPN transport profile %s is required before startup.", required[0]),
				)
			}
		}
	}
	return snapshot
}

func (h *Host) transportProfilePrerequisiteStatusLocked(
	plan RuntimeExecutionPlan,
	required []TransportProfileKind,
) *TransportProfilePrerequisiteStatus {
	status := &TransportProfilePrerequisiteStatus{
		RequiredKinds:  append([]TransportProfileKind(nil), required...),
		State:          TransportProfileCompatibilityStateIncompatible,
		MissingKind:    required[0],
		ImportAdapters: h.importAdaptersForTransportProfileKindsLocked(required),
		Message:        fmt.Sprintf("VPN transport profile %s is not configured.", required[0]),
	}
	scopeID := transportProfileDefaultScopeID(plan)
	if profileID := h.transportProfileDefaults[scopeID]; strings.TrimSpace(profileID) != "" {
		if ref, err := h.validateTransportProfileRefLocked(TransportProfileReference{
			ProfileID:      profileID,
			UseDefault:     true,
			DefaultScopeID: scopeID,
		}, plan, required); err == nil {
			status.State = TransportProfileCompatibilityStateCompatible
			status.DefaultProfile = ref
			status.SelectedProfile = ref
			status.MissingKind = ""
			status.Message = ""
			return status
		} else {
			status.MissingKind = ""
			status.Message = err.Error()
			return status
		}
	}
	for _, managed := range h.transportProfiles {
		if !transportProfileKindAllowed(managed.status.Kind, required) {
			continue
		}
		if transportProfileCompatibleWithPlan(managed.status.Kind, plan) &&
			managed.status.Validation.State == TransportProfileValidationStateValid {
			status.State = TransportProfileCompatibilityStateCompatible
			status.MissingKind = ""
			status.Message = "Select a VPN transport profile for this execution plan before startup."
			return status
		}
		status.State = TransportProfileCompatibilityStateIncompatible
		status.MissingKind = ""
		status.Message = fmt.Sprintf("Configured VPN transport profile %s is incompatible with this execution plan.", managed.status.ID)
	}
	return status
}

func (h *Host) TransportProfileStoreCapability() (*TransportProfileStoreCapability, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	capability := h.transportProfileStoreCapabilityLocked()
	if capability == nil {
		return nil, ErrTransportProfileStoreUnavailable
	}
	return cloneTransportProfileStoreCapability(capability), nil
}

func (h *Host) TransportProfiles() ([]TransportProfileStatus, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return nil, ErrTransportProfileStoreUnavailable
	}
	out := make([]TransportProfileStatus, 0, len(h.transportProfiles))
	for _, managed := range h.transportProfiles {
		out = append(out, cloneTransportProfileStatus(managed.status))
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

func (h *Host) ImportTransportProfile(req TransportProfileImportRequest) (TransportProfileStatus, error) {
	normalized, parsed, err := normalizeTransportProfileImportRequest(req)
	if err != nil {
		return TransportProfileStatus{}, err
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return TransportProfileStatus{}, ErrTransportProfileStoreUnavailable
	}

	status, err := h.storeParsedTransportProfileLocked(
		normalized,
		parsed,
		TransportProfileMaterialSourceImportAdapter,
		true,
	)
	if err != nil {
		return TransportProfileStatus{}, err
	}
	return cloneTransportProfileStatus(status), nil
}

func (h *Host) ValidateTransportProfile(profileID string) (TransportProfileStatus, error) {
	profileID = strings.TrimSpace(profileID)
	if profileID == "" {
		return TransportProfileStatus{}, ErrTransportProfileNotFound
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return TransportProfileStatus{}, ErrTransportProfileStoreUnavailable
	}
	if _, ok := h.transportProfiles[profileID]; !ok {
		return TransportProfileStatus{}, ErrTransportProfileNotFound
	}
	h.refreshTransportProfileStatusLocked(profileID)
	return cloneTransportProfileStatus(h.transportProfiles[profileID].status), nil
}

func (h *Host) SelectTransportProfileForStartup(
	profileID string,
	req TransportProfileSelectForStartupRequest,
) (TransportProfileStatus, error) {
	profileID = strings.TrimSpace(profileID)
	if profileID == "" {
		return TransportProfileStatus{}, ErrTransportProfileNotFound
	}
	if err := validateRuntimeExecutionPlan(req.Plan); err != nil {
		return TransportProfileStatus{}, fmt.Errorf("%w: %v", ErrTransportProfileInvalid, err)
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return TransportProfileStatus{}, ErrTransportProfileStoreUnavailable
	}
	managed, ok := h.transportProfiles[profileID]
	if !ok {
		return TransportProfileStatus{}, ErrTransportProfileNotFound
	}
	requiredKinds := h.requiredTransportProfileKindsForPlanLocked(req.Plan)
	if len(requiredKinds) == 0 {
		return TransportProfileStatus{}, fmt.Errorf("%w: selected execution plan does not require a VPN transport profile", ErrTransportProfileIncompatible)
	}
	if _, err := h.validateTransportProfileRefLocked(TransportProfileReference{
		ProfileID: profileID,
		Kind:      managed.status.Kind,
	}, req.Plan, requiredKinds); err != nil {
		return TransportProfileStatus{}, err
	}
	if !h.transportProfilePlanAdvertisedLocked(managed.status.Kind, req.Plan) {
		return TransportProfileStatus{}, fmt.Errorf("%w: selected execution plan is not advertised by this host", ErrTransportProfileIncompatible)
	}

	scopeID := transportProfileDefaultScopeID(req.Plan)
	previousDefaults := cloneTransportProfileDefaults(h.transportProfileDefaults)
	h.transportProfileDefaults[scopeID] = profileID
	h.refreshTransportProfileStatusesLocked()
	if err := h.persistTransportProfileStoreLocked(); err != nil {
		h.transportProfileDefaults = previousDefaults
		h.refreshTransportProfileStatusesLocked()
		return TransportProfileStatus{}, err
	}
	return cloneTransportProfileStatus(h.transportProfiles[profileID].status), nil
}

func (h *Host) MigrateWireGuardTransportProfileFromPath(path string) (TransportProfileStatus, bool, error) {
	path = strings.TrimSpace(path)
	if path == "" {
		return TransportProfileStatus{}, false, ErrTransportProfileNotFound
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return TransportProfileStatus{}, false, err
	}

	h.mu.Lock()
	if !h.transportProfileStoreEnabled {
		h.mu.Unlock()
		return TransportProfileStatus{}, false, ErrTransportProfileStoreUnavailable
	}
	for _, managed := range h.transportProfiles {
		if managed.status.Kind == TransportProfileKindWireGuardNativeV1 {
			status := cloneTransportProfileStatus(managed.status)
			h.mu.Unlock()
			return status, false, nil
		}
	}
	h.mu.Unlock()

	parsed, err := wireguardprofile.Parse(data, "legacy Android WireGuard profile")
	if err != nil {
		h.mu.Lock()
		defer h.mu.Unlock()
		if !h.transportProfileStoreEnabled {
			return TransportProfileStatus{}, false, ErrTransportProfileStoreUnavailable
		}
		for _, managed := range h.transportProfiles {
			if managed.status.Kind == TransportProfileKindWireGuardNativeV1 {
				return cloneTransportProfileStatus(managed.status), false, nil
			}
		}
		status, storeErr := h.storeInvalidLegacyWireGuardTransportProfileLocked(err)
		if storeErr != nil {
			return TransportProfileStatus{}, false, storeErr
		}
		return cloneTransportProfileStatus(status), false, nil
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return TransportProfileStatus{}, false, ErrTransportProfileStoreUnavailable
	}
	for _, managed := range h.transportProfiles {
		if managed.status.Kind == TransportProfileKindWireGuardNativeV1 {
			return cloneTransportProfileStatus(managed.status), false, nil
		}
	}
	req := TransportProfileImportRequest{
		Kind:        TransportProfileKindWireGuardNativeV1,
		DisplayName: "Migrated WireGuard VPN transport profile",
	}
	status, err := h.storeParsedTransportProfileLocked(
		req,
		parsed,
		TransportProfileMaterialSourceLegacyPath,
		true,
	)
	if err != nil {
		return TransportProfileStatus{}, false, err
	}
	return cloneTransportProfileStatus(status), true, nil
}

func (h *Host) storeInvalidLegacyWireGuardTransportProfileLocked(
	parseErr error,
) (TransportProfileStatus, error) {
	profileID := h.newID()
	now := h.now().UTC()
	status := TransportProfileStatus{
		ID:          profileID,
		Kind:        TransportProfileKindWireGuardNativeV1,
		Version:     "1",
		DisplayName: "Invalid migrated WireGuard VPN transport profile",
		Validation: TransportProfileValidationStatus{
			State:   TransportProfileValidationStateInvalid,
			Message: "legacy Android WireGuard profile is invalid",
		},
		Compatibility: TransportProfileCompatibilityStatus{
			State:   TransportProfileCompatibilityStateIncompatible,
			Message: "transport profile material is invalid",
		},
		SecretMaterialRef: TransportProfileSecretMaterialRef{
			Kind: TransportProfileMaterialSourceLegacyPath,
			Ref:  "host-owned:" + profileID,
		},
		Actions: transportProfileStatusActionsForProfile(
			TransportProfileKindWireGuardNativeV1,
			TransportProfileValidationStatus{State: TransportProfileValidationStateInvalid},
			nil,
		),
		ImportedAt: now,
		UpdatedAt:  now,
	}
	if parseErr != nil {
		status.Validation.Message = fmt.Sprintf("legacy Android WireGuard profile is invalid: %v", parseErr)
	}
	h.transportProfiles[profileID] = managedTransportProfile{status: status}
	h.refreshTransportProfileStatusLocked(profileID)
	status = h.transportProfiles[profileID].status
	if err := h.persistTransportProfileStoreLocked(); err != nil {
		delete(h.transportProfiles, profileID)
		return TransportProfileStatus{}, err
	}
	return cloneTransportProfileStatus(status), nil
}

func (h *Host) storeParsedTransportProfileLocked(
	normalized TransportProfileImportRequest,
	parsed *wireguardprofile.Profile,
	materialSource TransportProfileMaterialSource,
	assignDefaults bool,
) (TransportProfileStatus, error) {
	profileID := strings.TrimSpace(normalized.ReplaceProfileID)
	if profileID == "" {
		profileID = h.newID()
	}
	previousProfile, hadPreviousProfile := h.transportProfiles[profileID]
	importedAt := h.now().UTC()
	if existing, ok := h.transportProfiles[profileID]; ok && !existing.status.ImportedAt.IsZero() {
		importedAt = existing.status.ImportedAt.UTC()
	}

	validation := transportProfileValidationStatus(normalized.Kind, parsed)
	compatibilityState := TransportProfileCompatibilityStateCompatible
	compatibilityMessage := ""
	if validation.State != TransportProfileValidationStateValid {
		compatibilityState = TransportProfileCompatibilityStateIncompatible
		compatibilityMessage = "transport profile material is invalid"
	}

	status := TransportProfileStatus{
		ID:          profileID,
		Kind:        normalized.Kind,
		Version:     "1",
		DisplayName: firstNonEmpty(normalized.DisplayName, defaultTransportProfileDisplayName(normalized.Kind)),
		Validation:  validation,
		Compatibility: TransportProfileCompatibilityStatus{
			State:   compatibilityState,
			Message: compatibilityMessage,
			CompatibleExecutionPlans: compatiblePlansForTransportProfileKind(
				normalized.Kind,
				h.platformTunnels,
			),
		},
		SecretMaterialRef: TransportProfileSecretMaterialRef{
			Kind: materialSource,
			Ref:  "host-owned:" + profileID,
		},
		Actions:    transportProfileStatusActionsForProfile(normalized.Kind, validation, parsed),
		ImportedAt: importedAt,
		UpdatedAt:  h.now().UTC(),
	}
	if status.Validation.State == TransportProfileValidationStateValid && assignDefaults && (normalized.DefaultFor != nil || !hadPreviousProfile) {
		status.DefaultFor = h.defaultBindingsForImportedTransportProfileLocked(status, normalized.DefaultFor)
	} else {
		status.DefaultFor = h.defaultBindingsForTransportProfileLocked(status)
	}

	previousDefaults := cloneTransportProfileDefaults(h.transportProfileDefaults)
	h.transportProfiles[profileID] = managedTransportProfile{
		status:    cloneTransportProfileStatus(status),
		wireguard: cloneWireGuardProfile(parsed),
	}
	if status.Validation.State == TransportProfileValidationStateValid && assignDefaults && (normalized.DefaultFor != nil || !hadPreviousProfile) {
		for _, binding := range status.DefaultFor {
			h.transportProfileDefaults[binding.ScopeID] = profileID
		}
	}
	h.refreshTransportProfileStatusesLocked()
	status = h.transportProfiles[profileID].status
	if err := h.persistTransportProfileStoreLocked(); err != nil {
		if hadPreviousProfile {
			h.transportProfiles[profileID] = previousProfile
		} else {
			delete(h.transportProfiles, profileID)
		}
		h.transportProfileDefaults = previousDefaults
		h.refreshTransportProfileStatusesLocked()
		return TransportProfileStatus{}, err
	}
	return cloneTransportProfileStatus(status), nil
}

func (h *Host) ForgetTransportProfile(profileID string) error {
	profileID = strings.TrimSpace(profileID)
	if profileID == "" {
		return ErrTransportProfileNotFound
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return ErrTransportProfileStoreUnavailable
	}
	previousProfile, ok := h.transportProfiles[profileID]
	if !ok {
		return ErrTransportProfileNotFound
	}
	previousDefaults := cloneTransportProfileDefaults(h.transportProfileDefaults)
	delete(h.transportProfiles, profileID)
	for scopeID, defaultProfileID := range h.transportProfileDefaults {
		if defaultProfileID == profileID {
			delete(h.transportProfileDefaults, scopeID)
		}
	}
	h.refreshTransportProfileStatusesLocked()
	if err := h.persistTransportProfileStoreLocked(); err != nil {
		h.transportProfiles[profileID] = previousProfile
		h.transportProfileDefaults = previousDefaults
		h.refreshTransportProfileStatusesLocked()
		return err
	}
	return nil
}

func (h *Host) loadTransportProfileStore() error {
	if !h.transportProfileStoreEnabled || strings.TrimSpace(h.transportProfileStorePath) == "" {
		return nil
	}
	data, err := os.ReadFile(h.transportProfileStorePath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		return err
	}
	var disk transportProfileStoreDisk
	if err := json.Unmarshal(data, &disk); err != nil {
		return err
	}
	if disk.Version != 1 {
		return fmt.Errorf("%w: unsupported transport profile store version %d", ErrTransportProfileInvalid, disk.Version)
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	h.transportProfiles = make(map[string]managedTransportProfile)
	h.transportProfileDefaults = cloneTransportProfileDefaults(disk.Defaults)
	for _, record := range disk.Profiles {
		status := cloneTransportProfileStatus(record.Status)
		status.ID = strings.TrimSpace(status.ID)
		if status.ID == "" || !isKnownTransportProfileKind(status.Kind) {
			continue
		}
		var profile *wireguardprofile.Profile
		if status.Kind == TransportProfileKindWireGuardNativeV1 && record.WireGuard != nil {
			profile = wireGuardProfileFromDisk(record.WireGuard)
		}
		status.Validation = transportProfileValidationStatus(status.Kind, profile)
		status.SecretMaterialRef.Ref = "host-owned:" + status.ID
		if status.SecretMaterialRef.Kind == "" {
			status.SecretMaterialRef.Kind = TransportProfileMaterialSourceImportAdapter
		}
		status.Actions = transportProfileStatusActionsForProfile(status.Kind, status.Validation, profile)
		h.transportProfiles[status.ID] = managedTransportProfile{
			status:    status,
			wireguard: profile,
		}
	}
	for scopeID, profileID := range h.transportProfileDefaults {
		if _, ok := h.transportProfiles[profileID]; !ok {
			delete(h.transportProfileDefaults, scopeID)
		}
	}
	for profileID := range h.transportProfiles {
		h.refreshTransportProfileStatusLocked(profileID)
	}
	return nil
}

func (h *Host) persistTransportProfileStoreLocked() error {
	if strings.TrimSpace(h.transportProfileStorePath) == "" {
		return nil
	}
	records := make([]transportProfileDiskRecord, 0, len(h.transportProfiles))
	profileIDs := make([]string, 0, len(h.transportProfiles))
	for profileID := range h.transportProfiles {
		profileIDs = append(profileIDs, profileID)
	}
	sort.Strings(profileIDs)
	for _, profileID := range profileIDs {
		managed := h.transportProfiles[profileID]
		record := transportProfileDiskRecord{Status: cloneTransportProfileStatus(managed.status)}
		if managed.status.Kind == TransportProfileKindWireGuardNativeV1 {
			record.WireGuard = wireGuardProfileToDisk(managed.wireguard)
		}
		records = append(records, record)
	}
	disk := transportProfileStoreDisk{
		Version:  1,
		Profiles: records,
		Defaults: cloneTransportProfileDefaults(h.transportProfileDefaults),
	}
	data, err := json.MarshalIndent(disk, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')

	path := strings.TrimSpace(h.transportProfileStorePath)
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, ".transport-profiles-*.tmp")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	closed := false
	defer func() {
		if !closed {
			_ = tmp.Close()
		}
		_ = os.Remove(tmpPath)
	}()
	if err := tmp.Chmod(0o600); err != nil {
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		return err
	}
	if err := tmp.Sync(); err != nil {
		return err
	}
	if err := tmp.Close(); err != nil {
		closed = true
		return err
	}
	closed = true
	if err := os.Rename(tmpPath, path); err != nil {
		return err
	}
	return os.Chmod(path, 0o600)
}

func cloneTransportProfileDefaults(defaults map[string]string) map[string]string {
	if len(defaults) == 0 {
		return make(map[string]string)
	}
	out := make(map[string]string, len(defaults))
	for scopeID, profileID := range defaults {
		out[scopeID] = profileID
	}
	return out
}

func (h *Host) refreshTransportProfileStatusLocked(profileID string) {
	managed, ok := h.transportProfiles[profileID]
	if !ok {
		return
	}
	status := cloneTransportProfileStatus(managed.status)
	status.SecretMaterialRef.Ref = "host-owned:" + status.ID
	if status.SecretMaterialRef.Kind == "" {
		status.SecretMaterialRef.Kind = TransportProfileMaterialSourceImportAdapter
	}
	status.Validation = transportProfileValidationStatus(status.Kind, managed.wireguard)
	status.StructuredDraft = redactedStructuredDraftForTransportProfile(status, managed.wireguard)
	status.Actions = transportProfileStatusActionsForProfile(status.Kind, status.Validation, managed.wireguard)
	status.Compatibility.CompatibleExecutionPlans = compatiblePlansForTransportProfileKind(
		status.Kind,
		h.platformTunnels,
	)
	if status.Validation.State == TransportProfileValidationStateValid &&
		len(status.Compatibility.CompatibleExecutionPlans) > 0 {
		status.Compatibility.State = TransportProfileCompatibilityStateCompatible
		status.Compatibility.Message = ""
	} else if status.Validation.State != TransportProfileValidationStateValid {
		status.Compatibility.State = TransportProfileCompatibilityStateIncompatible
		status.Compatibility.Message = "transport profile material is invalid"
	} else {
		status.Compatibility.State = TransportProfileCompatibilityStateIncompatible
		status.Compatibility.Message = "transport profile is not compatible with any advertised execution plan"
	}
	status.DefaultFor = h.defaultBindingsForTransportProfileLocked(status)
	managed.status = status
	h.transportProfiles[profileID] = managed
}

func (h *Host) refreshTransportProfileStatusesLocked() {
	for profileID := range h.transportProfiles {
		h.refreshTransportProfileStatusLocked(profileID)
	}
}

func transportProfileBaseStatusActions() []TransportProfileLifecycleAction {
	return []TransportProfileLifecycleAction{
		TransportProfileLifecycleActionValidate,
		TransportProfileLifecycleActionReplace,
		TransportProfileLifecycleActionForget,
		TransportProfileLifecycleActionSelectForStartup,
		TransportProfileLifecycleActionUpdateStructured,
		TransportProfileLifecycleActionValidateDraft,
		TransportProfileLifecycleActionGenerateKey,
	}
}

func transportProfileStatusActionsForProfile(
	kind TransportProfileKind,
	validation TransportProfileValidationStatus,
	wireguard *wireguardprofile.Profile,
) []TransportProfileLifecycleAction {
	actions := transportProfileBaseStatusActions()
	if validation.State != TransportProfileValidationStateValid {
		actions = removeTransportProfileLifecycleAction(actions, TransportProfileLifecycleActionSelectForStartup)
	}
	if transportProfilePortableExportAvailable(kind, validation, wireguard) {
		actions = append(actions, TransportProfileLifecycleActionExportPortable)
	}
	return actions
}

func removeTransportProfileLifecycleAction(
	actions []TransportProfileLifecycleAction,
	action TransportProfileLifecycleAction,
) []TransportProfileLifecycleAction {
	out := actions[:0]
	for _, candidate := range actions {
		if candidate == action {
			continue
		}
		out = append(out, candidate)
	}
	return out
}

func (h *Host) resolveTransportProfileForStartupLocked(
	req PlatformTunnelStartRequest,
	plan RuntimeExecutionPlan,
	requiredKinds []TransportProfileKind,
) (*TransportProfileReference, error) {
	if len(requiredKinds) == 0 {
		requiredKinds = requiredTransportProfileKindsForPlan(plan)
		if len(requiredKinds) == 0 {
			return nil, nil
		}
	}
	if !h.transportProfileStoreEnabled {
		return nil, fmt.Errorf("%w: host does not advertise VPN transport profile store support", ErrTransportProfileStoreUnavailable)
	}

	if req.TransportProfile != nil && strings.TrimSpace(req.TransportProfile.ProfileID) != "" {
		return h.validateTransportProfileRefLocked(*req.TransportProfile, plan, requiredKinds)
	}

	scopeID := transportProfileDefaultScopeID(plan)
	if defaultProfileID := h.transportProfileDefaults[scopeID]; strings.TrimSpace(defaultProfileID) != "" {
		return h.validateTransportProfileRefLocked(TransportProfileReference{
			ProfileID:      defaultProfileID,
			UseDefault:     true,
			DefaultScopeID: scopeID,
		}, plan, requiredKinds)
	}

	return nil, fmt.Errorf("%w: selected execution plan requires %s transport profile", ErrTransportProfileNotFound, requiredKinds[0])
}

func (h *Host) attachTransportProfileToStartRequest(
	req PlatformTunnelStartRequest,
) (PlatformTunnelStartRequest, PlatformTunnelStartResult, bool) {
	if !h.transportProfileStoreEnabled {
		return req, PlatformTunnelStartResult{}, false
	}
	if strings.TrimSpace(req.ResolutionID) != "" && req.TransportProfile == nil {
		return req, PlatformTunnelStartResult{}, false
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	var selectedDescriptor *RuntimeExecutionPlanDescriptor
	for _, capability := range h.platformTunnels {
		if capability.Mode != req.Mode {
			continue
		}
		if !capability.Available {
			return req, PlatformTunnelStartResult{}, false
		}
		descriptor, err := selectPlatformTunnelExecutionPlanDescriptor(capability.ExecutionPlans, req.ExecutionPlan)
		if err != nil {
			return req, PlatformTunnelStartResult{}, false
		}
		if descriptor.SupportState != RuntimeExecutionPlanSupportStateSupported {
			return req, PlatformTunnelStartResult{}, false
		}
		selectedDescriptor = descriptor
		break
	}
	if selectedDescriptor == nil {
		return req, PlatformTunnelStartResult{}, false
	}
	selectedPlan := selectedDescriptor.Plan
	required := selectedDescriptor.RequiredTransportProfileKinds
	if len(required) == 0 {
		required = requiredTransportProfileKindsForPlan(selectedPlan)
	}
	if len(required) == 0 {
		return req, PlatformTunnelStartResult{}, false
	}
	ref, err := h.resolveTransportProfileForStartupLocked(req, selectedPlan, required)
	if err != nil {
		return req, PlatformTunnelStartResult{
			Mode:                req.Mode,
			ExecutionPlan:       cloneRuntimeExecutionPlan(&selectedPlan),
			Ready:               false,
			Stage:               PlatformTunnelStartupStageProfileValidate,
			MissingPrerequisite: PlatformTunnelPrerequisiteTransportProfile,
			UnderlayRoutePolicy: req.UnderlayRoutePolicy,
			Message:             err.Error(),
		}, true
	}
	req.TransportProfile = ref
	return req, PlatformTunnelStartResult{}, false
}

func (h *Host) validateTransportProfileRefLocked(
	ref TransportProfileReference,
	plan RuntimeExecutionPlan,
	requiredKinds []TransportProfileKind,
) (*TransportProfileReference, error) {
	profileID := strings.TrimSpace(ref.ProfileID)
	if profileID == "" {
		return nil, ErrTransportProfileNotFound
	}
	managed, ok := h.transportProfiles[profileID]
	if !ok {
		return nil, ErrTransportProfileNotFound
	}
	if !transportProfileKindAllowed(managed.status.Kind, requiredKinds) {
		return nil, fmt.Errorf("%w: profile %s has kind %s but selected plan requires %s", ErrTransportProfileIncompatible, profileID, managed.status.Kind, requiredKinds[0])
	}
	if managed.status.Validation.State != TransportProfileValidationStateValid {
		message := strings.TrimSpace(managed.status.Validation.Message)
		if message != "" {
			return nil, fmt.Errorf("%w: profile %s validation state is %s: %s", ErrTransportProfileInvalid, profileID, managed.status.Validation.State, message)
		}
		return nil, fmt.Errorf("%w: profile %s validation state is %s", ErrTransportProfileInvalid, profileID, managed.status.Validation.State)
	}
	if !transportProfileCompatibleWithPlan(managed.status.Kind, plan) {
		return nil, fmt.Errorf("%w: profile %s is not compatible with %s/%s/%s/%s", ErrTransportProfileIncompatible, profileID, plan.AccessMethod, plan.CarrierFamily, plan.EngineFamily, plan.HostAdapter)
	}
	if err := validateTransportProfileMaterialForPlan(managed, plan); err != nil {
		return nil, err
	}
	return &TransportProfileReference{
		ProfileID:      profileID,
		Kind:           managed.status.Kind,
		UseDefault:     ref.UseDefault,
		DefaultScopeID: strings.TrimSpace(ref.DefaultScopeID),
	}, nil
}

func (h *Host) wireGuardProfileForStartupLocked(profileID string) (*wireguardprofile.Profile, error) {
	managed, ok := h.transportProfiles[strings.TrimSpace(profileID)]
	if !ok || managed.wireguard == nil {
		return nil, ErrTransportProfileNotFound
	}
	return cloneWireGuardProfile(managed.wireguard), nil
}

func (h *Host) materializeWireGuardTurnLeaseFromTransportProfile(
	resolutionID string,
	descriptor RuntimeExecutionPlanDescriptor,
	credentials provider.Credentials,
	defaults RuntimeDefaults,
	transportProfile *TransportProfileReference,
) (*WireGuardTurnExecutionLease, error) {
	h.mu.Lock()
	ref, err := h.resolveTransportProfileForStartupLocked(PlatformTunnelStartRequest{
		TransportProfile: cloneTransportProfileReference(transportProfile),
	}, descriptor.Plan, descriptor.RequiredTransportProfileKinds)
	if err != nil {
		h.mu.Unlock()
		return nil, err
	}
	profile, err := h.wireGuardProfileForStartupLocked(ref.ProfileID)
	h.mu.Unlock()
	if err != nil {
		return nil, err
	}

	turnServerAddress := strings.TrimSpace(defaults.TURNServer)
	if turnServerAddress == "" {
		turnServerAddress = strings.TrimSpace(credentials.Address)
	}
	if turnServerAddress == "" {
		return nil, fmt.Errorf("%w: strict WireGuard profile materialization requires a TURN server address", ErrTransportProfileInvalid)
	}
	peerEndpointAddress := strings.TrimSpace(profile.Endpoint)
	if peerEndpointAddress == "" {
		return nil, fmt.Errorf("%w: strict WireGuard profile materialization requires an explicit raw WireGuard ingress endpoint in the transport profile", ErrTransportProfileInvalid)
	}
	var expiresAt *time.Time
	if credentials.TTL > 0 {
		value := h.now().UTC().Add(credentials.TTL)
		expiresAt = &value
	}
	return &WireGuardTurnExecutionLease{
		ResolutionID:               resolutionID,
		AccessMethod:               descriptor.Plan.AccessMethod,
		CarrierFamily:              descriptor.Plan.CarrierFamily,
		EngineFamily:               descriptor.Plan.EngineFamily,
		RemoteEndpointFamily:       descriptor.RemoteEndpointFamily,
		RemoteEndpointRole:         descriptor.RemoteEndpointRole,
		TURNServerAddress:          turnServerAddress,
		TURNUsername:               strings.TrimSpace(credentials.Username),
		TURNPassword:               strings.TrimSpace(credentials.Password),
		PeerEndpointAddress:        peerEndpointAddress,
		ClientPrivateKey:           profile.PrivateKey,
		ClientAddresses:            append([]string(nil), profile.Addresses...),
		PeerPublicKey:              profile.PeerPublicKey,
		PresharedKey:               profile.PresharedKey,
		AllowedIPs:                 append([]string(nil), profile.AllowedIPs...),
		DNSServers:                 append([]string(nil), profile.DNSServers...),
		MTU:                        profile.MTU,
		PersistentKeepaliveSeconds: profile.PersistentKeepaliveSeconds,
		ExpiresAt:                  expiresAt,
	}, nil
}

func (h *Host) defaultBindingsForImportedTransportProfileLocked(
	status TransportProfileStatus,
	requestedPlan *RuntimeExecutionPlan,
) []TransportProfileDefaultBinding {
	if status.Validation.State != TransportProfileValidationStateValid {
		return nil
	}
	plans := compatiblePlansForTransportProfileKind(status.Kind, h.platformTunnels)
	if requestedPlan != nil {
		plans = []RuntimeExecutionPlan{*requestedPlan}
	}
	out := make([]TransportProfileDefaultBinding, 0, len(plans))
	for _, plan := range plans {
		if !transportProfileCompatibleWithPlan(status.Kind, plan) {
			continue
		}
		scopeID := transportProfileDefaultScopeID(plan)
		out = append(out, TransportProfileDefaultBinding{
			ProfileID:   status.ID,
			Kind:        status.Kind,
			HostAdapter: plan.HostAdapter,
			Plan:        plan,
			ScopeID:     scopeID,
		})
	}
	return out
}

func (h *Host) defaultBindingsForTransportProfileLocked(
	status TransportProfileStatus,
) []TransportProfileDefaultBinding {
	if status.Validation.State != TransportProfileValidationStateValid {
		return nil
	}
	plans := compatiblePlansForTransportProfileKind(status.Kind, h.platformTunnels)
	out := make([]TransportProfileDefaultBinding, 0, len(plans))
	for _, plan := range plans {
		scopeID := transportProfileDefaultScopeID(plan)
		if h.transportProfileDefaults[scopeID] != status.ID {
			continue
		}
		out = append(out, TransportProfileDefaultBinding{
			ProfileID:   status.ID,
			Kind:        status.Kind,
			HostAdapter: plan.HostAdapter,
			Plan:        plan,
			ScopeID:     scopeID,
		})
	}
	return out
}

func normalizeTransportProfileImportRequest(req TransportProfileImportRequest) (TransportProfileImportRequest, *wireguardprofile.Profile, error) {
	normalized := req
	normalized.Adapter = TransportProfileImportAdapter(strings.TrimSpace(string(normalized.Adapter)))
	normalized.Kind = TransportProfileKind(strings.TrimSpace(string(normalized.Kind)))
	normalized.DisplayName = strings.TrimSpace(normalized.DisplayName)
	normalized.ReplaceProfileID = strings.TrimSpace(normalized.ReplaceProfileID)

	if normalized.Adapter != TransportProfileImportAdapterWireGuardConf {
		return TransportProfileImportRequest{}, nil, fmt.Errorf("%w: unsupported import adapter %q", ErrTransportProfileInvalid, normalized.Adapter)
	}
	if normalized.Kind != TransportProfileKindWireGuardNativeV1 {
		return TransportProfileImportRequest{}, nil, fmt.Errorf("%w: unsupported profile kind %q", ErrTransportProfileInvalid, normalized.Kind)
	}
	if strings.TrimSpace(normalized.Material) == "" {
		return TransportProfileImportRequest{}, nil, fmt.Errorf("%w: profile material is empty", ErrTransportProfileInvalid)
	}
	parsed, err := wireguardprofile.Parse([]byte(normalized.Material), "imported WireGuard profile")
	if err != nil {
		return TransportProfileImportRequest{}, nil, fmt.Errorf("%w: %v", ErrTransportProfileInvalid, err)
	}
	return normalized, parsed, nil
}

func requiredTransportProfileKindsForPlan(plan RuntimeExecutionPlan) []TransportProfileKind {
	if isStrictWireGuardTurnExecutionPlan(plan) {
		return []TransportProfileKind{TransportProfileKindWireGuardNativeV1}
	}
	return nil
}

func (h *Host) requiredTransportProfileKindsForPlanLocked(plan RuntimeExecutionPlan) []TransportProfileKind {
	for _, capability := range h.platformTunnels {
		for _, descriptor := range capability.ExecutionPlans {
			if !runtimeExecutionPlanEquals(descriptor.Plan, plan) {
				continue
			}
			if len(descriptor.RequiredTransportProfileKinds) > 0 {
				return append([]TransportProfileKind(nil), descriptor.RequiredTransportProfileKinds...)
			}
		}
	}
	return requiredTransportProfileKindsForPlan(plan)
}

func (h *Host) importAdaptersForTransportProfileKindsLocked(required []TransportProfileKind) []TransportProfileImportAdapter {
	capability := h.transportProfileStoreCapabilityLocked()
	if capability == nil || len(required) == 0 {
		return nil
	}
	out := make([]TransportProfileImportAdapter, 0, len(capability.ImportAdapters))
	seen := make(map[TransportProfileImportAdapter]struct{}, len(capability.ImportAdapters))
	for _, descriptor := range capability.ImportAdapters {
		if !transportProfileKindAllowed(descriptor.ProfileKind, required) {
			continue
		}
		if _, ok := seen[descriptor.ID]; ok {
			continue
		}
		seen[descriptor.ID] = struct{}{}
		out = append(out, descriptor.ID)
	}
	return out
}

func isKnownTransportProfileKind(kind TransportProfileKind) bool {
	switch kind {
	case TransportProfileKindWireGuardNativeV1:
		return true
	default:
		return false
	}
}

func transportProfileKindAllowed(kind TransportProfileKind, required []TransportProfileKind) bool {
	for _, candidate := range required {
		if candidate == kind {
			return true
		}
	}
	return false
}

func transportProfileCompatibleWithPlan(kind TransportProfileKind, plan RuntimeExecutionPlan) bool {
	switch kind {
	case TransportProfileKindWireGuardNativeV1:
		return isStrictWireGuardTurnExecutionPlan(plan)
	default:
		return false
	}
}

func (h *Host) transportProfilePlanAdvertisedLocked(
	kind TransportProfileKind,
	plan RuntimeExecutionPlan,
) bool {
	for _, capability := range h.platformTunnels {
		if !capability.Available {
			continue
		}
		for _, descriptor := range capability.ExecutionPlans {
			if descriptor.SupportState != RuntimeExecutionPlanSupportStateSupported {
				continue
			}
			if !runtimeExecutionPlanEquals(descriptor.Plan, plan) {
				continue
			}
			if transportProfileCompatibleWithPlan(kind, descriptor.Plan) {
				return true
			}
		}
	}
	return false
}

func compatiblePlansForTransportProfileKind(
	kind TransportProfileKind,
	capabilities []PlatformTunnelCapability,
) []RuntimeExecutionPlan {
	out := make([]RuntimeExecutionPlan, 0)
	for _, capability := range capabilities {
		for _, descriptor := range capability.ExecutionPlans {
			if !transportProfileCompatibleWithPlan(kind, descriptor.Plan) {
				continue
			}
			out = append(out, descriptor.Plan)
		}
	}
	return out
}

func transportProfileDefaultScopeID(plan RuntimeExecutionPlan) string {
	return strings.Join([]string{
		string(plan.HostAdapter),
		string(plan.AccessMethod),
		string(plan.CarrierFamily),
		string(plan.EngineFamily),
	}, "|")
}

func defaultTransportProfileDisplayName(kind TransportProfileKind) string {
	switch kind {
	case TransportProfileKindWireGuardNativeV1:
		return "WireGuard VPN transport profile"
	default:
		return string(kind)
	}
}

func wireGuardProfileToDisk(profile *wireguardprofile.Profile) *transportProfileDiskWireGuard {
	if profile == nil {
		return nil
	}
	return &transportProfileDiskWireGuard{
		PrivateKey:                 profile.PrivateKey,
		Addresses:                  append([]string(nil), profile.Addresses...),
		DNSServers:                 append([]string(nil), profile.DNSServers...),
		MTU:                        profile.MTU,
		PeerPublicKey:              profile.PeerPublicKey,
		PresharedKey:               profile.PresharedKey,
		AllowedIPs:                 append([]string(nil), profile.AllowedIPs...),
		Endpoint:                   profile.Endpoint,
		PersistentKeepaliveSeconds: profile.PersistentKeepaliveSeconds,
	}
}

func wireGuardProfileFromDisk(profile *transportProfileDiskWireGuard) *wireguardprofile.Profile {
	if profile == nil {
		return nil
	}
	return &wireguardprofile.Profile{
		PrivateKey:                 strings.TrimSpace(profile.PrivateKey),
		Addresses:                  append([]string(nil), profile.Addresses...),
		DNSServers:                 append([]string(nil), profile.DNSServers...),
		MTU:                        profile.MTU,
		PeerPublicKey:              strings.TrimSpace(profile.PeerPublicKey),
		PresharedKey:               strings.TrimSpace(profile.PresharedKey),
		AllowedIPs:                 append([]string(nil), profile.AllowedIPs...),
		Endpoint:                   strings.TrimSpace(profile.Endpoint),
		PersistentKeepaliveSeconds: profile.PersistentKeepaliveSeconds,
	}
}

func wireGuardProfileComplete(profile *wireguardprofile.Profile) bool {
	return profile != nil &&
		strings.TrimSpace(profile.PrivateKey) != "" &&
		len(profile.Addresses) > 0 &&
		strings.TrimSpace(profile.PeerPublicKey) != "" &&
		len(profile.AllowedIPs) > 0
}

func redactedStructuredDraftForTransportProfile(
	status TransportProfileStatus,
	profile *wireguardprofile.Profile,
) *TransportProfileStructuredDraft {
	if status.Kind != TransportProfileKindWireGuardNativeV1 || profile == nil {
		return nil
	}
	fields := map[TransportProfileStructuredFieldID]any{
		TransportProfileStructuredFieldDisplayName:         strings.TrimSpace(status.DisplayName),
		TransportProfileStructuredFieldInterfaceAddresses:  append([]string(nil), profile.Addresses...),
		TransportProfileStructuredFieldDNSServers:          append([]string(nil), profile.DNSServers...),
		TransportProfileStructuredFieldMTU:                 profile.MTU,
		TransportProfileStructuredFieldPeerPublicKey:       strings.TrimSpace(profile.PeerPublicKey),
		TransportProfileStructuredFieldAllowedIPs:          append([]string(nil), profile.AllowedIPs...),
		TransportProfileStructuredFieldEndpoint:            strings.TrimSpace(profile.Endpoint),
		TransportProfileStructuredFieldPersistentKeepalive: profile.PersistentKeepaliveSeconds,
	}
	for field, value := range fields {
		if structuredDraftFieldEmpty(value) {
			delete(fields, field)
		}
	}
	secretActions := make(map[TransportProfileStructuredFieldID]TransportProfileSecretUpdateAction)
	if strings.TrimSpace(profile.PrivateKey) != "" {
		secretActions[TransportProfileStructuredFieldInterfacePrivateKey] = TransportProfileSecretUpdateActionPreserveExisting
	}
	if strings.TrimSpace(profile.PresharedKey) != "" {
		secretActions[TransportProfileStructuredFieldPeerPresharedKey] = TransportProfileSecretUpdateActionPreserveExisting
	}
	return &TransportProfileStructuredDraft{
		Kind:                       status.Kind,
		SchemaVersion:              transportProfileStructuredWireGuardSchemaVersion,
		DisplayName:                strings.TrimSpace(status.DisplayName),
		Fields:                     fields,
		SecretActions:              secretActions,
		InterfaceAddresses:         append([]string(nil), profile.Addresses...),
		DNSServers:                 append([]string(nil), profile.DNSServers...),
		MTU:                        profile.MTU,
		PeerPublicKey:              strings.TrimSpace(profile.PeerPublicKey),
		AllowedIPs:                 append([]string(nil), profile.AllowedIPs...),
		Endpoint:                   strings.TrimSpace(profile.Endpoint),
		PersistentKeepaliveSeconds: profile.PersistentKeepaliveSeconds,
	}
}

func structuredDraftFieldEmpty(value any) bool {
	switch typed := value.(type) {
	case string:
		return strings.TrimSpace(typed) == ""
	case int:
		return typed == 0
	case []string:
		return len(trimStringList(typed)) == 0
	default:
		return value == nil
	}
}

func transportProfileValidationStatus(
	kind TransportProfileKind,
	profile *wireguardprofile.Profile,
) TransportProfileValidationStatus {
	switch kind {
	case TransportProfileKindWireGuardNativeV1:
		return wireGuardTransportProfileValidationStatus(profile)
	default:
		return TransportProfileValidationStatus{
			State:   TransportProfileValidationStateInvalid,
			Message: fmt.Sprintf("unsupported transport profile kind %s", kind),
		}
	}
}

func wireGuardTransportProfileValidationStatus(
	profile *wireguardprofile.Profile,
) TransportProfileValidationStatus {
	if !wireGuardProfileComplete(profile) {
		return TransportProfileValidationStatus{
			State:   TransportProfileValidationStateInvalid,
			Message: "stored transport profile material is unavailable",
		}
	}
	endpoint := strings.TrimSpace(profile.Endpoint)
	if endpoint == "" {
		return TransportProfileValidationStatus{
			State:   TransportProfileValidationStateInvalid,
			Message: "WireGuard transport profile requires an explicit raw WireGuard ingress endpoint",
		}
	}
	if err := validateRawWireGuardIngressEndpoint(endpoint); err != nil {
		return TransportProfileValidationStatus{
			State:   TransportProfileValidationStateInvalid,
			Message: err.Error(),
		}
	}
	return TransportProfileValidationStatus{
		State:       TransportProfileValidationStateValid,
		Fingerprint: wireGuardProfileFingerprint(profile),
	}
}

func validateTransportProfileMaterialForPlan(
	managed managedTransportProfile,
	plan RuntimeExecutionPlan,
) error {
	if managed.status.Kind != TransportProfileKindWireGuardNativeV1 ||
		!isStrictWireGuardTurnExecutionPlan(plan) {
		return nil
	}
	if managed.wireguard == nil {
		return fmt.Errorf("%w: profile %s WireGuard material is unavailable", ErrTransportProfileInvalid, managed.status.ID)
	}
	if err := validateRawWireGuardIngressEndpoint(managed.wireguard.Endpoint); err != nil {
		return fmt.Errorf("%w: profile %s %s", ErrTransportProfileInvalid, managed.status.ID, err)
	}
	return nil
}

func validateRawWireGuardIngressEndpoint(endpoint string) error {
	host, port, err := net.SplitHostPort(strings.TrimSpace(endpoint))
	if err != nil || strings.TrimSpace(host) == "" || strings.TrimSpace(port) == "" {
		return fmt.Errorf("WireGuard transport profile requires raw WireGuard ingress endpoint in host:port form")
	}
	if strings.EqualFold(host, "localhost") {
		return fmt.Errorf("WireGuard transport profile raw ingress endpoint must be remote, got localhost")
	}
	if addr, err := netip.ParseAddr(host); err == nil && (addr.IsLoopback() || addr.IsUnspecified()) {
		return fmt.Errorf("WireGuard transport profile raw ingress endpoint must be remote, got %s", addr)
	}
	return nil
}

func wireGuardProfileFingerprint(profile *wireguardprofile.Profile) string {
	if profile == nil {
		return ""
	}
	h := sha256.New()
	writeFingerprintPart := func(value string) {
		_, _ = h.Write([]byte(strings.TrimSpace(value)))
		_, _ = h.Write([]byte{0})
	}
	for _, address := range profile.Addresses {
		writeFingerprintPart(address)
	}
	writeFingerprintPart(profile.PeerPublicKey)
	for _, allowedIP := range profile.AllowedIPs {
		writeFingerprintPart(allowedIP)
	}
	writeFingerprintPart(profile.Endpoint)
	sum := h.Sum(nil)
	return "sha256:" + hex.EncodeToString(sum[:12])
}

func cloneWireGuardProfile(profile *wireguardprofile.Profile) *wireguardprofile.Profile {
	if profile == nil {
		return nil
	}
	clone := *profile
	clone.Addresses = append([]string(nil), profile.Addresses...)
	clone.DNSServers = append([]string(nil), profile.DNSServers...)
	clone.AllowedIPs = append([]string(nil), profile.AllowedIPs...)
	return &clone
}
