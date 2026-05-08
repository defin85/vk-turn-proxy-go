package clientcontrol

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/wireguardprofile"
	"golang.org/x/crypto/argon2"
	"golang.org/x/crypto/chacha20poly1305"
)

const (
	portableTransportProfileEnvelopeType             = "portable_transport_profile"
	portableTransportProfileEnvelopeVersion          = 1
	portableTransportProfileCryptoSuite              = "argon2id_xchacha20poly1305_v1"
	portableTransportProfileKDFName                  = "argon2id"
	portableTransportProfileQRMaxPayloadBytes        = 2048
	portableTransportProfileSaltBytes                = 16
	portableTransportProfileMinMemoryKiB      uint32 = 65536
	portableTransportProfileMinIterations     uint32 = 3
	portableTransportProfileMinParallelism    uint8  = 1
)

type portableTransportProfileEnvelope struct {
	Type        string                              `json:"type"`
	Version     int                                 `json:"version"`
	ProfileKind TransportProfileKind                `json:"profile_kind"`
	CryptoSuite string                              `json:"crypto_suite"`
	KDF         portableTransportProfileEnvelopeKDF `json:"kdf"`
	Nonce       string                              `json:"nonce"`
	Ciphertext  string                              `json:"ciphertext"`
}

type portableTransportProfileEnvelopeKDF struct {
	Name        string `json:"name"`
	MemoryKiB   uint32 `json:"memory_kib"`
	Iterations  uint32 `json:"iterations"`
	Parallelism uint8  `json:"parallelism"`
	Salt        string `json:"salt"`
}

type portableTransportProfileAAD struct {
	Type        string               `json:"type"`
	Version     int                  `json:"version"`
	ProfileKind TransportProfileKind `json:"profile_kind"`
	CryptoSuite string               `json:"crypto_suite"`
}

type portableTransportProfilePayload struct {
	ProfileKind       TransportProfileKind           `json:"profile_kind"`
	DisplayName       string                         `json:"display_name,omitempty"`
	WireGuardNativeV1 *transportProfileDiskWireGuard `json:"wireguard_native_v1,omitempty"`
}

type portableTransportProfileImportCandidate struct {
	preview             TransportProfilePortableTransferPreview
	resolvedDisplayName string
	kind                TransportProfileKind
	wireguard           *wireguardprofile.Profile
}

type portableTransportProfileBlockedError struct {
	Reason TransportProfilePortableTransferBlockedReason
	Err    error
}

func (e *portableTransportProfileBlockedError) Error() string {
	if e == nil || e.Err == nil {
		return ""
	}
	return e.Err.Error()
}

func (e *portableTransportProfileBlockedError) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.Err
}

func (h *Host) ExportTransportProfilePortable(
	profileID string,
	req TransportProfilePortableExportRequest,
) (TransportProfilePortableExportResult, error) {
	profileID = strings.TrimSpace(profileID)
	if profileID == "" {
		return TransportProfilePortableExportResult{}, ErrTransportProfileNotFound
	}
	passphrase := strings.TrimSpace(req.Passphrase)
	if passphrase == "" {
		return TransportProfilePortableExportResult{}, fmt.Errorf("%w: portable transfer passphrase is required", ErrTransportProfileInvalid)
	}

	h.mu.Lock()
	if !h.transportProfileStoreEnabled {
		h.mu.Unlock()
		return TransportProfilePortableExportResult{}, ErrTransportProfileStoreUnavailable
	}
	managed, ok := h.transportProfiles[profileID]
	if !ok {
		h.mu.Unlock()
		return TransportProfilePortableExportResult{}, ErrTransportProfileNotFound
	}
	if !transportProfilePortableExportAvailable(managed.status.Kind, managed.status.Validation, managed.wireguard) {
		h.mu.Unlock()
		return TransportProfilePortableExportResult{}, fmt.Errorf("%w: profile %s does not support portable export", ErrTransportProfileInvalid, profileID)
	}
	displayName := strings.TrimSpace(managed.status.DisplayName)
	kind := managed.status.Kind
	wireguard := cloneWireGuardProfile(managed.wireguard)
	h.mu.Unlock()

	payload := portableTransportProfilePayload{
		ProfileKind:       kind,
		DisplayName:       displayName,
		WireGuardNativeV1: wireGuardProfileToDisk(wireguard),
	}
	envelope, err := encodePortableTransportProfileEnvelope(payload, passphrase)
	if err != nil {
		return TransportProfilePortableExportResult{}, fmt.Errorf("%w: %v", ErrTransportProfileInvalid, err)
	}
	return TransportProfilePortableExportResult{
		Envelope:     envelope,
		ProfileKind:  kind,
		DisplayName:  displayName,
		EncodedBytes: len([]byte(envelope)),
	}, nil
}

