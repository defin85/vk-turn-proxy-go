package clientcontrol

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
)

type continueChallengeRequest struct {
	BrowserContinuation *ChallengeContinuation `json:"browser_continuation,omitempty"`
}

func Handler(host *Host) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/host", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		writeJSON(w, http.StatusOK, host.Info())
	})
	mux.HandleFunc("/v1/negotiate", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		var req NegotiateRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_json", err)
			return
		}
		info, err := host.Negotiate(req)
		if err != nil {
			var incompatible *IncompatibleHostError
			if errors.As(err, &incompatible) {
				writeError(w, http.StatusConflict, "incompatible_host", err)
				return
			}
			writeError(w, http.StatusInternalServerError, "negotiate_failed", err)
			return
		}
		writeJSON(w, http.StatusOK, info)
	})
	mux.HandleFunc("/v1/providers", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		writeJSON(
			w,
			http.StatusOK,
			localizeProviderDescriptors(host.Providers(), requestedDisplayLocale(r)),
		)
	})
	mux.HandleFunc("/v1/profiles", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			writeJSON(w, http.StatusOK, host.Profiles())
		case http.MethodPost:
			var profile Profile
			if err := json.NewDecoder(r.Body).Decode(&profile); err != nil {
				writeError(w, http.StatusBadRequest, "invalid_json", err)
				return
			}
			saved, err := host.UpsertProfile(profile)
			if err != nil {
				writeError(w, http.StatusBadRequest, errorCodeForBadRequest(err, "profile_invalid"), err)
				return
			}
			writeJSON(w, http.StatusOK, saved)
		default:
			writeMethodNotAllowed(w, r.Method)
		}
	})
	mux.HandleFunc("/v1/transport-profiles", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			profiles, err := host.TransportProfiles()
			if err != nil {
				writeError(w, http.StatusNotFound, "transport_profile_store_unavailable", err)
				return
			}
			writeJSON(w, http.StatusOK, profiles)
		case http.MethodPost:
			var req TransportProfileImportRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				writeError(w, http.StatusBadRequest, "invalid_json", err)
				return
			}
			profile, err := host.ImportTransportProfile(req)
			if err != nil {
				switch {
				case errors.Is(err, ErrTransportProfileStoreUnavailable):
					writeError(w, http.StatusNotFound, "transport_profile_store_unavailable", err)
				default:
					writeError(w, http.StatusBadRequest, "transport_profile_invalid", err)
				}
				return
			}
			writeJSON(w, http.StatusOK, profile)
		default:
			writeMethodNotAllowed(w, r.Method)
		}
	})
	mux.HandleFunc("/v1/transport-profiles:structured", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		var req TransportProfileStructuredCreateRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_json", err)
			return
		}
		profile, err := host.CreateStructuredTransportProfile(req)
		if err != nil {
			writeTransportProfileActionError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, profile)
	})
	mux.HandleFunc("/v1/transport-profiles:validate-draft", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		var req TransportProfileStructuredValidationRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_json", err)
			return
		}
		result, err := host.ValidateStructuredTransportProfileDraft(req)
		if err != nil {
			writeTransportProfileActionError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, result)
	})
	mux.HandleFunc("/v1/transport-profiles:generate-key", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		var req TransportProfileGenerateKeyRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_json", err)
			return
		}
		key, err := host.GenerateTransportProfileKey(req)
		if err != nil {
			writeTransportProfileActionError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, key)
	})
	mux.HandleFunc("/v1/provider-configs", func(w http.ResponseWriter, r *http.Request) {
		requestedLocale := requestedDisplayLocale(r)
		switch r.Method {
		case http.MethodGet:
			writeJSON(
				w,
				http.StatusOK,
				localizeProviderConfigs(host.ProviderConfigs(), requestedLocale),
			)
		case http.MethodPost:
			var config ProviderConfig
			if err := json.NewDecoder(r.Body).Decode(&config); err != nil {
				writeError(w, http.StatusBadRequest, "invalid_json", err)
				return
			}
			saved, err := host.UpsertProviderConfig(config)
			if err != nil {
				writeError(w, http.StatusBadRequest, errorCodeForBadRequest(err, "provider_config_invalid"), err)
				return
			}
			writeJSON(w, http.StatusOK, localizeProviderConfig(saved, requestedLocale))
		default:
			writeMethodNotAllowed(w, r.Method)
		}
	})
	mux.HandleFunc("/v1/provider-configs:restore", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		var config ProviderConfig
		if err := json.NewDecoder(r.Body).Decode(&config); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_json", err)
			return
		}
		saved, err := host.RestoreProviderConfig(config)
		if err != nil {
			writeError(w, http.StatusBadRequest, errorCodeForBadRequest(err, "provider_config_invalid"), err)
			return
		}
		writeJSON(w, http.StatusOK, localizeProviderConfig(saved, requestedDisplayLocale(r)))
	})
	mux.HandleFunc("/v1/provider-transport-compatibility/candidates", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		var req ProviderTransportCompatibilityRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_json", err)
			return
		}
		writeJSON(w, http.StatusOK, host.ProviderTransportCompatibilityCandidates(req))
	})
	mux.HandleFunc("/v1/profiles/", func(w http.ResponseWriter, r *http.Request) {
		profileID := strings.TrimPrefix(r.URL.Path, "/v1/profiles/")
		if profileID == "" {
			http.NotFound(w, r)
			return
		}
		switch r.Method {
		case http.MethodGet:
			profile, err := host.Profile(profileID)
			if err != nil {
				writeNotFound(w, err)
				return
			}
			writeJSON(w, http.StatusOK, profile)
		case http.MethodDelete:
			if err := host.DeleteProfile(profileID); err != nil {
				writeNotFound(w, err)
				return
			}
			w.WriteHeader(http.StatusNoContent)
		default:
			writeMethodNotAllowed(w, r.Method)
		}
	})
	mux.HandleFunc("/v1/transport-profiles/", func(w http.ResponseWriter, r *http.Request) {
		profileID, action, ok := parseTransportProfilePath(r.URL.Path)
		if !ok {
			http.NotFound(w, r)
			return
		}
		if profileID == "" {
			http.NotFound(w, r)
			return
		}
		if action != "" {
			if r.Method != http.MethodPost {
				writeMethodNotAllowed(w, r.Method)
				return
			}
			switch action {
			case "validate":
				profile, err := host.ValidateTransportProfile(profileID)
				if err != nil {
					writeTransportProfileActionError(w, err)
					return
				}
				writeJSON(w, http.StatusOK, profile)
			case "select-for-startup":
				var req TransportProfileSelectForStartupRequest
				if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
					writeError(w, http.StatusBadRequest, "invalid_json", err)
					return
				}
				profile, err := host.SelectTransportProfileForStartup(profileID, req)
				if err != nil {
					writeTransportProfileActionError(w, err)
					return
				}
				writeJSON(w, http.StatusOK, profile)
			case "structured-update":
				var req TransportProfileStructuredUpdateRequest
				if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
					writeError(w, http.StatusBadRequest, "invalid_json", err)
					return
				}
				profile, err := host.UpdateStructuredTransportProfile(profileID, req)
				if err != nil {
					writeTransportProfileActionError(w, err)
					return
				}
				writeJSON(w, http.StatusOK, profile)
			default:
				http.NotFound(w, r)
			}
			return
		}
		switch r.Method {
		case http.MethodDelete:
			if err := host.ForgetTransportProfile(profileID); err != nil {
				writeTransportProfileActionError(w, err)
				return
			}
			w.WriteHeader(http.StatusNoContent)
		default:
			writeMethodNotAllowed(w, r.Method)
		}
	})
	mux.HandleFunc("/v1/provider-configs/", func(w http.ResponseWriter, r *http.Request) {
		requestedLocale := requestedDisplayLocale(r)
		configID := strings.TrimPrefix(r.URL.Path, "/v1/provider-configs/")
		if configID == "" {
			http.NotFound(w, r)
			return
		}
		switch r.Method {
		case http.MethodGet:
			config, err := host.ProviderConfig(configID)
			if err != nil {
				writeNotFound(w, err)
				return
			}
			writeJSON(w, http.StatusOK, localizeProviderConfig(config, requestedLocale))
		case http.MethodDelete:
			if err := host.DeleteProviderConfig(configID); err != nil {
				writeNotFound(w, err)
				return
			}
			w.WriteHeader(http.StatusNoContent)
		default:
			writeMethodNotAllowed(w, r.Method)
		}
	})
	mux.HandleFunc("/v1/resolutions", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			writeJSON(w, http.StatusOK, host.Resolutions())
		case http.MethodPost:
			var req StartResolutionRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				writeError(w, http.StatusBadRequest, "invalid_json", err)
				return
			}
			resolution, err := host.StartResolution(context.WithoutCancel(r.Context()), req)
			if err != nil {
				writeError(w, http.StatusBadRequest, errorCodeForBadRequest(err, "start_resolution_failed"), err)
				return
			}
			writeJSON(w, http.StatusAccepted, resolution)
		default:
			writeMethodNotAllowed(w, r.Method)
		}
	})
	mux.HandleFunc("/v1/sessions", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			writeJSON(w, http.StatusOK, host.Sessions())
		case http.MethodPost:
			var req StartSessionRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				writeError(w, http.StatusBadRequest, "invalid_json", err)
				return
			}
			// Session lifetime must outlive the HTTP request that created it.
			session, err := host.StartSession(context.WithoutCancel(r.Context()), req)
			if err != nil {
				writeError(w, http.StatusBadRequest, errorCodeForBadRequest(err, "start_session_failed"), err)
				return
			}
			writeJSON(w, http.StatusAccepted, session)
		default:
			writeMethodNotAllowed(w, r.Method)
		}
	})
	mux.HandleFunc("/v1/resolutions/", func(w http.ResponseWriter, r *http.Request) {
		path := strings.TrimPrefix(r.URL.Path, "/v1/resolutions/")
		if path == "" {
			http.NotFound(w, r)
			return
		}
		switch {
		case strings.HasSuffix(path, "/cancel"):
			if r.Method != http.MethodPost {
				writeMethodNotAllowed(w, r.Method)
				return
			}
			resolutionID := strings.TrimSuffix(path, "/cancel")
			resolutionID = strings.TrimSuffix(resolutionID, "/")
			resolution, err := host.CancelResolution(resolutionID)
			if err != nil {
				writeNotFound(w, err)
				return
			}
			writeJSON(w, http.StatusOK, resolution)
		case strings.HasSuffix(path, "/export"):
			if r.Method != http.MethodPost {
				writeMethodNotAllowed(w, r.Method)
				return
			}
			resolutionID := strings.TrimSuffix(path, "/export")
			resolutionID = strings.TrimSuffix(resolutionID, "/")
			result, err := host.ExportResolution(resolutionID)
			if err != nil {
				switch {
				case errors.Is(err, ErrResolutionNotFound):
					writeNotFound(w, err)
				case errors.Is(err, errResolutionNotTransportReady), errors.Is(err, errResolutionExpired), errors.Is(err, errResolutionExportUnavailable):
					writeError(w, http.StatusConflict, "resolution_export_unavailable", err)
				default:
					writeError(w, http.StatusInternalServerError, "resolution_export_failed", err)
				}
				return
			}
			writeJSON(w, http.StatusOK, result)
		case strings.HasSuffix(path, "/materialize"):
			if r.Method != http.MethodPost {
				writeMethodNotAllowed(w, r.Method)
				return
			}
			resolutionID := strings.TrimSuffix(path, "/materialize")
			resolutionID = strings.TrimSuffix(resolutionID, "/")
			var req MaterializeResolutionRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				writeError(w, http.StatusBadRequest, "invalid_json", err)
				return
			}
			session, err := host.MaterializeResolutionWithPlan(
				context.WithoutCancel(r.Context()),
				resolutionID,
				req.RuntimeDefaults,
				req.ExecutionPlan,
			)
			if err != nil {
				switch {
				case errors.Is(err, ErrResolutionNotFound):
					writeNotFound(w, err)
				case errors.Is(err, errResolutionNotTransportReady),
					errors.Is(err, errResolutionExpired),
					errors.Is(err, errRuntimeExecutionPlanUnavailable),
					errors.Is(err, errRuntimeExecutionPlanUnsupported),
					errors.Is(err, errRuntimeExecutionPlanSelectionRequired):
					writeError(w, http.StatusConflict, "resolution_materialize_unavailable", err)
				default:
					writeError(w, http.StatusBadRequest, "resolution_materialize_failed", err)
				}
				return
			}
			writeJSON(w, http.StatusAccepted, session)
		default:
			if r.Method != http.MethodGet {
				writeMethodNotAllowed(w, r.Method)
				return
			}
			resolution, err := host.Resolution(strings.TrimSuffix(path, "/"))
			if err != nil {
				writeNotFound(w, err)
				return
			}
			writeJSON(w, http.StatusOK, resolution)
		}
	})
	mux.HandleFunc("/v1/platform-tunnels/start", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		var req PlatformTunnelStartRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_json", err)
			return
		}
		result, err := host.StartPlatformTunnel(context.WithoutCancel(r.Context()), req)
		if err != nil {
			if startResult, ok := platformTunnelStartResultFromError(err); ok {
				writeJSON(w, http.StatusOK, startResult)
				return
			}
			switch {
			case errors.Is(err, ErrPlatformTunnelModeRequired),
				errors.Is(err, ErrPlatformTunnelModeUnknown),
				errors.Is(err, ErrPlatformTunnelAppRoutingPolicyInvalid),
				errors.Is(err, ErrPlatformTunnelUnderlayRoutePolicyInvalid):
				writeError(w, http.StatusBadRequest, "platform_tunnel_invalid", err)
			default:
				writeError(w, http.StatusInternalServerError, "platform_tunnel_start_failed", err)
			}
			return
		}
		writeJSON(w, http.StatusOK, result)
	})
	mux.HandleFunc("/v1/platform-tunnels/resume", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		var req PlatformTunnelResumeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_json", err)
			return
		}
		result, err := host.ResumePlatformTunnel(context.WithoutCancel(r.Context()), req)
		if err != nil {
			if startResult, ok := platformTunnelStartResultFromError(err); ok {
				writeJSON(w, http.StatusOK, startResult)
				return
			}
			switch {
			case errors.Is(err, ErrPlatformTunnelStartupAttemptRequired):
				writeError(w, http.StatusBadRequest, "platform_tunnel_resume_invalid", err)
			case errors.Is(err, ErrPlatformTunnelStartupAttemptNotFound):
				writeError(w, http.StatusNotFound, "platform_tunnel_startup_attempt_not_found", err)
			default:
				writeError(w, http.StatusInternalServerError, "platform_tunnel_resume_failed", err)
			}
			return
		}
		writeJSON(w, http.StatusOK, result)
	})
	mux.HandleFunc("/v1/platform-tunnels/status", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		writeJSON(w, http.StatusOK, host.PlatformTunnelStatuses())
	})
	mux.HandleFunc("/v1/platform-tunnels/stop", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		var req PlatformTunnelStopRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_json", err)
			return
		}
		result, err := host.StopPlatformTunnel(context.WithoutCancel(r.Context()), req)
		if err != nil {
			switch {
			case errors.Is(err, ErrPlatformTunnelModeRequired),
				errors.Is(err, ErrPlatformTunnelModeUnknown):
				writeError(w, http.StatusBadRequest, "platform_tunnel_invalid", err)
			default:
				writeError(w, http.StatusInternalServerError, "platform_tunnel_stop_failed", err)
			}
			return
		}
		writeJSON(w, http.StatusOK, result)
	})
	mux.HandleFunc("/v1/sessions/", func(w http.ResponseWriter, r *http.Request) {
		path := strings.TrimPrefix(r.URL.Path, "/v1/sessions/")
		if path == "" {
			http.NotFound(w, r)
			return
		}
		switch {
		case strings.HasSuffix(path, "/stop"):
			if r.Method != http.MethodPost {
				writeMethodNotAllowed(w, r.Method)
				return
			}
			sessionID := strings.TrimSuffix(path, "/stop")
			sessionID = strings.TrimSuffix(sessionID, "/")
			session, err := host.StopSession(sessionID)
			if err != nil {
				writeNotFound(w, err)
				return
			}
			writeJSON(w, http.StatusOK, session)
		case strings.HasSuffix(path, "/diagnostics"):
			if r.Method != http.MethodGet {
				writeMethodNotAllowed(w, r.Method)
				return
			}
			sessionID := strings.TrimSuffix(path, "/diagnostics")
			sessionID = strings.TrimSuffix(sessionID, "/")
			diagnostics, err := host.ExportDiagnostics(sessionID)
			if err != nil {
				writeNotFound(w, err)
				return
			}
			writeJSON(w, http.StatusOK, diagnostics)
		default:
			if r.Method != http.MethodGet {
				writeMethodNotAllowed(w, r.Method)
				return
			}
			session, err := host.Session(strings.TrimSuffix(path, "/"))
			if err != nil {
				writeNotFound(w, err)
				return
			}
			writeJSON(w, http.StatusOK, session)
		}
	})
	mux.HandleFunc("/v1/challenges/", func(w http.ResponseWriter, r *http.Request) {
		path := strings.TrimPrefix(r.URL.Path, "/v1/challenges/")
		if path == "" {
			http.NotFound(w, r)
			return
		}
		switch {
		case strings.HasSuffix(path, "/continue"):
			if r.Method != http.MethodPost {
				writeMethodNotAllowed(w, r.Method)
				return
			}
			challengeID := strings.TrimSuffix(path, "/continue")
			challengeID = strings.TrimSuffix(challengeID, "/")
			req, err := decodeContinueChallengeRequest(r.Body)
			if err != nil {
				writeError(w, http.StatusBadRequest, "invalid_json", err)
				return
			}
			challenge, err := host.ContinueChallengeWithBrowserContinuation(
				challengeID,
				req.BrowserContinuation,
			)
			if err != nil {
				if errors.Is(err, ErrChallengeNotFound) {
					writeNotFound(w, err)
					return
				}
				writeError(w, http.StatusBadRequest, "challenge_continue_invalid", err)
				return
			}
			writeJSON(w, http.StatusOK, challenge)
		case strings.HasSuffix(path, "/cancel"):
			if r.Method != http.MethodPost {
				writeMethodNotAllowed(w, r.Method)
				return
			}
			challengeID := strings.TrimSuffix(path, "/cancel")
			challengeID = strings.TrimSuffix(challengeID, "/")
			challenge, err := host.CancelChallenge(challengeID)
			if err != nil {
				writeNotFound(w, err)
				return
			}
			writeJSON(w, http.StatusOK, challenge)
		default:
			if r.Method != http.MethodGet {
				writeMethodNotAllowed(w, r.Method)
				return
			}
			challenge, err := host.Challenge(strings.TrimSuffix(path, "/"))
			if err != nil {
				writeNotFound(w, err)
				return
			}
			writeJSON(w, http.StatusOK, challenge)
		}
	})
	mux.HandleFunc("/v1/events", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			writeMethodNotAllowed(w, r.Method)
			return
		}
		ch, cancel := host.Subscribe(64)
		defer cancel()

		w.Header().Set("Content-Type", "application/x-ndjson")
		w.Header().Set("Cache-Control", "no-store")

		flusher, ok := w.(http.Flusher)
		if !ok {
			writeError(w, http.StatusInternalServerError, "streaming_unsupported", fmt.Errorf("response writer does not support flush"))
			return
		}

		w.WriteHeader(http.StatusOK)
		flusher.Flush()

		encoder := json.NewEncoder(w)
		for {
			select {
			case <-r.Context().Done():
				return
			case event, ok := <-ch:
				if !ok {
					return
				}
				if err := encoder.Encode(event); err != nil {
					return
				}
				flusher.Flush()
			}
		}
	})

	return mux
}

