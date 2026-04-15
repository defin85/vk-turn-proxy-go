package clientcontrol

import internalprovider "github.com/defin85/vk-turn-proxy-go/internal/provider"

type ProviderInputKind string

const (
	ProviderInputKindLink ProviderInputKind = "link"
)

type ProviderAuthPosture string

const (
	ProviderAuthPostureNotApplicable  ProviderAuthPosture = "not_applicable"
	ProviderAuthPostureGuest          ProviderAuthPosture = "guest"
	ProviderAuthPostureAccount        ProviderAuthPosture = "account"
	ProviderAuthPostureGuestOrAccount ProviderAuthPosture = "guest_or_account"
	ProviderAuthPostureStaticSecret   ProviderAuthPosture = "static_secret"
)

type ProviderBrowserPolicy string

const (
	ProviderBrowserPolicyNotRequired      ProviderBrowserPolicy = "not_required"
	ProviderBrowserPolicyExternalRequired ProviderBrowserPolicy = "external_required"
	ProviderBrowserPolicyEmbeddedAllowed  ProviderBrowserPolicy = "embedded_allowed"
)

type ProviderChallengeMode string

const (
	ProviderChallengeModeBrowser ProviderChallengeMode = "browser"
)

type ArtifactFamily string

const (
	ArtifactFamilyGenericTURN    ArtifactFamily = "generic_turn"
	ArtifactFamilyConferenceRoom ArtifactFamily = "conference_room"
	ArtifactFamilyCameraStream   ArtifactFamily = "camera_stream"
)

type ArtifactAction string

const (
	ArtifactActionStartOnThisDevice ArtifactAction = "start_on_this_device"
	ArtifactActionExportHandoff     ArtifactAction = "export_handoff"
	ArtifactActionOpenRoom          ArtifactAction = "open_room"
	ArtifactActionOpenCamera        ArtifactAction = "open_camera"
	ArtifactActionOpenArchive       ArtifactAction = "open_archive"
)

type ArtifactRedactionMode string

const (
	ArtifactRedactionModeSummaryOnly ArtifactRedactionMode = "summary_only"
)

type ArtifactRedactionPolicy struct {
	OrdinaryReads  ArtifactRedactionMode `json:"ordinary_reads,omitempty"`
	Events         ArtifactRedactionMode `json:"events,omitempty"`
	Diagnostics    ArtifactRedactionMode `json:"diagnostics,omitempty"`
	PersistedState ArtifactRedactionMode `json:"persisted_state,omitempty"`
}

type ProviderCapabilityHints struct {
	PotentialActions []ArtifactAction        `json:"potential_actions,omitempty"`
	RedactionPolicy  ArtifactRedactionPolicy `json:"redaction_policy,omitempty"`
}

type ProviderDescriptor struct {
	ID               string                  `json:"id"`
	DisplayName      string                  `json:"display_name"`
	Description      string                  `json:"description,omitempty"`
	InputKind        ProviderInputKind       `json:"input_kind"`
	AuthPosture      ProviderAuthPosture     `json:"auth_posture"`
	BrowserPolicy    ProviderBrowserPolicy   `json:"browser_policy"`
	SettingsSchema   *ProviderSettingsSchema `json:"provider_settings_schema,omitempty"`
	ChallengeModes   []ProviderChallengeMode `json:"challenge_modes,omitempty"`
	ArtifactFamilies []ArtifactFamily        `json:"artifact_families,omitempty"`
	CapabilityHints  ProviderCapabilityHints `json:"capability_hints,omitempty"`
}

type ProviderInputEnvelope struct {
	Kind ProviderInputKind `json:"kind"`
	Link string            `json:"link,omitempty"`
}

type ResolutionAction struct {
	ID             ArtifactAction                   `json:"id"`
	ExecutionOwner ActionExecutionOwner             `json:"execution_owner"`
	ExecutionPlans []RuntimeExecutionPlanDescriptor `json:"execution_plans,omitempty"`
}

type ConferenceRoomArtifactSummary struct {
	RoomURL string `json:"room_url,omitempty"`
}

type CameraStreamArtifactSummary struct {
	CameraURL  string `json:"camera_url,omitempty"`
	ArchiveURL string `json:"archive_url,omitempty"`
}

type ResolutionArtifactSummary struct {
	GenericTURN    *ResolutionCredentials         `json:"generic_turn,omitempty"`
	ConferenceRoom *ConferenceRoomArtifactSummary `json:"conference_room,omitempty"`
	CameraStream   *CameraStreamArtifactSummary   `json:"camera_stream,omitempty"`
}

type ResolutionArtifact struct {
	Family        ArtifactFamily            `json:"family"`
	AccessMethods []RuntimeAccessMethod     `json:"access_methods,omitempty"`
	Actions       []ResolutionAction        `json:"actions,omitempty"`
	Summary       ResolutionArtifactSummary `json:"summary,omitempty"`
}

type ActionExecutionOwner string

const (
	ActionExecutionOwnerHost          ActionExecutionOwner = "host"
	ActionExecutionOwnerShellLocal    ActionExecutionOwner = "shell_local"
	ActionExecutionOwnerShellExternal ActionExecutionOwner = "shell_external"
)

func providerDescriptorsFromInternal(descriptors []internalprovider.ProviderDescriptor) []ProviderDescriptor {
	out := make([]ProviderDescriptor, 0, len(descriptors))
	for _, descriptor := range descriptors {
		converted, _ := providerDescriptorFromInternal(descriptor)
		out = append(out, converted)
	}
	return out
}