func (h *Host) PreviewTransportProfilePortableImport(
	req TransportProfilePortableImportRequest,
) (TransportProfilePortableTransferPreview, error) {
	candidate, err := h.resolvePortableTransportProfileImportCandidate(req)
	if err != nil {
		var blocked *portableTransportProfileBlockedError
		if errors.As(err, &blocked) {
			return TransportProfilePortableTransferPreview{
				Outcome:       TransportProfilePortableTransferPreviewOutcomeBlocked,
				BlockedReason: blocked.Reason,
			}, nil
		}
		return TransportProfilePortableTransferPreview{}, err
	}
	return cloneTransportProfilePortableTransferPreview(&candidate.preview), nil
}

func (h *Host) ConfirmTransportProfilePortableImport(
	req TransportProfilePortableImportRequest,
) (TransportProfileStatus, error) {
	candidate, err := h.resolvePortableTransportProfileImportCandidate(req)
	if err != nil {
		var blocked *portableTransportProfileBlockedError
		if errors.As(err, &blocked) {
			return TransportProfileStatus{}, fmt.Errorf("%w: %v", ErrTransportProfileInvalid, blocked)
		}
		return TransportProfileStatus{}, err
	}
	if candidate.preview.Outcome != TransportProfilePortableTransferPreviewOutcomeImportable {
		return TransportProfileStatus{}, fmt.Errorf(
			"%w: portable transport-profile import preview outcome is %s",
			ErrTransportProfileInvalid,
			candidate.preview.Outcome,
		)
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return TransportProfileStatus{}, ErrTransportProfileStoreUnavailable
	}
	status, err := h.storeParsedTransportProfileLocked(
		TransportProfileImportRequest{
			Kind:        candidate.kind,
			DisplayName: candidate.resolvedDisplayName,
		},
		candidate.wireguard,
		TransportProfileMaterialSourcePortableTransfer,
		false,
	)
	if err != nil {
		return TransportProfileStatus{}, err
	}
	return cloneTransportProfileStatus(status), nil
}

