package clientcontrol

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"net/netip"
	"strconv"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/wireguardprofile"
	"golang.org/x/crypto/curve25519"
)

const transportProfileStructuredWireGuardSchemaVersion = "wireguard_native_v1.structured_editor.v1"

func defaultTransportProfileEditableKindSchemas() []TransportProfileEditableKindSchema {
	privateKeyActions := []TransportProfileSecretUpdateAction{
		TransportProfileSecretUpdateActionPreserveExisting,
		TransportProfileSecretUpdateActionReplaceSubmitted,
		TransportProfileSecretUpdateActionGenerateHost,
	}
	secretReplacementActions := []TransportProfileSecretUpdateAction{
		TransportProfileSecretUpdateActionPreserveExisting,
		TransportProfileSecretUpdateActionReplaceSubmitted,
	}
	return []TransportProfileEditableKindSchema{{
		Kind:          TransportProfileKindWireGuardNativeV1,
		SchemaVersion: transportProfileStructuredWireGuardSchemaVersion,
		LifecycleActions: []TransportProfileLifecycleAction{
			TransportProfileLifecycleActionCreateStructured,
			TransportProfileLifecycleActionUpdateStructured,
			TransportProfileLifecycleActionValidateDraft,
			TransportProfileLifecycleActionGenerateKey,
		},
		Fields: []TransportProfileStructuredFieldDescriptor{
			{
				ID:          TransportProfileStructuredFieldDisplayName,
				DisplayName: "Name",
				Group:       "profile",
				Order:       10,
				ValueKind:   TransportProfileStructuredFieldValueKindString,
				Supported:   true,
			},
			{
				ID:                  TransportProfileStructuredFieldInterfacePrivateKey,
				DisplayName:         "Private key",
				HelpText:            "Generate on save or replace with submitted WireGuard private key material.",
				Group:               "interface",
				Order:               20,
				ValueKind:           TransportProfileStructuredFieldValueKindSecretString,
				Required:            true,
				Secret:              true,
				Generated:           true,
				UpdatePreservable:   true,
				ManualReplacement:   true,
				Supported:           true,
				SecretUpdateActions: privateKeyActions,
			},
			{
				ID:          TransportProfileStructuredFieldInterfaceAddresses,
				DisplayName: "Interface addresses",
				Group:       "interface",
				Order:       30,
				ValueKind:   TransportProfileStructuredFieldValueKindStringList,
				Cardinality: TransportProfileStructuredFieldCardinalityMany,
				Required:    true,
				MinItems:    1,
				Supported:   true,
			},
			{
				ID:          TransportProfileStructuredFieldDNSServers,
				DisplayName: "DNS servers",
				Group:       "interface",
				Order:       40,
				ValueKind:   TransportProfileStructuredFieldValueKindStringList,
				Cardinality: TransportProfileStructuredFieldCardinalityMany,
				Supported:   true,
			},
			{
				ID:             TransportProfileStructuredFieldMTU,
				DisplayName:    "MTU",
				Group:          "interface",
				Order:          50,
				ValueKind:      TransportProfileStructuredFieldValueKindInteger,
				DefaultInteger: 1280,
				Supported:      true,
			},
			{
				ID:          TransportProfileStructuredFieldPeerPublicKey,
				DisplayName: "Peer public key",
				Group:       "peer",
				Order:       60,
				ValueKind:   TransportProfileStructuredFieldValueKindString,
				Required:    true,
				Supported:   true,
			},
			{
				ID:                  TransportProfileStructuredFieldPeerPresharedKey,
				DisplayName:         "Peer preshared key",
				Group:               "peer",
				Order:               70,
				ValueKind:           TransportProfileStructuredFieldValueKindSecretString,
				Secret:              true,
				UpdatePreservable:   true,
				ManualReplacement:   true,
				Supported:           true,
				SecretUpdateActions: secretReplacementActions,
			},
			{
				ID:                TransportProfileStructuredFieldAllowedIPs,
				DisplayName:       "Allowed IPs",
				Group:             "peer",
				Order:             80,
				ValueKind:         TransportProfileStructuredFieldValueKindStringList,
				Cardinality:       TransportProfileStructuredFieldCardinalityMany,
				Required:          true,
				MinItems:          1,
				DefaultStringList: []string{"0.0.0.0/0"},
				Supported:         true,
			},
			{
				ID:          TransportProfileStructuredFieldEndpoint,
				DisplayName: "Endpoint",
				Group:       "peer",
				Order:       90,
				ValueKind:   TransportProfileStructuredFieldValueKindString,
				Required:    true,
				Supported:   true,
			},
			{
				ID:          TransportProfileStructuredFieldPersistentKeepalive,
				DisplayName: "Persistent keepalive",
				Group:       "peer",
				Order:       100,
				ValueKind:   TransportProfileStructuredFieldValueKindInteger,
				Supported:   true,
			},
		},
	}}
}

