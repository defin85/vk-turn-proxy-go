package clientcontrol

const supportedProviderRolloutContractVersion = "1"

type ProviderRolloutState string

const (
	ProviderRolloutStateShipped        ProviderRolloutState = "shipped"
	ProviderRolloutStatePlanned        ProviderRolloutState = "planned"
	ProviderRolloutStatePendingRollout ProviderRolloutState = "pending_rollout"
)

type ProviderRolloutRequirement string

const (
	ProviderRolloutRequirementProviderContract      ProviderRolloutRequirement = "provider_contract"
	ProviderRolloutRequirementArtifactFamilyActions ProviderRolloutRequirement = "artifact_family_actions"
	ProviderRolloutRequirementHostReadiness         ProviderRolloutRequirement = "host_readiness"
	ProviderRolloutRequirementDesktopShellReadiness ProviderRolloutRequirement = "desktop_shell_readiness"
	ProviderRolloutRequirementMobileShellReadiness  ProviderRolloutRequirement = "mobile_shell_readiness"
	ProviderRolloutRequirementVerificationEvidence  ProviderRolloutRequirement = "verification_evidence"
)

type SupportedProviderRolloutCapability struct {
	Version                string                       `json:"version"`
	CatalogOwner           string                       `json:"catalog_owner"`
	ProviderDescriptorRole string                       `json:"provider_descriptor_role"`
	Providers              []ProviderRolloutDescriptor  `json:"providers,omitempty"`
	PromotionRequirements  []ProviderRolloutRequirement `json:"promotion_requirements,omitempty"`
}

type ProviderRolloutDescriptor struct {
	ProviderID string               `json:"provider_id"`
	State      ProviderRolloutState `json:"state"`
}

func defaultSupportedProviderRolloutCapability() SupportedProviderRolloutCapability {
	return SupportedProviderRolloutCapability{
		Version:                supportedProviderRolloutContractVersion,
		CatalogOwner:           "app_owned_shell_core",
		ProviderDescriptorRole: "runtime_overlay",
		Providers: []ProviderRolloutDescriptor{
			{ProviderID: "vk", State: ProviderRolloutStateShipped},
			{ProviderID: "generic-turn", State: ProviderRolloutStateShipped},
			{ProviderID: "wb-stream", State: ProviderRolloutStatePlanned},
			{ProviderID: "smarthome", State: ProviderRolloutStatePlanned},
		},
		PromotionRequirements: []ProviderRolloutRequirement{
			ProviderRolloutRequirementProviderContract,
			ProviderRolloutRequirementArtifactFamilyActions,
			ProviderRolloutRequirementHostReadiness,
			ProviderRolloutRequirementDesktopShellReadiness,
			ProviderRolloutRequirementMobileShellReadiness,
			ProviderRolloutRequirementVerificationEvidence,
		},
	}
}

func cloneSupportedProviderRolloutCapability(
	capability *SupportedProviderRolloutCapability,
) *SupportedProviderRolloutCapability {
	if capability == nil {
		return nil
	}
	clone := *capability
	clone.Providers = append([]ProviderRolloutDescriptor(nil), capability.Providers...)
	clone.PromotionRequirements = append(
		[]ProviderRolloutRequirement(nil),
		capability.PromotionRequirements...,
	)
	return &clone
}