func (h *Host) resolvePortableTransportProfileImportCandidate(
	req TransportProfilePortableImportRequest,
) (*portableTransportProfileImportCandidate, error) {
	envelopeJSON := strings.TrimSpace(req.Envelope)
	if envelopeJSON == "" {
		return nil, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    errors.New("portable transport-profile envelope is empty"),
		}
	}
	passphrase := strings.TrimSpace(req.Passphrase)
	if passphrase == "" {
		return nil, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonWrongPassphrase,
			Err:    errors.New("portable transport-profile passphrase is required"),
		}
	}

	h.mu.Lock()
	if !h.transportProfileStoreEnabled {
		h.mu.Unlock()
		return nil, ErrTransportProfileStoreUnavailable
	}
	capability := h.transportProfileStoreCapabilityLocked()
	h.mu.Unlock()

	envelope, err := decodePortableTransportProfileEnvelope(envelopeJSON)
	if err != nil {
		var blocked *portableTransportProfileBlockedError
		if errors.As(err, &blocked) {
			return nil, blocked
		}
		return nil, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    err,
		}
	}
	if capability == nil || !transportProfileKindAllowed(envelope.ProfileKind, capability.SupportedKinds) {
		return nil, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonUnsupportedProfileKind,
			Err:    fmt.Errorf("transport profile kind %s is not supported by this host", envelope.ProfileKind),
		}
	}
	payload, err := decryptPortableTransportProfileEnvelope(envelope, passphrase)
	if err != nil {
		return nil, err
	}
	wireguard, err := portableTransportProfilePayloadWireGuard(payload)
	if err != nil {
		return nil, err
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return nil, ErrTransportProfileStoreUnavailable
	}
	compatiblePlans := h.advertisedCompatiblePlansForTransportProfileKindLocked(payload.ProfileKind)
	if len(compatiblePlans) == 0 {
		return nil, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonIncompatibleHost,
			Err:    fmt.Errorf("transport profile kind %s is not compatible with any advertised execution plan on this host", payload.ProfileKind),
		}
	}
	displayName := strings.TrimSpace(payload.DisplayName)
	if displayName == "" {
		displayName = defaultTransportProfileDisplayName(payload.ProfileKind)
	}
	compatibility := TransportProfileCompatibilityStatus{
		State:                    TransportProfileCompatibilityStateCompatible,
		CompatibleExecutionPlans: compatiblePlans,
	}
	duplicateFingerprint := transportProfilePortableDuplicateFingerprint(
		payload.ProfileKind,
		wireguard,
	)
	existingProfiles := h.transportProfilePortableDuplicateMatchesLocked(
		payload.ProfileKind,
		duplicateFingerprint,
	)
	if len(existingProfiles) > 0 {
		selectionRequired := true
		for _, existing := range existingProfiles {
			if len(existing.DefaultFor) > 0 {
				selectionRequired = false
				break
			}
		}
		return &portableTransportProfileImportCandidate{
			preview: TransportProfilePortableTransferPreview{
				Outcome:              TransportProfilePortableTransferPreviewOutcomeAlreadyPresent,
				ProfileKind:          payload.ProfileKind,
				DisplayName:          displayName,
				ResolvedDisplayName:  displayName,
				Compatibility:        cloneTransportProfileCompatibilityStatus(&compatibility),
				SelectionRequired:    selectionRequired,
				DuplicateFingerprint: duplicateFingerprint,
				ExistingProfiles:     existingProfiles,
			},
			resolvedDisplayName: displayName,
			kind:                payload.ProfileKind,
			wireguard:           wireguard,
		}, nil
	}
	resolvedDisplayName, conflict := h.resolvePortableTransportProfileDisplayNameLocked(
		displayName,
	)
	warnings := make([]TransportProfilePortableTransferPreviewWarning, 0, 1)
	if conflict {
		warnings = append(warnings, TransportProfilePortableTransferPreviewWarning{
			Code:    TransportProfilePortableTransferPreviewWarningDisplayNameConflict,
			Message: "display name already exists on this device",
		})
	}
	return &portableTransportProfileImportCandidate{
		preview: TransportProfilePortableTransferPreview{
			Outcome:             TransportProfilePortableTransferPreviewOutcomeImportable,
			ProfileKind:         payload.ProfileKind,
			DisplayName:         displayName,
			ResolvedDisplayName: resolvedDisplayName,
			Compatibility:       cloneTransportProfileCompatibilityStatus(&compatibility),
			SelectionRequired:   true,
			Warnings:            warnings,
		},
		resolvedDisplayName: resolvedDisplayName,
		kind:                payload.ProfileKind,
		wireguard:           wireguard,
	}, nil
}

func cloneTransportProfilePortableTransferPreview(
	preview *TransportProfilePortableTransferPreview,
) TransportProfilePortableTransferPreview {
	if preview == nil {
		return TransportProfilePortableTransferPreview{}
	}
	clone := *preview
	clone.Compatibility = cloneTransportProfileCompatibilityStatus(preview.Compatibility)
	if len(preview.ExistingProfiles) > 0 {
		clone.ExistingProfiles = make(
			[]TransportProfilePortableTransferExistingProfile,
			0,
			len(preview.ExistingProfiles),
		)
		for _, existing := range preview.ExistingProfiles {
			copyExisting := existing
			copyExisting.DefaultFor = cloneTransportProfileDefaultBindings(existing.DefaultFor)
			clone.ExistingProfiles = append(clone.ExistingProfiles, copyExisting)
		}
	}
	if len(preview.Warnings) > 0 {
		clone.Warnings = append(
			[]TransportProfilePortableTransferPreviewWarning(nil),
			preview.Warnings...,
		)
	}
	return clone
}