func cloneTransportProfileEditableKindSchemas(schemas []TransportProfileEditableKindSchema) []TransportProfileEditableKindSchema {
	if len(schemas) == 0 {
		return nil
	}
	out := make([]TransportProfileEditableKindSchema, 0, len(schemas))
	for _, schema := range schemas {
		clone := schema
		clone.Fields = cloneTransportProfileStructuredFieldDescriptors(schema.Fields)
		clone.LifecycleActions = append([]TransportProfileLifecycleAction(nil), schema.LifecycleActions...)
		out = append(out, clone)
	}
	return out
}

func cloneTransportProfileStructuredFieldDescriptors(
	fields []TransportProfileStructuredFieldDescriptor,
) []TransportProfileStructuredFieldDescriptor {
	if len(fields) == 0 {
		return nil
	}
	out := make([]TransportProfileStructuredFieldDescriptor, 0, len(fields))
	for _, field := range fields {
		clone := field
		clone.SecretUpdateActions = append([]TransportProfileSecretUpdateAction(nil), field.SecretUpdateActions...)
		clone.DefaultStringList = append([]string(nil), field.DefaultStringList...)
		out = append(out, clone)
	}
	return out
}

func (h *Host) CreateStructuredTransportProfile(
	req TransportProfileStructuredCreateRequest,
) (TransportProfileStructuredSaveResult, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return TransportProfileStructuredSaveResult{}, ErrTransportProfileStoreUnavailable
	}
	normalized, profile, generatedKeys, result := normalizeStructuredWireGuardDraft(req.Draft, nil, false)
	if !result.Valid {
		return TransportProfileStructuredSaveResult{}, structuredDraftInvalidError(result)
	}
	status, err := h.storeParsedTransportProfileLocked(
		normalized,
		profile,
		TransportProfileMaterialSourceStructured,
		true,
	)
	if err != nil {
		return TransportProfileStructuredSaveResult{}, err
	}
	return TransportProfileStructuredSaveResult{
		Profile:       cloneTransportProfileStatus(status),
		GeneratedKeys: generatedKeys,
	}, nil
}

func (h *Host) UpdateStructuredTransportProfile(
	profileID string,
	req TransportProfileStructuredUpdateRequest,
) (TransportProfileStructuredSaveResult, error) {
	profileID = strings.TrimSpace(profileID)
	if profileID == "" {
		return TransportProfileStructuredSaveResult{}, ErrTransportProfileNotFound
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return TransportProfileStructuredSaveResult{}, ErrTransportProfileStoreUnavailable
	}
	existing, ok := h.transportProfiles[profileID]
	if !ok || existing.wireguard == nil {
		return TransportProfileStructuredSaveResult{}, ErrTransportProfileNotFound
	}
	normalized, profile, generatedKeys, result := normalizeStructuredWireGuardDraft(req.Draft, existing.wireguard, true)
	if !result.Valid {
		return TransportProfileStructuredSaveResult{}, structuredDraftInvalidError(result)
	}
	normalized.ReplaceProfileID = profileID
	status, err := h.storeParsedTransportProfileLocked(
		normalized,
		profile,
		TransportProfileMaterialSourceStructured,
		true,
	)
	if err != nil {
		return TransportProfileStructuredSaveResult{}, err
	}
	return TransportProfileStructuredSaveResult{
		Profile:       cloneTransportProfileStatus(status),
		GeneratedKeys: generatedKeys,
	}, nil
}

func (h *Host) ValidateStructuredTransportProfileDraft(
	req TransportProfileStructuredValidationRequest,
) (TransportProfileStructuredValidationResult, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return TransportProfileStructuredValidationResult{}, ErrTransportProfileStoreUnavailable
	}

	var existing *wireguardprofile.Profile
	if profileID := strings.TrimSpace(req.ProfileID); profileID != "" {
		managed, ok := h.transportProfiles[profileID]
		if !ok || managed.wireguard == nil {
			return TransportProfileStructuredValidationResult{}, ErrTransportProfileNotFound
		}
		existing = managed.wireguard
	}
	_, _, _, result := normalizeStructuredWireGuardDraft(req.Draft, existing, existing != nil)
	return result, nil
}

