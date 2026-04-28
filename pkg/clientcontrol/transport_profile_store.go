package clientcontrol

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
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
	PrivateKey    string   `json:"private_key"`
	Addresses     []string `json:"addresses,omitempty"`
	DNSServers    []string `json:"dns_servers,omitempty"`
	MTU           int      `json:"mtu,omitempty"`
	PeerPublicKey string   `json:"peer_public_key"`
	AllowedIPs    []string `json:"allowed_ips,omitempty"`
	Endpoint      string   `json:"endpoint,omitempty"`
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
			ID:          TransportProfileImportAdapterWireGuardConf,
			ProfileKind: TransportProfileKindWireGuardNativeV1,
			DisplayName: "WireGuard .conf",
			Extensions:  []string{"conf"},
		}},
		LifecycleActions: []TransportProfileLifecycleAction{
			TransportProfileLifecycleActionList,
			TransportProfileLifecycleActionImport,
			TransportProfileLifecycleActionReplace,
			TransportProfileLifecycleActionForget,
			TransportProfileLifecycleActionValidate,
			TransportProfileLifecycleActionSelectForStartup,
		},
		RedactionGuarantees: []string{
			"ordinary_reads_exclude_raw_material",
			"ordinary_reads_exclude_private_keys",
			"ordinary_reads_exclude_host_private_paths",
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
	return &clone
}