func encodePortableTransportProfileEnvelope(
	payload portableTransportProfilePayload,
	passphrase string,
) (string, error) {
	plaintext, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	salt, err := portableTransportProfileRandomBytes(portableTransportProfileSaltBytes)
	if err != nil {
		return "", err
	}
	nonce, err := portableTransportProfileRandomBytes(chacha20poly1305.NonceSizeX)
	if err != nil {
		return "", err
	}
	envelope := portableTransportProfileEnvelope{
		Type:        portableTransportProfileEnvelopeType,
		Version:     portableTransportProfileEnvelopeVersion,
		ProfileKind: payload.ProfileKind,
		CryptoSuite: portableTransportProfileCryptoSuite,
		KDF: portableTransportProfileEnvelopeKDF{
			Name:        portableTransportProfileKDFName,
			MemoryKiB:   portableTransportProfileMinMemoryKiB,
			Iterations:  portableTransportProfileMinIterations,
			Parallelism: portableTransportProfileMinParallelism,
			Salt:        base64.RawStdEncoding.EncodeToString(salt),
		},
		Nonce: base64.RawStdEncoding.EncodeToString(nonce),
	}
	key := argon2.IDKey(
		[]byte(passphrase),
		salt,
		envelope.KDF.Iterations,
		envelope.KDF.MemoryKiB,
		envelope.KDF.Parallelism,
		chacha20poly1305.KeySize,
	)
	aead, err := chacha20poly1305.NewX(key)
	if err != nil {
		return "", err
	}
	aad, err := portableTransportProfileAADBytes(envelope)
	if err != nil {
		return "", err
	}
	envelope.Ciphertext = base64.RawStdEncoding.EncodeToString(
		aead.Seal(nil, nonce, plaintext, aad),
	)
	raw, err := json.Marshal(envelope)
	if err != nil {
		return "", err
	}
	return string(raw), nil
}

func decodePortableTransportProfileEnvelope(
	raw string,
) (portableTransportProfileEnvelope, error) {
	var envelope portableTransportProfileEnvelope
	if err := json.Unmarshal([]byte(raw), &envelope); err != nil {
		return portableTransportProfileEnvelope{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    fmt.Errorf("portable transport-profile envelope is invalid JSON: %w", err),
		}
	}
	if strings.TrimSpace(envelope.Type) != portableTransportProfileEnvelopeType {
		return portableTransportProfileEnvelope{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonUnsupportedEnvelope,
			Err:    fmt.Errorf("portable transport-profile envelope type %q is not supported", envelope.Type),
		}
	}
	if envelope.Version != portableTransportProfileEnvelopeVersion {
		return portableTransportProfileEnvelope{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonUnsupportedEnvelope,
			Err:    fmt.Errorf("portable transport-profile envelope version %d is not supported", envelope.Version),
		}
	}
	if strings.TrimSpace(string(envelope.ProfileKind)) == "" {
		return portableTransportProfileEnvelope{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    errors.New("portable transport-profile envelope profile_kind is required"),
		}
	}
	if strings.TrimSpace(envelope.CryptoSuite) != portableTransportProfileCryptoSuite {
		return portableTransportProfileEnvelope{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonUnsupportedEnvelope,
			Err:    fmt.Errorf("portable transport-profile crypto suite %q is not supported", envelope.CryptoSuite),
		}
	}
	if strings.TrimSpace(envelope.KDF.Name) != portableTransportProfileKDFName {
		return portableTransportProfileEnvelope{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonUnsupportedEnvelope,
			Err:    fmt.Errorf("portable transport-profile KDF %q is not supported", envelope.KDF.Name),
		}
	}
	if envelope.KDF.MemoryKiB < portableTransportProfileMinMemoryKiB ||
		envelope.KDF.Iterations < portableTransportProfileMinIterations ||
		envelope.KDF.Parallelism < portableTransportProfileMinParallelism {
		return portableTransportProfileEnvelope{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonUnsupportedEnvelope,
			Err: fmt.Errorf(
				"portable transport-profile KDF params below minimum floor memory_kib=%d iterations=%d parallelism=%d",
				envelope.KDF.MemoryKiB,
				envelope.KDF.Iterations,
				envelope.KDF.Parallelism,
			),
		}
	}
	if strings.TrimSpace(envelope.KDF.Salt) == "" ||
		strings.TrimSpace(envelope.Nonce) == "" ||
		strings.TrimSpace(envelope.Ciphertext) == "" {
		return portableTransportProfileEnvelope{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    errors.New("portable transport-profile envelope is missing salt, nonce, or ciphertext"),
		}
	}
	return envelope, nil
}