func (h *Host) GenerateTransportProfileKey(
	req TransportProfileGenerateKeyRequest,
) (TransportProfileGeneratedKey, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.transportProfileStoreEnabled {
		return TransportProfileGeneratedKey{}, ErrTransportProfileStoreUnavailable
	}
	kind := TransportProfileKind(strings.TrimSpace(string(req.Kind)))
	if kind == "" {
		kind = TransportProfileKindWireGuardNativeV1
	}
	if kind != TransportProfileKindWireGuardNativeV1 {
		return TransportProfileGeneratedKey{}, fmt.Errorf("%w: unsupported profile kind %q", ErrTransportProfileInvalid, kind)
	}
	field := req.Field
	if field == "" {
		field = TransportProfileStructuredFieldInterfacePrivateKey
	}
	if field != TransportProfileStructuredFieldInterfacePrivateKey {
		return TransportProfileGeneratedKey{}, fmt.Errorf("%w: field %q does not support host key generation", ErrTransportProfileInvalid, field)
	}
	_, publicKey, err := generateWireGuardKeyPair()
	if err != nil {
		return TransportProfileGeneratedKey{}, err
	}
	return TransportProfileGeneratedKey{
		Kind:        kind,
		Field:       field,
		PublicKey:   publicKey,
		Fingerprint: wireGuardGeneratedKeyFingerprint(publicKey),
	}, nil
}