func decodeContinueChallengeRequest(
	body io.ReadCloser,
) (continueChallengeRequest, error) {
	if body == nil {
		return continueChallengeRequest{}, nil
	}
	defer body.Close()

	decoder := json.NewDecoder(body)
	var req continueChallengeRequest
	if err := decoder.Decode(&req); err != nil {
		if errors.Is(err, io.EOF) {
			return continueChallengeRequest{}, nil
		}
		return continueChallengeRequest{}, err
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		if err == nil {
			return continueChallengeRequest{}, errors.New("unexpected trailing JSON input")
		}
		return continueChallengeRequest{}, err
	}
	return req, nil
}

func parseTransportProfilePath(path string) (string, string, bool) {
	trimmed := strings.Trim(strings.TrimPrefix(path, "/v1/transport-profiles/"), "/")
	if trimmed == "" {
		return "", "", false
	}
	parts := strings.Split(trimmed, "/")
	switch len(parts) {
	case 1:
		return parts[0], "", true
	case 2:
		return parts[0], parts[1], true
	default:
		return "", "", false
	}
}

func writeTransportProfileActionError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrTransportProfileStoreUnavailable):
		writeError(w, http.StatusNotFound, "transport_profile_store_unavailable", err)
	case errors.Is(err, ErrTransportProfileNotFound):
		writeNotFound(w, err)
	default:
		writeError(w, http.StatusBadRequest, "transport_profile_invalid", err)
	}
}