func decryptPortableTransportProfileEnvelope(
	envelope portableTransportProfileEnvelope,
	passphrase string,
) (portableTransportProfilePayload, error) {
	salt, err := base64.RawStdEncoding.DecodeString(envelope.KDF.Salt)
	if err != nil {
		return portableTransportProfilePayload{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    fmt.Errorf("portable transport-profile envelope salt is invalid: %w", err),
		}
	}
	nonce, err := base64.RawStdEncoding.DecodeString(envelope.Nonce)
	if err != nil {
		return portableTransportProfilePayload{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    fmt.Errorf("portable transport-profile envelope nonce is invalid: %w", err),
		}
	}
	if len(nonce) != chacha20poly1305.NonceSizeX {
		return portableTransportProfilePayload{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    fmt.Errorf("portable transport-profile envelope nonce size %d is invalid", len(nonce)),
		}
	}
	ciphertext, err := base64.RawStdEncoding.DecodeString(envelope.Ciphertext)
	if err != nil {
		return portableTransportProfilePayload{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    fmt.Errorf("portable transport-profile envelope ciphertext is invalid: %w", err),
		}
	}
	key := argon2.IDKey(
		[]byte(passphrase),
		salt,
		envelope.KDF.Iterations,
		envelope.KDF.MemoryKiB,
		envelope.KDF.Parallelism,
		chacha20poly1305.KeySize,
	)
	aead, err := chacha20poly1305.NewX(key)
	if err != nil {
		return portableTransportProfilePayload{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    err,
		}
	}
	aad, err := portableTransportProfileAADBytes(envelope)
	if err != nil {
		return portableTransportProfilePayload{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    err,
		}
	}
	plaintext, err := aead.Open(nil, nonce, ciphertext, aad)
	if err != nil {
		return portableTransportProfilePayload{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonWrongPassphrase,
			Err:    errors.New("portable transport-profile passphrase is wrong or the envelope was tampered with"),
		}
	}
	var payload portableTransportProfilePayload
	if err := json.Unmarshal(plaintext, &payload); err != nil {
		return portableTransportProfilePayload{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    fmt.Errorf("portable transport-profile payload is invalid JSON: %w", err),
		}
	}
	if payload.ProfileKind != envelope.ProfileKind {
		return portableTransportProfilePayload{}, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
			Err:    fmt.Errorf("portable transport-profile payload kind %q does not match envelope kind %q", payload.ProfileKind, envelope.ProfileKind),
		}
	}
	return payload, nil
}

func portableTransportProfilePayloadWireGuard(
	payload portableTransportProfilePayload,
) (*wireguardprofile.Profile, error) {
	switch payload.ProfileKind {
	case TransportProfileKindWireGuardNativeV1:
		profile := wireGuardProfileFromDisk(payload.WireGuardNativeV1)
		if !wireGuardProfileComplete(profile) {
			return nil, &portableTransportProfileBlockedError{
				Reason: TransportProfilePortableTransferBlockedReasonMalformedEnvelope,
				Err:    errors.New("portable transport-profile payload is missing required WireGuard material"),
			}
		}
		return profile, nil
	default:
		return nil, &portableTransportProfileBlockedError{
			Reason: TransportProfilePortableTransferBlockedReasonUnsupportedProfileKind,
			Err:    fmt.Errorf("transport profile kind %s is not supported", payload.ProfileKind),
		}
	}
}

func portableTransportProfileAADBytes(
	envelope portableTransportProfileEnvelope,
) ([]byte, error) {
	return json.Marshal(portableTransportProfileAAD{
		Type:        envelope.Type,
		Version:     envelope.Version,
		ProfileKind: envelope.ProfileKind,
		CryptoSuite: envelope.CryptoSuite,
	})
}

func portableTransportProfileRandomBytes(size int) ([]byte, error) {
	out := make([]byte, size)
	if _, err := rand.Read(out); err != nil {
		return nil, err
	}
	return out, nil
}

func transportProfilePortableExportAvailable(
	kind TransportProfileKind,
	validation TransportProfileValidationStatus,
	wireguard *wireguardprofile.Profile,
) bool {
	return validation.State == TransportProfileValidationStateValid &&
		kind == TransportProfileKindWireGuardNativeV1 &&
		wireGuardProfileComplete(wireguard)
}