func cloneTransportProfileStatus(status TransportProfileStatus) TransportProfileStatus {
	clone := status
	clone.Actions = append([]TransportProfileLifecycleAction(nil), status.Actions...)
	clone.DefaultFor = cloneTransportProfileDefaultBindings(status.DefaultFor)
	clone.Compatibility.CompatibleExecutionPlans = append([]RuntimeExecutionPlan(nil), status.Compatibility.CompatibleExecutionPlans...)
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
			if status.State != TransportProfileCompatibilityStateCompatible {
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
		ImportAdapters: []TransportProfileImportAdapter{TransportProfileImportAdapterWireGuardConf},
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
		}
	}
	for _, managed := range h.transportProfiles {
		if !transportProfileKindAllowed(managed.status.Kind, required) {
			continue
		}
		if transportProfileCompatibleWithPlan(managed.status.Kind, plan) &&
			managed.status.Validation.State == TransportProfileValidationStateValid {
			status.State = TransportProfileCompatibilityStateCompatible
			status.SelectedProfile = &TransportProfileReference{
				ProfileID: managed.status.ID,
				Kind:      managed.status.Kind,
			}
			status.MissingKind = ""
			status.Message = ""
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
	requiredKinds := requiredTransportProfileKindsForPlan(req.Plan)
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
		Actions:    transportProfileStatusActions(),
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
) (TransportProfileStatus, error) {
	profileID := strings.TrimSpace(normalized.ReplaceProfileID)
	if profileID == "" {
		profileID = h.newID()
	}
	importedAt := h.now().UTC()
	if existing, ok := h.transportProfiles[profileID]; ok && !existing.status.ImportedAt.IsZero() {
		importedAt = existing.status.ImportedAt.UTC()
	}

	status := TransportProfileStatus{
		ID:          profileID,
		Kind:        normalized.Kind,
		Version:     "1",
		DisplayName: firstNonEmpty(normalized.DisplayName, defaultTransportProfileDisplayName(normalized.Kind)),
		Validation: TransportProfileValidationStatus{
			State:       TransportProfileValidationStateValid,
			Fingerprint: wireGuardProfileFingerprint(parsed),
		},
		Compatibility: TransportProfileCompatibilityStatus{
			State: TransportProfileCompatibilityStateCompatible,
			CompatibleExecutionPlans: compatiblePlansForTransportProfileKind(
				normalized.Kind,
				h.platformTunnels,
			),
		},
		SecretMaterialRef: TransportProfileSecretMaterialRef{
			Kind: materialSource,
			Ref:  "host-owned:" + profileID,
		},
		Actions:    transportProfileStatusActions(),
		ImportedAt: importedAt,
		UpdatedAt:  h.now().UTC(),
	}
	status.DefaultFor = h.defaultBindingsForImportedTransportProfileLocked(status, normalized.DefaultFor)

	previousProfile, hadPreviousProfile := h.transportProfiles[profileID]
	previousDefaults := cloneTransportProfileDefaults(h.transportProfileDefaults)
	h.transportProfiles[profileID] = managedTransportProfile{
		status:    cloneTransportProfileStatus(status),
		wireguard: cloneWireGuardProfile(parsed),
	}
	for _, binding := range status.DefaultFor {
		h.transportProfileDefaults[binding.ScopeID] = profileID
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
		if !wireGuardProfileComplete(profile) {
			status.Validation = TransportProfileValidationStatus{
				State:   TransportProfileValidationStateInvalid,
				Message: "stored transport profile material is unavailable",
			}
			profile = nil
		} else {
			status.Validation.State = TransportProfileValidationStateValid
			status.Validation.Message = ""
			status.Validation.Fingerprint = wireGuardProfileFingerprint(profile)
		}
		status.SecretMaterialRef.Ref = "host-owned:" + status.ID
		if status.SecretMaterialRef.Kind == "" {
			status.SecretMaterialRef.Kind = TransportProfileMaterialSourceImportAdapter
		}
		status.Actions = transportProfileStatusActions()
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
		record := transportProfileDiskRecord{
			Status: cloneTransportProfileStatus(managed.status),
		}
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
	status.Actions = transportProfileStatusActions()
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

func transportProfileStatusActions() []TransportProfileLifecycleAction {
	return []TransportProfileLifecycleAction{
		TransportProfileLifecycleActionValidate,
		TransportProfileLifecycleActionReplace,
		TransportProfileLifecycleActionForget,
		TransportProfileLifecycleActionSelectForStartup,
	}
}

func (h *Host) resolveTransportProfileForStartupLocked(
	req PlatformTunnelStartRequest,
	plan RuntimeExecutionPlan,
) (*TransportProfileReference, error) {
	requiredKinds := requiredTransportProfileKindsForPlan(plan)
	if len(requiredKinds) == 0 {
		return nil, nil
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
	ref, err := h.resolveTransportProfileForStartupLocked(req, selectedPlan)
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
		return nil, fmt.Errorf("%w: profile %s validation state is %s", ErrTransportProfileInvalid, profileID, managed.status.Validation.State)
	}
	if !transportProfileCompatibleWithPlan(managed.status.Kind, plan) {
		return nil, fmt.Errorf("%w: profile %s is not compatible with %s/%s/%s/%s", ErrTransportProfileIncompatible, profileID, plan.AccessMethod, plan.CarrierFamily, plan.EngineFamily, plan.HostAdapter)
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
	}, descriptor.Plan)
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
	peerEndpointAddress := strings.TrimSpace(defaults.PeerAddr)
	if peerEndpointAddress == "" {
		peerEndpointAddress = strings.TrimSpace(profile.Endpoint)
	}
	if peerEndpointAddress == "" {
		return nil, fmt.Errorf("%w: strict WireGuard profile materialization requires a peer endpoint address", ErrTransportProfileInvalid)
	}
	var expiresAt *time.Time
	if credentials.TTL > 0 {
		value := h.now().UTC().Add(credentials.TTL)
		expiresAt = &value
	}
	return &WireGuardTurnExecutionLease{
		ResolutionID:         resolutionID,
		AccessMethod:         descriptor.Plan.AccessMethod,
		CarrierFamily:        descriptor.Plan.CarrierFamily,
		EngineFamily:         descriptor.Plan.EngineFamily,
		RemoteEndpointFamily: descriptor.RemoteEndpointFamily,
		RemoteEndpointRole:   WireGuardTurnRemoteEndpointRoleDatagramTermination,
		TURNServerAddress:    turnServerAddress,
		TURNUsername:         strings.TrimSpace(credentials.Username),
		TURNPassword:         strings.TrimSpace(credentials.Password),
		PeerEndpointAddress:  peerEndpointAddress,
		ClientPrivateKey:     profile.PrivateKey,
		ClientAddresses:      append([]string(nil), profile.Addresses...),
		PeerPublicKey:        profile.PeerPublicKey,
		AllowedIPs:           append([]string(nil), profile.AllowedIPs...),
		DNSServers:           append([]string(nil), profile.DNSServers...),
		MTU:                  profile.MTU,
		ExpiresAt:            expiresAt,
	}, nil
}

func (h *Host) defaultBindingsForImportedTransportProfileLocked(
	status TransportProfileStatus,
	requestedPlan *RuntimeExecutionPlan,
) []TransportProfileDefaultBinding {
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
		PrivateKey:    profile.PrivateKey,
		Addresses:     append([]string(nil), profile.Addresses...),
		DNSServers:    append([]string(nil), profile.DNSServers...),
		MTU:           profile.MTU,
		PeerPublicKey: profile.PeerPublicKey,
		AllowedIPs:    append([]string(nil), profile.AllowedIPs...),
		Endpoint:      profile.Endpoint,
	}
}

func wireGuardProfileFromDisk(profile *transportProfileDiskWireGuard) *wireguardprofile.Profile {
	if profile == nil {
		return nil
	}
	return &wireguardprofile.Profile{
		PrivateKey:    strings.TrimSpace(profile.PrivateKey),
		Addresses:     append([]string(nil), profile.Addresses...),
		DNSServers:    append([]string(nil), profile.DNSServers...),
		MTU:           profile.MTU,
		PeerPublicKey: strings.TrimSpace(profile.PeerPublicKey),
		AllowedIPs:    append([]string(nil), profile.AllowedIPs...),
		Endpoint:      strings.TrimSpace(profile.Endpoint),
	}
}

func wireGuardProfileComplete(profile *wireguardprofile.Profile) bool {
	return profile != nil &&
		strings.TrimSpace(profile.PrivateKey) != "" &&
		len(profile.Addresses) > 0 &&
		strings.TrimSpace(profile.PeerPublicKey) != "" &&
		len(profile.AllowedIPs) > 0
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
