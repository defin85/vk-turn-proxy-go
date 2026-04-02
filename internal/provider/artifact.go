package provider

type ProbeArtifact struct {
	Provider         string               `json:"provider"`
	ResolutionMethod string               `json:"resolution_method,omitempty"`
	Input            ProbeArtifactInput   `json:"input"`
	Stages           []ProbeArtifactStage `json:"stages"`
	Outcome          ProbeArtifactOutcome `json:"outcome"`
}

type ProbeArtifactInput struct {
	InviteURLRedacted           string `json:"invite_url_redacted,omitempty"`
	NormalizedJoinTokenRedacted string `json:"normalized_join_token_redacted,omitempty"`
}

type ProbeArtifactStage struct {
	Name       string                     `json:"name"`
	EndpointID string                     `json:"endpoint_id"`
	Request    ProbeArtifactStageRequest  `json:"request"`
	Response   ProbeArtifactStageResponse `json:"response"`
	Outcome    ProbeArtifactStageOutcome  `json:"outcome"`
}

type ProbeArtifactStageRequest struct {
	Method         string   `json:"method"`
	FormKeys       []string `json:"form_keys"`
	RedactedFields []string `json:"redacted_fields"`
}

type ProbeArtifactStageResponse struct {
	StatusCode int            `json:"status_code"`
	Body       map[string]any `json:"body"`
}

type ProbeArtifactStageOutcome struct {
	Kind      string         `json:"kind"`
	Extracted map[string]any `json:"extracted,omitempty"`
	ErrorCode string         `json:"error_code,omitempty"`
}

type ProbeArtifactOutcome struct {
	ResultKind    string                      `json:"result_kind"`
	Resolution    *ProbeArtifactResolution    `json:"resolution,omitempty"`
	ProviderError *ProbeArtifactProviderError `json:"provider_error,omitempty"`
}

type ProbeArtifactResolution struct {
	UsernameRedacted string `json:"username_redacted"`
	PasswordRedacted string `json:"password_redacted"`
	Address          string `json:"address"`
}

type ProbeArtifactProviderError struct {
	Stage string `json:"stage"`
	Code  string `json:"code"`
}

type ArtifactCarrier interface {
	Artifact() *ProbeArtifact
}

type ArtifactError struct {
	Err           error
	ProbeArtifact *ProbeArtifact
}

func (e *ArtifactError) Error() string {
	if e == nil || e.Err == nil {
		return ""
	}

	return e.Err.Error()
}

func (e *ArtifactError) Unwrap() error {
	if e == nil {
		return nil
	}

	return e.Err
}

func (e *ArtifactError) Artifact() *ProbeArtifact {
	if e == nil {
		return nil
	}

	return e.ProbeArtifact
}
