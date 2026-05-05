package clientcontrol

const (
	conferenceRoomActionsContractVersion = "1"
	conferenceRoomURLSummaryField        = "summary.conference_room.room_url"
)

type ConferenceRoomActionsCapability struct {
	Version            string                           `json:"version"`
	ArtifactFamily     ArtifactFamily                   `json:"artifact_family"`
	SummaryFields      []string                         `json:"summary_fields,omitempty"`
	Actions            []ConferenceRoomActionDescriptor `json:"actions,omitempty"`
	UnsupportedActions []ArtifactAction                 `json:"unsupported_actions,omitempty"`
	Redaction          RedactionSummary                 `json:"redaction,omitempty"`
}

type ConferenceRoomActionDescriptor struct {
	ID                    ArtifactAction       `json:"id"`
	ExecutionOwner        ActionExecutionOwner `json:"execution_owner"`
	NavigationTargetField string               `json:"navigation_target_field,omitempty"`
}

func defaultConferenceRoomActionsCapability() ConferenceRoomActionsCapability {
	return ConferenceRoomActionsCapability{
		Version:        conferenceRoomActionsContractVersion,
		ArtifactFamily: ArtifactFamilyConferenceRoom,
		SummaryFields: []string{
			conferenceRoomURLSummaryField,
		},
		Actions: []ConferenceRoomActionDescriptor{
			{
				ID:                    ArtifactActionOpenRoom,
				ExecutionOwner:        ActionExecutionOwnerShellExternal,
				NavigationTargetField: conferenceRoomURLSummaryField,
			},
		},
		UnsupportedActions: []ArtifactAction{
			ArtifactActionStartOnThisDevice,
			ArtifactActionExportHandoff,
		},
		Redaction: RedactionSummary{
			OrdinaryReads:  string(ArtifactRedactionModeSummaryOnly),
			Events:         string(ArtifactRedactionModeSummaryOnly),
			Diagnostics:    string(ArtifactRedactionModeSummaryOnly),
			PersistedState: string(ArtifactRedactionModeSummaryOnly),
		},
	}
}

func cloneConferenceRoomActionsCapability(
	capability *ConferenceRoomActionsCapability,
) *ConferenceRoomActionsCapability {
	if capability == nil {
		return nil
	}
	clone := *capability
	clone.SummaryFields = append([]string(nil), capability.SummaryFields...)
	clone.Actions = append([]ConferenceRoomActionDescriptor(nil), capability.Actions...)
	clone.UnsupportedActions = append([]ArtifactAction(nil), capability.UnsupportedActions...)
	return &clone
}
