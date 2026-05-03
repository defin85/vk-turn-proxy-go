package vpscatalog

import "time"

func CloneSnapshot(snapshot CatalogSnapshot) CatalogSnapshot {
	clone := snapshot
	clone.Sources = make([]ProviderSource, 0, len(snapshot.Sources))
	for _, source := range snapshot.Sources {
		clone.Sources = append(clone.Sources, CloneSource(source))
	}
	return clone
}

func CloneSource(source ProviderSource) ProviderSource {
	clone := source
	clone.Health = cloneHealth(source.Health)
	clone.Evidence = cloneEvidence(source.Evidence)
	clone.ArtifactOffers = make([]ArtifactOffer, 0, len(source.ArtifactOffers))
	for _, offer := range source.ArtifactOffers {
		clone.ArtifactOffers = append(clone.ArtifactOffers, CloneOffer(offer))
	}
	clone.Metadata = cloneStringMap(source.Metadata)
	return clone
}

func CloneOffer(offer ArtifactOffer) ArtifactOffer {
	clone := offer
	clone.AccessMethods = append([]string(nil), offer.AccessMethods...)
	clone.Actions = append([]string(nil), offer.Actions...)
	clone.CompatibleProfileKinds = append([]string(nil), offer.CompatibleProfileKinds...)
	clone.Health = cloneHealth(offer.Health)
	clone.Evidence = cloneEvidence(offer.Evidence)
	clone.Metadata = cloneStringMap(offer.Metadata)
	return clone
}

func CloneIssueResponse(response ArtifactIssueResponse) ArtifactIssueResponse {
	clone := response
	clone.Artifact.AccessMethods = append([]string(nil), response.Artifact.AccessMethods...)
	clone.Artifact.Actions = append([]string(nil), response.Artifact.Actions...)
	clone.Artifact.CompatibleProfileKinds = append([]string(nil), response.Artifact.CompatibleProfileKinds...)
	clone.Artifact.Health = cloneHealth(response.Artifact.Health)
	clone.Artifact.Evidence = cloneEvidence(response.Artifact.Evidence)
	if response.Export != nil {
		export := *response.Export
		clone.Export = &export
	}
	return clone
}

func cloneHealth(health Health) Health {
	clone := health
	clone.CheckedAt = cloneTimePointer(health.CheckedAt)
	clone.ExpiresAt = cloneTimePointer(health.ExpiresAt)
	return clone
}

func cloneEvidence(evidence []Evidence) []Evidence {
	if len(evidence) == 0 {
		return nil
	}
	out := make([]Evidence, 0, len(evidence))
	for _, item := range evidence {
		clone := item
		clone.ObservedAt = cloneTimePointer(item.ObservedAt)
		clone.ExpiresAt = cloneTimePointer(item.ExpiresAt)
		out = append(out, clone)
	}
	return out
}

func cloneStringMap(values map[string]string) map[string]string {
	if len(values) == 0 {
		return nil
	}
	out := make(map[string]string, len(values))
	for key, value := range values {
		out[key] = value
	}
	return out
}

func cloneTimePointer(value *time.Time) *time.Time {
	if value == nil {
		return nil
	}
	clone := value.UTC()
	return &clone
}
