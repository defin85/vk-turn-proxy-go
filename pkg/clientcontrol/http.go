package clientcontrol

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
)

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
				writeError(w, http.StatusBadRequest, "profile_invalid", err)
				return
			}
			writeJSON(w, http.StatusOK, saved)
		default:
			writeMethodNotAllowed(w, r.Method)
		}
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
			session, err := host.StartSession(r.Context(), req)
			if err != nil {
				writeError(w, http.StatusBadRequest, "start_session_failed", err)
				return
			}
			writeJSON(w, http.StatusAccepted, session)
		default:
			writeMethodNotAllowed(w, r.Method)
		}
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
			challenge, err := host.ContinueChallenge(challengeID)
			if err != nil {
				writeNotFound(w, err)
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

type errorResponse struct {
	Code    string `json:"code"`
	Message string `json:"message"`
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
	writeJSON(w, status, errorResponse{Code: code, Message: message})
}

func writeMethodNotAllowed(w http.ResponseWriter, method string) {
	writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", fmt.Errorf("method %s is not supported", method))
}

func writeNotFound(w http.ResponseWriter, err error) {
	writeError(w, http.StatusNotFound, "not_found", err)
}
