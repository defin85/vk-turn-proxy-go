package clientcontrol

import "time"

const ContractVersion = "1"

type Capability string

const (
	CapabilityProfiles         Capability = "profiles"
	CapabilitySessions         Capability = "sessions"
	CapabilityChallenges       Capability = "challenges"
	CapabilityDiagnostics      Capability = "diagnostics"
	CapabilityEventStream      Capability = "event_stream"
	CapabilityDesktopSidecar   Capability = "desktop_sidecar"
	CapabilityMobileHostBridge Capability = "mobile_host_bridge"
)

type TransportMode string

const (
	TransportModeAuto TransportMode = "auto"
	TransportModeTCP  TransportMode = "tcp"
	TransportModeUDP  TransportMode = "udp"
)

type SessionState string

const (
	SessionStateStarting          SessionState = "starting"
	SessionStateChallengeRequired SessionState = "challenge_required"
	SessionStateReady             SessionState = "ready"
	SessionStateRetrying          SessionState = "retrying"
	SessionStateStopping          SessionState = "stopping"
	SessionStateStopped           SessionState = "stopped"
	SessionStateFailed            SessionState = "failed"
)

type ChallengeStatus string

const (
	ChallengeStatusPending    ChallengeStatus = "pending"
	ChallengeStatusContinuing ChallengeStatus = "continuing"
	ChallengeStatusCompleted  ChallengeStatus = "completed"
	ChallengeStatusCancelled  ChallengeStatus = "cancelled"
	ChallengeStatusFailed     ChallengeStatus = "failed"
)

type EventType string

const (
	EventSessionStarting   EventType = "session_starting"
	EventSessionReady      EventType = "session_ready"
	EventSessionRetrying   EventType = "session_retrying"
	EventSessionFailed     EventType = "session_failed"
	EventSessionStopped    EventType = "session_stopped"
	EventChallengeRequired EventType = "challenge_required"
	EventChallengeUpdated  EventType = "challenge_updated"
)

type HostInfo struct {
	Version      string       `json:"version"`
	Capabilities []Capability `json:"capabilities"`
}

type NegotiateRequest struct {
	SupportedVersions    []string     `json:"supported_versions,omitempty"`
	RequiredCapabilities []Capability `json:"required_capabilities,omitempty"`
}

type ProfileSpec struct {
	Provider            string        `json:"provider"`
	Link                string        `json:"link"`
	ListenAddr          string        `json:"listen_addr"`
	PeerAddr            string        `json:"peer_addr"`
	Connections         int           `json:"connections,omitempty"`
	TURNServer          string        `json:"turn_server,omitempty"`
	TURNPort            string        `json:"turn_port,omitempty"`
	BindInterface       string        `json:"bind_interface,omitempty"`
	Mode                TransportMode `json:"mode,omitempty"`
	UseDTLS             *bool         `json:"use_dtls,omitempty"`
	InteractiveProvider bool          `json:"interactive_provider,omitempty"`
	LogLevel            string        `json:"log_level,omitempty"`
}

type Profile struct {
	ID   string      `json:"id"`
	Name string      `json:"name,omitempty"`
	Spec ProfileSpec `json:"spec"`
}

type FailureInfo struct {
	Stage          string `json:"stage,omitempty"`
	Message        string `json:"message,omitempty"`
	NotImplemented bool   `json:"not_implemented,omitempty"`
}

type Session struct {
	ID                string       `json:"id"`
	ProfileID         string       `json:"profile_id,omitempty"`
	ProfileName       string       `json:"profile_name,omitempty"`
	Profile           ProfileSpec  `json:"profile"`
	State             SessionState `json:"state"`
	Failure           *FailureInfo `json:"failure,omitempty"`
	ActiveChallengeID string       `json:"active_challenge_id,omitempty"`
	StartedAt         time.Time    `json:"started_at"`
	UpdatedAt         time.Time    `json:"updated_at"`
	StoppedAt         *time.Time   `json:"stopped_at,omitempty"`
}

type Challenge struct {
	ID        string          `json:"id"`
	SessionID string          `json:"session_id"`
	Provider  string          `json:"provider"`
	Stage     string          `json:"stage"`
	Kind      string          `json:"kind"`
	Prompt    string          `json:"prompt,omitempty"`
	OpenURL   string          `json:"open_url,omitempty"`
	Status    ChallengeStatus `json:"status"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt time.Time       `json:"updated_at"`
}

type Event struct {
	ID           string       `json:"id"`
	Timestamp    time.Time    `json:"timestamp"`
	SessionID    string       `json:"session_id"`
	Type         EventType    `json:"type"`
	State        SessionState `json:"state,omitempty"`
	Stage        string       `json:"stage,omitempty"`
	Message      string       `json:"message,omitempty"`
	Connections  int          `json:"connections,omitempty"`
	ReadyWorkers int          `json:"ready_workers,omitempty"`
	Restart      int          `json:"restart,omitempty"`
	Backoff      string       `json:"backoff,omitempty"`
	Challenge    *Challenge   `json:"challenge,omitempty"`
}

type Diagnostics struct {
	Session    Session     `json:"session"`
	Events     []Event     `json:"events"`
	Challenges []Challenge `json:"challenges"`
	Metrics    string      `json:"metrics"`
}

type StartSessionRequest struct {
	ProfileID string       `json:"profile_id,omitempty"`
	Spec      *ProfileSpec `json:"spec,omitempty"`
}
