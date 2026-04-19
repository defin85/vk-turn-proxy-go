package clientcontrol

import "time"

const ContractVersion = "1"

type Capability string

const (
	CapabilityProfiles                 Capability = "profiles"
	CapabilityProviderConfigs          Capability = "provider_configs"
	CapabilitySessions                 Capability = "sessions"
	CapabilityChallenges               Capability = "challenges"
	CapabilityDiagnostics              Capability = "diagnostics"
	CapabilityEventStream              Capability = "event_stream"
	CapabilityDesktopSidecar           Capability = "desktop_sidecar"
	CapabilityMobileHostBridge         Capability = "mobile_host_bridge"
	CapabilityPlatformTunnels          Capability = "platform_tunnels"
	CapabilityProviderRuntimeArtifacts Capability = "provider-runtime-artifacts"
	CapabilityRuntimeExecutionPlanning Capability = "runtime-execution-planning"
)

type TransportMode string

const (
	TransportModeAuto TransportMode = "auto"
	TransportModeTCP  TransportMode = "tcp"
	TransportModeUDP  TransportMode = "udp"
)

type AdapterKind string

const (
	AdapterUDP AdapterKind = "udp"
	AdapterTCP AdapterKind = "tcp"
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

type ResolutionState string

const (
	ResolutionStateStarting          ResolutionState = "starting"
	ResolutionStateChallengeRequired ResolutionState = "challenge_required"
	ResolutionStateResolved          ResolutionState = "resolved"
	ResolutionStateFailed            ResolutionState = "failed"
	ResolutionStateCancelled         ResolutionState = "cancelled"
	ResolutionStateExpired           ResolutionState = "expired"
)

type ChallengeStatus string

const (
	ChallengeStatusPending    ChallengeStatus = "pending"
	ChallengeStatusContinuing ChallengeStatus = "continuing"
	ChallengeStatusCompleted  ChallengeStatus = "completed"
	ChallengeStatusCancelled  ChallengeStatus = "cancelled"
	ChallengeStatusFailed     ChallengeStatus = "failed"
)

type ChallengeCompletionMode string

const (
	ChallengeCompletionModeManualConfirm        ChallengeCompletionMode = "manual_confirm"
	ChallengeCompletionModeAppReturnCallback    ChallengeCompletionMode = "app_return_callback"
	ChallengeCompletionModeOwnedBrowserObserved ChallengeCompletionMode = "owned_browser_observed"
)

type BrowserReturnSignalKind string

const (
	BrowserReturnSignalKindAppLink          BrowserReturnSignalKind = "app_link"
	BrowserReturnSignalKindUniversalLink    BrowserReturnSignalKind = "universal_link"
	BrowserReturnSignalKindForegroundResume BrowserReturnSignalKind = "foreground_resume"
)

type EventType string

const (
	EventSessionStarting     EventType = "session_starting"
	EventSessionReady        EventType = "session_ready"
	EventSessionRetrying     EventType = "session_retrying"
	EventSessionFailed       EventType = "session_failed"
	EventSessionStopped      EventType = "session_stopped"
	EventResolutionStarting  EventType = "resolution_starting"
	EventResolutionResolved  EventType = "resolution_resolved"
	EventResolutionFailed    EventType = "resolution_failed"
	EventResolutionCancelled EventType = "resolution_cancelled"
	EventResolutionExpired   EventType = "resolution_expired"
	EventChallengeRequired   EventType = "challenge_required"
	EventChallengeUpdated    EventType = "challenge_updated"
)

type PlatformTunnelMode string

const (
	PlatformTunnelModeAndroidVPNService     PlatformTunnelMode = "android_vpn_service"
	PlatformTunnelModeAppleNetworkExtension PlatformTunnelMode = "apple_network_extension"
	PlatformTunnelModeWindowsWintun         PlatformTunnelMode = "windows_wintun"
	PlatformTunnelModeLinuxTun              PlatformTunnelMode = "linux_tun"
)

type PlatformTunnelPrerequisite string

const (
	PlatformTunnelPrerequisitePermission          PlatformTunnelPrerequisite = "permission"
	PlatformTunnelPrerequisiteEntitlement         PlatformTunnelPrerequisite = "entitlement"
	PlatformTunnelPrerequisitePrivilegedExtension PlatformTunnelPrerequisite = "privileged_extension"
	PlatformTunnelPrerequisiteDriver              PlatformTunnelPrerequisite = "driver"
	PlatformTunnelPrerequisiteRouteExclusion      PlatformTunnelPrerequisite = "route_exclusion"
	PlatformTunnelPrerequisiteDNSBypass           PlatformTunnelPrerequisite = "dns_bypass"
	PlatformTunnelPrerequisiteAppRoutingPolicy    PlatformTunnelPrerequisite = "app_routing_policy"
	PlatformTunnelPrerequisiteHostImplementation  PlatformTunnelPrerequisite = "host_implementation"
)

type PlatformTunnelStartupStage string

const (
	PlatformTunnelStartupStageCapabilityCheck    PlatformTunnelStartupStage = "capability_check"
	PlatformTunnelStartupStagePermissionAcquire  PlatformTunnelStartupStage = "permission_acquire"
	PlatformTunnelStartupStageEntitlementAcquire PlatformTunnelStartupStage = "entitlement_acquire"
	PlatformTunnelStartupStageDriverCheck        PlatformTunnelStartupStage = "driver_check"
	PlatformTunnelStartupStageRouteValidate      PlatformTunnelStartupStage = "route_validate"
	PlatformTunnelStartupStageHostBringup        PlatformTunnelStartupStage = "host_bringup"
	PlatformTunnelStartupStageRuntimeAttach      PlatformTunnelStartupStage = "runtime_attach"
)

type PlatformTunnelApplicationRoutingPolicy string

const (
	PlatformTunnelApplicationRoutingPolicyAllApps            PlatformTunnelApplicationRoutingPolicy = "all_apps"
	PlatformTunnelApplicationRoutingPolicyAllowedPackages    PlatformTunnelApplicationRoutingPolicy = "allowed_packages"
	PlatformTunnelApplicationRoutingPolicyDisallowedPackages PlatformTunnelApplicationRoutingPolicy = "disallowed_packages"
)

type PlatformTunnelUnderlayRoutePolicy string

const (
	PlatformTunnelUnderlayRoutePolicyStandard                   PlatformTunnelUnderlayRoutePolicy = "standard"
	PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork PlatformTunnelUnderlayRoutePolicy = "preserve_active_local_network"
)

type PlatformTunnelCapability struct {
	Mode                           PlatformTunnelMode                  `json:"mode"`
	Available                      bool                                `json:"available"`
	SatisfiedPrerequisites         []PlatformTunnelPrerequisite        `json:"satisfied_prerequisites,omitempty"`
	SupportedUnderlayRoutePolicies []PlatformTunnelUnderlayRoutePolicy `json:"supported_underlay_route_policies,omitempty"`
	ExecutionPlans                 []RuntimeExecutionPlanDescriptor    `json:"execution_plans,omitempty"`
	MissingPrerequisite            PlatformTunnelPrerequisite          `json:"missing_prerequisite,omitempty"`
	Message                        string                              `json:"message,omitempty"`
}

type HostInfo struct {
	Version         string                     `json:"version,omitempty"`
	ContractVersion string                     `json:"contract_version,omitempty"`
	Build           BuildIdentity              `json:"build"`
	Capabilities    []Capability               `json:"capabilities"`
	PlatformTunnels []PlatformTunnelCapability `json:"platform_tunnels,omitempty"`
}

type BuildIdentity struct {
	Product     string `json:"product"`
	Version     string `json:"version"`
	BuildNumber string `json:"build_number"`
	Revision    string `json:"revision,omitempty"`
	Dirty       bool   `json:"dirty,omitempty"`
	BuiltAt     string `json:"built_at,omitempty"`
	Role        string `json:"role,omitempty"`
	Target      string `json:"target,omitempty"`
}

type NegotiateRequest struct {
	SupportedVersions    []string     `json:"supported_versions,omitempty"`
	RequiredCapabilities []Capability `json:"required_capabilities,omitempty"`
}

type ProfileSpec struct {
	Provider            string           `json:"provider"`
	Link                string           `json:"link"`
	ProviderSettings    ProviderSettings `json:"provider_settings,omitempty"`
	ListenAddr          string           `json:"listen_addr"`
	PeerAddr            string           `json:"peer_addr"`
	Ingress             AdapterKind      `json:"ingress,omitempty"`
	Connections         int              `json:"connections,omitempty"`
	TURNServer          string           `json:"turn_server,omitempty"`
	TURNPort            string           `json:"turn_port,omitempty"`
	BindInterface       string           `json:"bind_interface,omitempty"`
	Mode                TransportMode    `json:"mode,omitempty"`
	UseDTLS             *bool            `json:"use_dtls,omitempty"`
	InteractiveProvider bool             `json:"interactive_provider,omitempty"`
	LogLevel            string           `json:"log_level,omitempty"`
}

type Profile struct {
	ID   string      `json:"id"`
	Name string      `json:"name,omitempty"`
	Spec ProfileSpec `json:"spec"`
}

type ProviderConfigAvailabilityState string

const (
	ProviderConfigAvailabilityAvailable           ProviderConfigAvailabilityState = "available"
	ProviderConfigAvailabilityProviderUnavailable ProviderConfigAvailabilityState = "provider_unavailable"
	ProviderConfigAvailabilitySchemaUnsupported   ProviderConfigAvailabilityState = "schema_unsupported"
	ProviderConfigAvailabilitySettingsInvalid     ProviderConfigAvailabilityState = "settings_invalid"
)

type ProviderConfigAvailability struct {
	State            ProviderConfigAvailabilityState `json:"state"`
	Message          string                          `json:"message,omitempty"`
	MessageLocalized LocalizedTextMap                `json:"message_localized,omitempty"`
	Field            string                          `json:"field,omitempty"`
	Violation        string                          `json:"violation,omitempty"`
}

type ProviderConfig struct {
	ID               string                     `json:"id"`
	Provider         string                     `json:"provider"`
	Name             string                     `json:"name"`
	ProviderSettings ProviderSettings           `json:"provider_settings,omitempty"`
	Availability     ProviderConfigAvailability `json:"availability"`
	CreatedAt        time.Time                  `json:"created_at"`
	UpdatedAt        time.Time                  `json:"updated_at"`
}

type ResolutionInput struct {
	Provider            string            `json:"provider"`
	Kind                ProviderInputKind `json:"kind,omitempty"`
	LinkRedacted        string            `json:"link_redacted,omitempty"`
	InteractiveProvider bool              `json:"interactive_provider,omitempty"`
}

type ResolutionCredentials struct {
	Address          string `json:"address,omitempty"`
	UsernameRedacted string `json:"username_redacted,omitempty"`
	PasswordRedacted string `json:"password_redacted,omitempty"`
}

type ResolutionExportStatus struct {
	Supported    bool       `json:"supported"`
	ExpiresAt    *time.Time `json:"expires_at,omitempty"`
	ExpirySource string     `json:"expiry_source,omitempty"`
}

type Resolution struct {
	ID                string                 `json:"id"`
	Provider          string                 `json:"provider"`
	ResolutionMethod  string                 `json:"resolution_method,omitempty"`
	Input             ResolutionInput        `json:"input"`
	Artifact          *ResolutionArtifact    `json:"artifact,omitempty"`
	State             ResolutionState        `json:"state"`
	Credentials       *ResolutionCredentials `json:"credentials,omitempty"`
	Export            ResolutionExportStatus `json:"export"`
	Failure           *FailureInfo           `json:"failure,omitempty"`
	ActiveChallengeID string                 `json:"active_challenge_id,omitempty"`
	StartedAt         time.Time              `json:"started_at"`
	UpdatedAt         time.Time              `json:"updated_at"`
	ResolvedAt        *time.Time             `json:"resolved_at,omitempty"`
	ExpiredAt         *time.Time             `json:"expired_at,omitempty"`
}

type FailureInfo struct {
	Stage          string `json:"stage,omitempty"`
	Message        string `json:"message,omitempty"`
	NotImplemented bool   `json:"not_implemented,omitempty"`
}

type Session struct {
	ID                 string       `json:"id"`
	ProfileID          string       `json:"profile_id,omitempty"`
	ProfileName        string       `json:"profile_name,omitempty"`
	SourceResolutionID string       `json:"source_resolution_id,omitempty"`
	Profile            ProfileSpec  `json:"profile"`
	State              SessionState `json:"state"`
	Failure            *FailureInfo `json:"failure,omitempty"`
	ActiveChallengeID  string       `json:"active_challenge_id,omitempty"`
	StartedAt          time.Time    `json:"started_at"`
	UpdatedAt          time.Time    `json:"updated_at"`
	StoppedAt          *time.Time   `json:"stopped_at,omitempty"`
}

type Challenge struct {
	ID             string                          `json:"id"`
	SessionID      string                          `json:"session_id"`
	ResolutionID   string                          `json:"resolution_id,omitempty"`
	Provider       string                          `json:"provider"`
	Stage          string                          `json:"stage"`
	Kind           string                          `json:"kind"`
	Prompt         string                          `json:"prompt,omitempty"`
	OpenURL        string                          `json:"open_url,omitempty"`
	Status         ChallengeStatus                 `json:"status"`
	CompletionMode ChallengeCompletionMode         `json:"completion_mode"`
	BrowserReturn  *ChallengeBrowserReturnMetadata `json:"browser_return,omitempty"`
	OwnedBrowser   *ChallengeOwnedBrowserMetadata  `json:"owned_browser,omitempty"`
	CreatedAt      time.Time                       `json:"created_at"`
	UpdatedAt      time.Time                       `json:"updated_at"`
}

type ChallengeBrowserReturnMetadata struct {
	SignalKinds       []BrowserReturnSignalKind `json:"signal_kinds,omitempty"`
	AllowAutoContinue bool                      `json:"allow_auto_continue"`
	ExpectedReturnURI string                    `json:"expected_return_uri,omitempty"`
}

type ChallengeOwnedBrowserMetadata struct {
	CookieURLs []string `json:"cookie_urls,omitempty"`
}

type BrowserCookie struct {
	Name     string    `json:"name"`
	Value    string    `json:"value"`
	Domain   string    `json:"domain,omitempty"`
	Path     string    `json:"path,omitempty"`
	Expires  time.Time `json:"expires,omitempty"`
	Secure   bool      `json:"secure,omitempty"`
	HTTPOnly bool      `json:"http_only,omitempty"`
}

type ObservedBrowserRequest struct {
	Method     string            `json:"method,omitempty"`
	URL        string            `json:"url,omitempty"`
	FormValues map[string]string `json:"form_values,omitempty"`
	StatusCode int               `json:"status_code,omitempty"`
	Body       map[string]any    `json:"body,omitempty"`
}

type ChallengeContinuation struct {
	Cookies          []BrowserCookie          `json:"cookies,omitempty"`
	ObservedRequests []ObservedBrowserRequest `json:"observed_requests,omitempty"`
}

type Event struct {
	ID              string              `json:"id"`
	Timestamp       time.Time           `json:"timestamp"`
	SessionID       string              `json:"session_id"`
	ResolutionID    string              `json:"resolution_id,omitempty"`
	Type            EventType           `json:"type"`
	State           SessionState        `json:"state,omitempty"`
	ResolutionState ResolutionState     `json:"resolution_state,omitempty"`
	Stage           string              `json:"stage,omitempty"`
	Message         string              `json:"message,omitempty"`
	Connections     int                 `json:"connections,omitempty"`
	ReadyWorkers    int                 `json:"ready_workers,omitempty"`
	Restart         int                 `json:"restart,omitempty"`
	Backoff         string              `json:"backoff,omitempty"`
	Challenge       *Challenge          `json:"challenge,omitempty"`
	Artifact        *ResolutionArtifact `json:"artifact,omitempty"`
}

type Diagnostics struct {
	Session         Session        `json:"session"`
	Events          []Event        `json:"events"`
	Challenges      []Challenge    `json:"challenges"`
	Metrics         string         `json:"metrics"`
	GUIBuild        *BuildIdentity `json:"gui_build,omitempty"`
	HostBuild       BuildIdentity  `json:"host_build"`
	ContractVersion string         `json:"contract_version"`
}

type StartSessionRequest struct {
	ProfileID string       `json:"profile_id,omitempty"`
	Spec      *ProfileSpec `json:"spec,omitempty"`
}

type StartResolutionRequest struct {
	Provider            string                 `json:"provider"`
	Input               *ProviderInputEnvelope `json:"input,omitempty"`
	ProviderSettings    ProviderSettings       `json:"provider_settings,omitempty"`
	Link                string                 `json:"-"`
	InteractiveProvider bool                   `json:"-"`
}

type ResolutionExportResult struct {
	ResolutionID string    `json:"resolution_id"`
	Link         string    `json:"link"`
	ExpiresAt    time.Time `json:"expires_at"`
	ExpirySource string    `json:"expiry_source,omitempty"`
}

type RuntimeDefaults struct {
	ListenAddr    string        `json:"listen_addr"`
	PeerAddr      string        `json:"peer_addr"`
	Ingress       AdapterKind   `json:"ingress,omitempty"`
	Connections   int           `json:"connections,omitempty"`
	TURNServer    string        `json:"turn_server,omitempty"`
	TURNPort      string        `json:"turn_port,omitempty"`
	BindInterface string        `json:"bind_interface,omitempty"`
	Mode          TransportMode `json:"mode,omitempty"`
	UseDTLS       *bool         `json:"use_dtls,omitempty"`
	LogLevel      string        `json:"log_level,omitempty"`
}

type MaterializeResolutionRequest struct {
	RuntimeDefaults RuntimeDefaults       `json:"runtime_defaults"`
	ExecutionPlan   *RuntimeExecutionPlan `json:"execution_plan,omitempty"`
}

type PlatformTunnelStartRequest struct {
	ResolutionID             string                                 `json:"resolution_id,omitempty"`
	RuntimeDefaults          *RuntimeDefaults                       `json:"runtime_defaults,omitempty"`
	Mode                     PlatformTunnelMode                     `json:"mode"`
	ExecutionPlan            *RuntimeExecutionPlan                  `json:"execution_plan,omitempty"`
	ApplicationRoutingPolicy PlatformTunnelApplicationRoutingPolicy `json:"application_routing_policy,omitempty"`
	UnderlayRoutePolicy      PlatformTunnelUnderlayRoutePolicy      `json:"underlay_route_policy,omitempty"`
	AllowedPackages          []string                               `json:"allowed_packages,omitempty"`
	DisallowedPackages       []string                               `json:"disallowed_packages,omitempty"`
}

type PlatformTunnelResumeRequest struct {
	StartupAttemptID string `json:"startup_attempt_id"`
}

type PlatformTunnelStopRequest struct {
	Mode PlatformTunnelMode `json:"mode"`
}

type PlatformTunnelStartResult struct {
	Mode                    PlatformTunnelMode                `json:"mode"`
	ExecutionPlan           *RuntimeExecutionPlan             `json:"execution_plan,omitempty"`
	Ready                   bool                              `json:"ready"`
	Stage                   PlatformTunnelStartupStage        `json:"stage,omitempty"`
	MissingPrerequisite     PlatformTunnelPrerequisite        `json:"missing_prerequisite,omitempty"`
	StartupAttemptID        string                            `json:"startup_attempt_id,omitempty"`
	UnderlayRoutePolicy     PlatformTunnelUnderlayRoutePolicy `json:"underlay_route_policy,omitempty"`
	UnderlayRouteExclusions []string                          `json:"underlay_route_exclusions,omitempty"`
	Message                 string                            `json:"message,omitempty"`
}

type PlatformTunnelStopResult struct {
	Mode    PlatformTunnelMode `json:"mode"`
	Stopped bool               `json:"stopped"`
	Message string             `json:"message,omitempty"`
}