func cloneTransportProfileCompatibilityStatus(
	status *TransportProfileCompatibilityStatus,
) *TransportProfileCompatibilityStatus {
	if status == nil {
		return nil
	}
	clone := *status
	clone.CompatibleExecutionPlans = append([]RuntimeExecutionPlan(nil), status.CompatibleExecutionPlans...)
	return &clone
}

func (h *Host) advertisedCompatiblePlansForTransportProfileKindLocked(
	kind TransportProfileKind,
) []RuntimeExecutionPlan {
	out := make([]RuntimeExecutionPlan, 0)
	for _, capability := range h.platformTunnels {
		if !capability.Available {
			continue
		}
		for _, descriptor := range capability.ExecutionPlans {
			if descriptor.SupportState != RuntimeExecutionPlanSupportStateSupported {
				continue
			}
			if !transportProfileCompatibleWithPlan(kind, descriptor.Plan) {
				continue
			}
			out = append(out, descriptor.Plan)
		}
	}
	return out
}

func transportProfilePortableDuplicateFingerprint(
	kind TransportProfileKind,
	wireguard *wireguardprofile.Profile,
) string {
	h := sha256.New()
	write := func(value string) {
		_, _ = h.Write([]byte(strings.TrimSpace(value)))
		_, _ = h.Write([]byte{0})
	}
	write(string(kind))
	switch kind {
	case TransportProfileKindWireGuardNativeV1:
		if wireguard == nil {
			break
		}
		addresses := append([]string(nil), wireguard.Addresses...)
		sort.Strings(addresses)
		for _, address := range addresses {
			write(address)
		}
		dnsServers := append([]string(nil), wireguard.DNSServers...)
		sort.Strings(dnsServers)
		for _, dnsServer := range dnsServers {
			write(dnsServer)
		}
		write(fmt.Sprintf("%d", wireguard.MTU))
		write(wireguard.PrivateKey)
		write(wireguard.PeerPublicKey)
		write(wireguard.PresharedKey)
		allowedIPs := append([]string(nil), wireguard.AllowedIPs...)
		sort.Strings(allowedIPs)
		for _, allowedIP := range allowedIPs {
			write(allowedIP)
		}
		write(wireguard.Endpoint)
		write(fmt.Sprintf("%d", wireguard.PersistentKeepaliveSeconds))
	}
	sum := h.Sum(nil)
	return "sha256:" + hex.EncodeToString(sum[:12])
}

func (h *Host) transportProfilePortableDuplicateMatchesLocked(
	kind TransportProfileKind,
	fingerprint string,
) []TransportProfilePortableTransferExistingProfile {
	matches := make([]TransportProfilePortableTransferExistingProfile, 0)
	for _, managed := range h.transportProfiles {
		if managed.status.Kind != kind || managed.wireguard == nil {
			continue
		}
		if transportProfilePortableDuplicateFingerprint(kind, managed.wireguard) != fingerprint {
			continue
		}
		matches = append(matches, TransportProfilePortableTransferExistingProfile{
			ProfileID:   managed.status.ID,
			Kind:        managed.status.Kind,
			DisplayName: managed.status.DisplayName,
			DefaultFor:  cloneTransportProfileDefaultBindings(managed.status.DefaultFor),
		})
	}
	sort.Slice(matches, func(i, j int) bool {
		return matches[i].ProfileID < matches[j].ProfileID
	})
	return matches
}

func (h *Host) resolvePortableTransportProfileDisplayNameLocked(
	displayName string,
) (string, bool) {
	displayName = strings.TrimSpace(displayName)
	if displayName == "" {
		displayName = defaultTransportProfileDisplayName(TransportProfileKindWireGuardNativeV1)
	}
	exists := func(candidate string) bool {
		trimmed := strings.TrimSpace(candidate)
		for _, managed := range h.transportProfiles {
			if strings.EqualFold(strings.TrimSpace(managed.status.DisplayName), trimmed) {
				return true
			}
		}
		return false
	}
	if !exists(displayName) {
		return displayName, false
	}
	for suffix := 2; suffix < 10_000; suffix++ {
		candidate := fmt.Sprintf("%s (%d)", displayName, suffix)
		if !exists(candidate) {
			return candidate, true
		}
	}
	return displayName, true
}