func normalizeStructuredWireGuardDraft(
	draft TransportProfileStructuredDraft,
	existing *wireguardprofile.Profile,
	updating bool,
) (TransportProfileImportRequest, *wireguardprofile.Profile, []TransportProfileGeneratedKey, TransportProfileStructuredValidationResult) {
	var errors []TransportProfileFieldValidationError
	var generatedKeys []TransportProfileGeneratedKey
	addError := func(field TransportProfileStructuredFieldID, violation, message string) {
		errors = append(errors, TransportProfileFieldValidationError{
			Field:     field,
			Violation: violation,
			Message:   message,
		})
	}

	kind := TransportProfileKind(strings.TrimSpace(string(draft.Kind)))
	if kind == "" {
		kind = TransportProfileKindWireGuardNativeV1
	}
	if kind != TransportProfileKindWireGuardNativeV1 {
		addError(TransportProfileStructuredFieldSchemaVersion, "unsupported", fmt.Sprintf("unsupported profile kind %q", kind))
	}
	if schemaVersion := strings.TrimSpace(draft.SchemaVersion); schemaVersion != "" &&
		schemaVersion != transportProfileStructuredWireGuardSchemaVersion {
		addError(TransportProfileStructuredFieldSchemaVersion, "unsupported", fmt.Sprintf("unsupported schema version %q", schemaVersion))
	}
	if draft.DefaultFor != nil {
		if err := validateRuntimeExecutionPlan(*draft.DefaultFor); err != nil {
			addError(TransportProfileStructuredFieldSchemaVersion, "malformed", fmt.Sprintf("default execution plan is invalid: %v", err))
		}
	}
	validateSubmittedStructuredFields(draft, addError)

	privateKey := normalizeStructuredPrivateKey(draft, existing, updating, &generatedKeys, addError)
	presharedKey := normalizeStructuredPresharedKey(draft, existing, updating, addError)
	addresses := structuredStringListField(draft, TransportProfileStructuredFieldInterfaceAddresses, draft.InterfaceAddresses, addError)
	if len(addresses) == 0 {
		addError(TransportProfileStructuredFieldInterfaceAddresses, "required", "at least one interface address is required")
	} else {
		validatePrefixes(addresses, TransportProfileStructuredFieldInterfaceAddresses, addError)
	}
	dnsServers := structuredStringListField(draft, TransportProfileStructuredFieldDNSServers, draft.DNSServers, addError)
	validateAddrs(dnsServers, TransportProfileStructuredFieldDNSServers, addError)
	mtu := structuredIntField(draft, TransportProfileStructuredFieldMTU, draft.MTU, addError)
	if mtu == 0 {
		mtu = 1280
	}
	if mtu < 576 || mtu > 9000 {
		addError(TransportProfileStructuredFieldMTU, "out_of_range", "MTU must be between 576 and 9000")
	}
	peerPublicKey := structuredStringField(draft, TransportProfileStructuredFieldPeerPublicKey, draft.PeerPublicKey, addError)
	if peerPublicKey == "" {
		addError(TransportProfileStructuredFieldPeerPublicKey, "required", "peer public key is required")
	} else if err := validateWireGuardBase64Key(peerPublicKey); err != nil {
		addError(TransportProfileStructuredFieldPeerPublicKey, "malformed", err.Error())
	}
	allowedIPs := structuredStringListField(draft, TransportProfileStructuredFieldAllowedIPs, draft.AllowedIPs, addError)
	if len(allowedIPs) == 0 {
		addError(TransportProfileStructuredFieldAllowedIPs, "required", "at least one allowed IP prefix is required")
	} else {
		validatePrefixes(allowedIPs, TransportProfileStructuredFieldAllowedIPs, addError)
	}
	endpoint := structuredStringField(draft, TransportProfileStructuredFieldEndpoint, draft.Endpoint, addError)
	if endpoint == "" {
		addError(TransportProfileStructuredFieldEndpoint, "required", "peer endpoint is required")
	} else if err := validateWireGuardEndpoint(endpoint); err != nil {
		addError(TransportProfileStructuredFieldEndpoint, "malformed", err.Error())
	}
	persistentKeepaliveSeconds := structuredIntField(
		draft,
		TransportProfileStructuredFieldPersistentKeepalive,
		draft.PersistentKeepaliveSeconds,
		addError,
	)
	if persistentKeepaliveSeconds < 0 || persistentKeepaliveSeconds > 65535 {
		addError(TransportProfileStructuredFieldPersistentKeepalive, "out_of_range", "persistent keepalive must be between 0 and 65535 seconds")
	}
	displayName := structuredStringField(draft, TransportProfileStructuredFieldDisplayName, draft.DisplayName, addError)

	if len(errors) > 0 {
		return TransportProfileImportRequest{}, nil, nil, TransportProfileStructuredValidationResult{
			Valid:  false,
			Errors: errors,
		}
	}

	profile := &wireguardprofile.Profile{
		PrivateKey:                 privateKey,
		Addresses:                  addresses,
		DNSServers:                 dnsServers,
		MTU:                        mtu,
		PeerPublicKey:              peerPublicKey,
		PresharedKey:               presharedKey,
		AllowedIPs:                 allowedIPs,
		Endpoint:                   endpoint,
		PersistentKeepaliveSeconds: persistentKeepaliveSeconds,
	}
	status := &TransportProfileValidationStatus{
		State:       TransportProfileValidationStateValid,
		Fingerprint: wireGuardProfileFingerprint(profile),
	}
	return TransportProfileImportRequest{
			Kind:        kind,
			DisplayName: displayName,
			DefaultFor:  cloneRuntimeExecutionPlan(draft.DefaultFor),
		}, profile, generatedKeys, TransportProfileStructuredValidationResult{
			Valid:  true,
			Status: status,
		}
}