type errorResponse struct {
	Code                   string                `json:"code"`
	Message                string                `json:"message"`
	Action                 string                `json:"action,omitempty"`
	RequestedExecutionPlan *RuntimeExecutionPlan `json:"requested_execution_plan,omitempty"`
	Field                  string                `json:"field,omitempty"`
	Violation              string                `json:"violation,omitempty"`
	Stage                  string                `json:"stage,omitempty"`
	NotImplemented         bool                  `json:"not_implemented,omitempty"`
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, code string, err error) {
	message := ""
	if err != nil {
		message = err.Error()
	}
	response := errorResponse{Code: code, Message: message}
	var actionErr *ResolutionActionError
	if errors.As(err, &actionErr) {
		response.Action = string(actionErr.Action)
		response.RequestedExecutionPlan = cloneRuntimeExecutionPlan(actionErr.Plan)
	}
	var settingsErr *ProviderSettingsValidationError
	if errors.As(err, &settingsErr) {
		response.Field = settingsErr.Field
		response.Violation = settingsErr.Violation
	}
	if err != nil {
		info := failureInfoFromResolutionError(err)
		response.Stage = info.Stage
		response.NotImplemented = info.NotImplemented
	}
	writeJSON(w, status, response)
}

func writeMethodNotAllowed(w http.ResponseWriter, method string) {
	writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", fmt.Errorf("method %s is not supported", method))
}

func writeNotFound(w http.ResponseWriter, err error) {
	writeError(w, http.StatusNotFound, "not_found", err)
}

func errorCodeForBadRequest(err error, fallback string) string {
	var settingsErr *ProviderSettingsValidationError
	if errors.As(err, &settingsErr) {
		return "provider_settings_invalid"
	}
	return fallback
}
