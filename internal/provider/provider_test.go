package provider

import (
	"context"
	"testing"
)

type fakeAdapter struct {
	name       string
	descriptor ProviderDescriptor
}

func (f fakeAdapter) Name() string { return f.name }

func (f fakeAdapter) Descriptor() ProviderDescriptor {
	if f.descriptor.ID != "" {
		return f.descriptor
	}

	return ProviderDescriptor{
		ID:            f.name,
		DisplayName:   f.name,
		InputKind:     ProviderInputKindLink,
		AuthPosture:   ProviderAuthPostureNotApplicable,
		BrowserPolicy: ProviderBrowserPolicyNotRequired,
		CapabilityHints: ProviderCapabilityHints{
			RedactionPolicy: SummaryOnlyArtifactRedactionPolicy(),
		},
	}
}

func (f fakeAdapter) Resolve(context.Context, string) (Resolution, error) {
	return Resolution{}, nil
}

func TestRegistryReturnsRegisteredAdapter(t *testing.T) {
	registry := NewRegistry(fakeAdapter{name: "vk"})

	adapter, err := registry.Get("vk")
	if err != nil {
		t.Fatalf("expected adapter, got %v", err)
	}
	if adapter.Name() != "vk" {
		t.Fatalf("unexpected adapter %q", adapter.Name())
	}
}

func TestRegistryNamesAreSorted(t *testing.T) {
	registry := NewRegistry(fakeAdapter{name: "zeta"}, fakeAdapter{name: "alpha"})

	names := registry.Names()
	if len(names) != 2 {
		t.Fatalf("expected 2 names, got %d", len(names))
	}
	if names[0] != "alpha" || names[1] != "zeta" {
		t.Fatalf("unexpected names order %v", names)
	}
}

func TestRegistryDescriptorsAreSortedAndCloned(t *testing.T) {
	registry := NewRegistry(
		fakeAdapter{
			name: "zeta",
			descriptor: ProviderDescriptor{
				ID:            "zeta",
				DisplayName:   "Zeta",
				InputKind:     ProviderInputKindLink,
				AuthPosture:   ProviderAuthPostureAccount,
				BrowserPolicy: ProviderBrowserPolicyExternalRequired,
				ChallengeModes: []ProviderChallengeMode{
					ProviderChallengeModeBrowser,
				},
				ArtifactFamilies: []ArtifactFamily{ArtifactFamilyConferenceRoom},
				CapabilityHints: ProviderCapabilityHints{
					PotentialActions: []ArtifactAction{ArtifactActionOpenRoom},
					RedactionPolicy:  SummaryOnlyArtifactRedactionPolicy(),
				},
			},
		},
		fakeAdapter{
			name: "alpha",
			descriptor: ProviderDescriptor{
				ID:               "alpha",
				DisplayName:      "Alpha",
				InputKind:        ProviderInputKindLink,
				AuthPosture:      ProviderAuthPostureGuest,
				BrowserPolicy:    ProviderBrowserPolicyNotRequired,
				ArtifactFamilies: []ArtifactFamily{ArtifactFamilyGenericTURN},
				CapabilityHints: ProviderCapabilityHints{
					PotentialActions: []ArtifactAction{ArtifactActionExportHandoff},
					RedactionPolicy:  SummaryOnlyArtifactRedactionPolicy(),
				},
			},
		},
	)

	descriptors := registry.Descriptors()
	if len(descriptors) != 2 {
		t.Fatalf("expected 2 descriptors, got %d", len(descriptors))
	}
	if descriptors[0].ID != "alpha" || descriptors[1].ID != "zeta" {
		t.Fatalf("unexpected descriptor order %+v", descriptors)
	}

	descriptors[0].ArtifactFamilies[0] = ArtifactFamilyCameraStream

	descriptor, err := registry.Descriptor("alpha")
	if err != nil {
		t.Fatalf("Descriptor(alpha) error = %v", err)
	}
	if len(descriptor.ArtifactFamilies) != 1 || descriptor.ArtifactFamilies[0] != ArtifactFamilyGenericTURN {
		t.Fatalf("registry descriptor mutated unexpectedly: %+v", descriptor)
	}
}