func providerDescriptorFromInternal(descriptor internalprovider.ProviderDescriptor) (ProviderDescriptor, error) {
	settingsSchema, schemaErr := providerSettingsSchemaFromInternal(
		descriptor.SettingsSchema,
	)
	out := ProviderDescriptor{
		ID:             descriptor.ID,
		DisplayName:    descriptor.DisplayName,
		Description:    descriptor.Description,
		InputKind:      ProviderInputKind(descriptor.InputKind),
		AuthPosture:    ProviderAuthPosture(descriptor.AuthPosture),
		BrowserPolicy:  ProviderBrowserPolicy(descriptor.BrowserPolicy),
		SettingsSchema: settingsSchema,
		CapabilityHints: ProviderCapabilityHints{
			RedactionPolicy: ArtifactRedactionPolicy{
				OrdinaryReads:  ArtifactRedactionMode(descriptor.CapabilityHints.RedactionPolicy.OrdinaryReads),
				Events:         ArtifactRedactionMode(descriptor.CapabilityHints.RedactionPolicy.Events),
				Diagnostics:    ArtifactRedactionMode(descriptor.CapabilityHints.RedactionPolicy.Diagnostics),
				PersistedState: ArtifactRedactionMode(descriptor.CapabilityHints.RedactionPolicy.PersistedState),
			},
		},
	}
	if len(descriptor.ChallengeModes) > 0 {
		out.ChallengeModes = make([]ProviderChallengeMode, 0, len(descriptor.ChallengeModes))
		for _, mode := range descriptor.ChallengeModes {
			out.ChallengeModes = append(out.ChallengeModes, ProviderChallengeMode(mode))
		}
	}
	if len(descriptor.ArtifactFamilies) > 0 {
		out.ArtifactFamilies = make([]ArtifactFamily, 0, len(descriptor.ArtifactFamilies))
		for _, family := range descriptor.ArtifactFamilies {
			out.ArtifactFamilies = append(out.ArtifactFamilies, ArtifactFamily(family))
		}
	}
	if len(descriptor.CapabilityHints.PotentialActions) > 0 {
		out.CapabilityHints.PotentialActions = make([]ArtifactAction, 0, len(descriptor.CapabilityHints.PotentialActions))
		for _, action := range descriptor.CapabilityHints.PotentialActions {
			out.CapabilityHints.PotentialActions = append(out.CapabilityHints.PotentialActions, ArtifactAction(action))
		}
	}
	return out, schemaErr
}

func providerSettingsSchemaFromInternal(
	schema *internalprovider.ProviderSettingsSchema,
) (*ProviderSettingsSchema, error) {
	if schema == nil {
		return nil, nil
	}

	out := &ProviderSettingsSchema{
		Type:                 schema.Type,
		Required:             append([]string(nil), schema.Required...),
		AdditionalProperties: schema.AdditionalProperties,
		Order:                append([]string(nil), schema.Order...),
	}
	if len(schema.Properties) > 0 {
		out.Properties = make(map[string]ProviderSettingProperty, len(schema.Properties))
		for key, property := range schema.Properties {
			out.Properties[key] = ProviderSettingProperty{
				Type:        ProviderSettingType(property.Type),
				Title:       property.Title,
				Description: property.Description,
				Enum:        append([]any(nil), property.Enum...),
				Default:     property.Default,
				Examples:    append([]any(nil), property.Examples...),
				WriteOnly:   property.WriteOnly,
				MinLength:   cloneIntPointer(property.MinLength),
				MaxLength:   cloneIntPointer(property.MaxLength),
				Pattern:     property.Pattern,
				Minimum:     cloneFloat64Pointer(property.Minimum),
				Maximum:     cloneFloat64Pointer(property.Maximum),
				Control:     ProviderSettingControl(property.Control),
				Persistence: ProviderSettingPersistence(property.Persistence),
			}
		}
	}
	if err := validateProviderSettingsSchema(out); err != nil {
		return nil, err
	}
	return out, nil
}

func providerMayRequireInteractiveSupport(descriptor ProviderDescriptor) bool {
	return len(descriptor.ChallengeModes) > 0
}

func cloneResolutionArtifact(artifact *ResolutionArtifact) *ResolutionArtifact {
	if artifact == nil {
		return nil
	}

	clone := &ResolutionArtifact{
		Family:        artifact.Family,
		AccessMethods: append([]RuntimeAccessMethod(nil), artifact.AccessMethods...),
		Summary: ResolutionArtifactSummary{
			GenericTURN:    cloneResolutionCredentials(artifact.Summary.GenericTURN),
			ConferenceRoom: cloneConferenceRoomArtifactSummary(artifact.Summary.ConferenceRoom),
			CameraStream:   cloneCameraStreamArtifactSummary(artifact.Summary.CameraStream),
		},
	}
	if len(artifact.Actions) > 0 {
		clone.Actions = make([]ResolutionAction, 0, len(artifact.Actions))
		for _, action := range artifact.Actions {
			copyAction := action
			copyAction.ExecutionPlans = cloneRuntimeExecutionPlanDescriptors(action.ExecutionPlans)
			clone.Actions = append(clone.Actions, copyAction)
		}
	}
	return clone
}

func cloneResolutionCredentials(credentials *ResolutionCredentials) *ResolutionCredentials {
	if credentials == nil {
		return nil
	}
	clone := *credentials
	return &clone
}

func cloneConferenceRoomArtifactSummary(summary *ConferenceRoomArtifactSummary) *ConferenceRoomArtifactSummary {
	if summary == nil {
		return nil
	}
	clone := *summary
	return &clone
}

func cloneCameraStreamArtifactSummary(summary *CameraStreamArtifactSummary) *CameraStreamArtifactSummary {
	if summary == nil {
		return nil
	}
	clone := *summary
	return &clone
}