func normalizeStructuredPrivateKey(
	draft TransportProfileStructuredDraft,
	existing *wireguardprofile.Profile,
	updating bool,
	generatedKeys *[]TransportProfileGeneratedKey,
	addError func(TransportProfileStructuredFieldID, string, string),
) string {
	legacyAction := draft.InterfacePrivateKeyAction
	rawAction := strings.TrimSpace(string(secretActionForField(draft, TransportProfileStructuredFieldInterfacePrivateKey, legacyAction)))
	action := normalizeSecretUpdateAction(secretActionForField(draft, TransportProfileStructuredFieldInterfacePrivateKey, legacyAction))
	submitted := structuredStringField(draft, TransportProfileStructuredFieldInterfacePrivateKey, draft.InterfacePrivateKey, addError)
	if rawAction != "" && action == "" {
		addError(TransportProfileStructuredFieldInterfacePrivateKey, "invalid_action", fmt.Sprintf("unsupported secret update action %q", rawAction))
		return ""
	}
	switch {
	case action == TransportProfileSecretUpdateActionGenerateHost:
		privateKey, publicKey, err := generateWireGuardKeyPair()
		if err != nil {
			addError(TransportProfileStructuredFieldInterfacePrivateKey, "generation_failed", err.Error())
			return ""
		}
		*generatedKeys = append(*generatedKeys, TransportProfileGeneratedKey{
			Kind:        TransportProfileKindWireGuardNativeV1,
			Field:       TransportProfileStructuredFieldInterfacePrivateKey,
			PublicKey:   publicKey,
			Fingerprint: wireGuardGeneratedKeyFingerprint(publicKey),
		})
		return privateKey
	case action == TransportProfileSecretUpdateActionPreserveExisting:
		if !updating || existing == nil || strings.TrimSpace(existing.PrivateKey) == "" {
			addError(TransportProfileStructuredFieldInterfacePrivateKey, "invalid_action", "there is no existing private key to preserve")
			return ""
		}
		return strings.TrimSpace(existing.PrivateKey)
	case action == TransportProfileSecretUpdateActionReplaceSubmitted:
		if submitted == "" {
			addError(TransportProfileStructuredFieldInterfacePrivateKey, "required", "private key is required when replacing submitted secret material")
			return ""
		}
		if err := validateWireGuardBase64Key(submitted); err != nil {
			addError(TransportProfileStructuredFieldInterfacePrivateKey, "malformed", err.Error())
		}
		return submitted
	case submitted != "":
		if err := validateWireGuardBase64Key(submitted); err != nil {
			addError(TransportProfileStructuredFieldInterfacePrivateKey, "malformed", err.Error())
		}
		return submitted
	case updating && existing != nil && strings.TrimSpace(existing.PrivateKey) != "":
		return strings.TrimSpace(existing.PrivateKey)
	default:
		addError(TransportProfileStructuredFieldInterfacePrivateKey, "required", "private key is required or must be generated by the host")
		return ""
	}
}

func normalizeStructuredPresharedKey(
	draft TransportProfileStructuredDraft,
	existing *wireguardprofile.Profile,
	updating bool,
	addError func(TransportProfileStructuredFieldID, string, string),
) string {
	legacyAction := draft.PeerPresharedKeyAction
	rawAction := strings.TrimSpace(string(secretActionForField(draft, TransportProfileStructuredFieldPeerPresharedKey, legacyAction)))
	action := normalizeSecretUpdateAction(secretActionForField(draft, TransportProfileStructuredFieldPeerPresharedKey, legacyAction))
	submitted := structuredStringField(draft, TransportProfileStructuredFieldPeerPresharedKey, draft.PeerPresharedKey, addError)
	if rawAction != "" && action == "" {
		addError(TransportProfileStructuredFieldPeerPresharedKey, "invalid_action", fmt.Sprintf("unsupported secret update action %q", rawAction))
		return ""
	}
	switch {
	case action == TransportProfileSecretUpdateActionGenerateHost:
		addError(TransportProfileStructuredFieldPeerPresharedKey, "invalid_action", "preshared keys do not expose safe public-key metadata")
		return ""
	case action == TransportProfileSecretUpdateActionPreserveExisting:
		if updating && existing != nil {
			return strings.TrimSpace(existing.PresharedKey)
		}
		addError(TransportProfileStructuredFieldPeerPresharedKey, "invalid_action", "there is no existing preshared key to preserve")
		return ""
	case action == TransportProfileSecretUpdateActionReplaceSubmitted:
		if submitted != "" {
			if err := validateWireGuardBase64Key(submitted); err != nil {
				addError(TransportProfileStructuredFieldPeerPresharedKey, "malformed", err.Error())
			}
		}
		return submitted
	case submitted != "":
		if err := validateWireGuardBase64Key(submitted); err != nil {
			addError(TransportProfileStructuredFieldPeerPresharedKey, "malformed", err.Error())
		}
		return submitted
	case updating && existing != nil:
		return strings.TrimSpace(existing.PresharedKey)
	default:
		return ""
	}
}

