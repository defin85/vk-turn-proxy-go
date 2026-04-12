package provider

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
	ChallengeModes   []ProviderChallengeMode `json:"challenge_modes,omitempty"`
	ArtifactFamilies []ArtifactFamily        `json:"artifact_families,omitempty"`
	CapabilityHints  ProviderCapabilityHints `json:"capability_hints,omitempty"`
}

func SummaryOnlyArtifactRedactionPolicy() ArtifactRedactionPolicy {
	return ArtifactRedactionPolicy{
		OrdinaryReads:  ArtifactRedactionModeSummaryOnly,
		Events:         ArtifactRedactionModeSummaryOnly,
		Diagnostics:    ArtifactRedactionModeSummaryOnly,
		PersistedState: ArtifactRedactionModeSummaryOnly,
	}
}

func cloneProviderDescriptor(descriptor ProviderDescriptor) ProviderDescriptor {
	descriptor.ChallengeModes = append([]ProviderChallengeMode(nil), descriptor.ChallengeModes...)
	descriptor.ArtifactFamilies = append([]ArtifactFamily(nil), descriptor.ArtifactFamilies...)
	descriptor.CapabilityHints.PotentialActions = append([]ArtifactAction(nil), descriptor.CapabilityHints.PotentialActions...)

	return descriptor
}