func validateSubmittedStructuredFields(
	draft TransportProfileStructuredDraft,
	addError func(TransportProfileStructuredFieldID, string, string),
) {
	if len(draft.Fields) == 0 && len(draft.SecretActions) == 0 {
		return
	}
	kind := TransportProfileKind(strings.TrimSpace(string(draft.Kind)))
	if kind == "" {
		kind = TransportProfileKindWireGuardNativeV1
	}
	descriptors := transportProfileStructuredFieldDescriptorMap(kind)
	if len(descriptors) == 0 {
		for field := range draft.Fields {
			addError(field, "unsupported", fmt.Sprintf("profile kind %q does not advertise structured field %q", kind, field))
		}
		for field := range draft.SecretActions {
			addError(field, "unsupported", fmt.Sprintf("profile kind %q does not advertise secret action %q", kind, field))
		}
		return
	}
	for field := range draft.Fields {
		descriptor, ok := descriptors[field]
		if !ok {
			addError(field, "unknown", fmt.Sprintf("field %q is not advertised by schema %q", field, kind))
			continue
		}
		if !descriptor.Supported {
			addError(field, "unsupported", firstNonEmpty(descriptor.UnsupportedReason, fmt.Sprintf("field %q is not supported", field)))
		}
	}
	for field, action := range draft.SecretActions {
		descriptor, ok := descriptors[field]
		if !ok {
			addError(field, "unknown", fmt.Sprintf("secret action field %q is not advertised by schema %q", field, kind))
			continue
		}
		if !descriptor.Supported || !descriptor.Secret {
			addError(field, "unsupported", fmt.Sprintf("field %q does not support secret update actions", field))
			continue
		}
		if normalizeSecretUpdateAction(action) == "" {
			addError(field, "invalid_action", fmt.Sprintf("unsupported secret update action %q", action))
			continue
		}
		if !transportProfileSecretActionAdvertised(action, descriptor.SecretUpdateActions) {
			addError(field, "invalid_action", fmt.Sprintf("secret update action %q is not advertised for field %q", action, field))
		}
	}
}

func transportProfileStructuredFieldDescriptorMap(
	kind TransportProfileKind,
) map[TransportProfileStructuredFieldID]TransportProfileStructuredFieldDescriptor {
	for _, schema := range defaultTransportProfileEditableKindSchemas() {
		if schema.Kind != kind {
			continue
		}
		out := make(map[TransportProfileStructuredFieldID]TransportProfileStructuredFieldDescriptor, len(schema.Fields))
		for _, field := range schema.Fields {
			out[field.ID] = field
		}
		return out
	}
	return nil
}

func transportProfileSecretActionAdvertised(
	action TransportProfileSecretUpdateAction,
	actions []TransportProfileSecretUpdateAction,
) bool {
	for _, candidate := range actions {
		if candidate == action {
			return true
		}
	}
	return false
}

func secretActionForField(
	draft TransportProfileStructuredDraft,
	field TransportProfileStructuredFieldID,
	legacy TransportProfileSecretUpdateAction,
) TransportProfileSecretUpdateAction {
	if draft.SecretActions == nil {
		return legacy
	}
	if action, ok := draft.SecretActions[field]; ok {
		return action
	}
	return legacy
}

func structuredStringField(
	draft TransportProfileStructuredDraft,
	field TransportProfileStructuredFieldID,
	legacy string,
	addError func(TransportProfileStructuredFieldID, string, string),
) string {
	value, ok := draft.Fields[field]
	if !ok {
		return strings.TrimSpace(legacy)
	}
	switch typed := value.(type) {
	case string:
		return strings.TrimSpace(typed)
	case fmt.Stringer:
		return strings.TrimSpace(typed.String())
	default:
		addError(field, "type", fmt.Sprintf("field %q must be a string", field))
		return ""
	}
}

func structuredStringListField(
	draft TransportProfileStructuredDraft,
	field TransportProfileStructuredFieldID,
	legacy []string,
	addError func(TransportProfileStructuredFieldID, string, string),
) []string {
	value, ok := draft.Fields[field]
	if !ok {
		return trimStringList(legacy)
	}
	switch typed := value.(type) {
	case []string:
		return trimStringList(typed)
	case []any:
		values := make([]string, 0, len(typed))
		for _, item := range typed {
			text, ok := item.(string)
			if !ok {
				addError(field, "type", fmt.Sprintf("field %q must be a string list", field))
				return nil
			}
			values = append(values, text)
		}
		return trimStringList(values)
	case string:
		return trimStringList(strings.Split(typed, ","))
	default:
		addError(field, "type", fmt.Sprintf("field %q must be a string list", field))
		return nil
	}
}

func structuredIntField(
	draft TransportProfileStructuredDraft,
	field TransportProfileStructuredFieldID,
	legacy int,
	addError func(TransportProfileStructuredFieldID, string, string),
) int {
	value, ok := draft.Fields[field]
	if !ok {
		return legacy
	}
	switch typed := value.(type) {
	case int:
		return typed
	case int32:
		return int(typed)
	case int64:
		return int(typed)
	case float64:
		if typed != float64(int(typed)) {
			addError(field, "type", fmt.Sprintf("field %q must be an integer", field))
			return 0
		}
		return int(typed)
	case json.Number:
		number, err := strconv.Atoi(typed.String())
		if err != nil {
			addError(field, "type", fmt.Sprintf("field %q must be an integer", field))
			return 0
		}
		return number
	case string:
		if strings.TrimSpace(typed) == "" {
			return 0
		}
		number, err := strconv.Atoi(strings.TrimSpace(typed))
		if err != nil {
			addError(field, "type", fmt.Sprintf("field %q must be an integer", field))
			return 0
		}
		return number
	default:
		addError(field, "type", fmt.Sprintf("field %q must be an integer", field))
		return 0
	}
}

func normalizeSecretUpdateAction(action TransportProfileSecretUpdateAction) TransportProfileSecretUpdateAction {
	switch TransportProfileSecretUpdateAction(strings.TrimSpace(string(action))) {
	case TransportProfileSecretUpdateActionPreserveExisting:
		return TransportProfileSecretUpdateActionPreserveExisting
	case TransportProfileSecretUpdateActionReplaceSubmitted:
		return TransportProfileSecretUpdateActionReplaceSubmitted
	case TransportProfileSecretUpdateActionGenerateHost:
		return TransportProfileSecretUpdateActionGenerateHost
	default:
		return ""
	}
}

func structuredDraftInvalidError(result TransportProfileStructuredValidationResult) error {
	if len(result.Errors) == 0 {
		return ErrTransportProfileInvalid
	}
	first := result.Errors[0]
	return fmt.Errorf("%w: field %s %s: %s", ErrTransportProfileInvalid, first.Field, first.Violation, first.Message)
}

func trimStringList(values []string) []string {
	out := make([]string, 0, len(values))
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out
}

func validatePrefixes(
	values []string,
	field TransportProfileStructuredFieldID,
	addError func(TransportProfileStructuredFieldID, string, string),
) {
	for _, value := range values {
		if _, err := netip.ParsePrefix(value); err != nil {
			addError(field, "malformed", fmt.Sprintf("%q is not a valid IP prefix", value))
		}
	}
}

func validateAddrs(
	values []string,
	field TransportProfileStructuredFieldID,
	addError func(TransportProfileStructuredFieldID, string, string),
) {
	for _, value := range values {
		if _, err := netip.ParseAddr(value); err != nil {
			addError(field, "malformed", fmt.Sprintf("%q is not a valid IP address", value))
		}
	}
}

func validateWireGuardEndpoint(endpoint string) error {
	host, port, err := net.SplitHostPort(endpoint)
	if err != nil {
		return err
	}
	if strings.TrimSpace(host) == "" {
		return fmt.Errorf("endpoint host is empty")
	}
	portNumber, err := strconv.Atoi(port)
	if err != nil || portNumber <= 0 || portNumber > 65535 {
		return fmt.Errorf("endpoint port is invalid")
	}
	return nil
}

func validateWireGuardBase64Key(value string) error {
	raw, err := base64.StdEncoding.DecodeString(strings.TrimSpace(value))
	if err != nil {
		return fmt.Errorf("key must be base64-encoded")
	}
	if len(raw) != 32 {
		return fmt.Errorf("key must decode to 32 bytes")
	}
	return nil
}

func generateWireGuardKeyPair() (string, string, error) {
	var private [32]byte
	if _, err := rand.Read(private[:]); err != nil {
		return "", "", err
	}
	private[0] &= 248
	private[31] &= 127
	private[31] |= 64
	public, err := curve25519.X25519(private[:], curve25519.Basepoint)
	if err != nil {
		return "", "", err
	}
	return base64.StdEncoding.EncodeToString(private[:]), base64.StdEncoding.EncodeToString(public), nil
}

func wireGuardGeneratedKeyFingerprint(publicKey string) string {
	sum := sha256.Sum256([]byte(strings.TrimSpace(publicKey)))
	return "sha256:" + hex.EncodeToString(sum[:12])
}
