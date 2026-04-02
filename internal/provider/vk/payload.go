package vk

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
)

var (
	errMissingTurnUsername   = errors.New("turn_server.username is required")
	errMissingTurnCredential = errors.New("turn_server.credential is required")
	errMissingTurnURL        = errors.New("turn_server.urls[0] is required")
	errInvalidTurnURL        = errors.New("turn_server.urls[0] must be a valid turn or turns URL")
)

func parseAccessToken(payload map[string]any) (string, error) {
	data, err := objectField(payload, "data")
	if err != nil {
		return "", err
	}

	return stringField(data, "access_token")
}

func parseAnonymousToken(payload map[string]any) (string, error) {
	response, err := objectField(payload, "response")
	if err != nil {
		return "", err
	}

	return stringField(response, "token")
}

func parseSessionKey(payload map[string]any) (string, error) {
	return stringField(payload, "session_key")
}

func parseTurnCredentials(payload map[string]any) (string, string, string, error) {
	turnServer, err := objectField(payload, "turn_server")
	if err != nil {
		return "", "", "", err
	}

	username, err := stringField(turnServer, "username")
	if err != nil {
		return "", "", "", errMissingTurnUsername
	}
	password, err := stringField(turnServer, "credential")
	if err != nil {
		return "", "", "", errMissingTurnCredential
	}
	urls, err := stringArrayField(turnServer, "urls")
	if err != nil || len(urls) == 0 {
		return "", "", "", errMissingTurnURL
	}

	address, err := normalizeTurnAddress(urls[0])
	if err != nil {
		return "", "", "", err
	}

	return username, password, address, nil
}

func objectField(payload map[string]any, key string) (map[string]any, error) {
	value, ok := payload[key]
	if !ok {
		return nil, fmt.Errorf("%s is required", key)
	}

	object, ok := value.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("%s must be an object", key)
	}

	return object, nil
}

func stringField(payload map[string]any, key string) (string, error) {
	value, ok := payload[key]
	if !ok {
		return "", fmt.Errorf("%s is required", key)
	}

	text, ok := value.(string)
	if !ok || strings.TrimSpace(text) == "" {
		return "", fmt.Errorf("%s must be a non-empty string", key)
	}

	return text, nil
}

func stringArrayField(payload map[string]any, key string) ([]string, error) {
	value, ok := payload[key]
	if !ok {
		return nil, fmt.Errorf("%s is required", key)
	}

	items, ok := value.([]any)
	if !ok {
		return nil, fmt.Errorf("%s must be an array", key)
	}

	result := make([]string, 0, len(items))
	for _, item := range items {
		text, ok := item.(string)
		if !ok || strings.TrimSpace(text) == "" {
			return nil, fmt.Errorf("%s must contain non-empty strings", key)
		}
		result = append(result, text)
	}

	return result, nil
}

func normalizeTurnAddress(raw string) (string, error) {
	clean := strings.TrimSpace(raw)
	switch {
	case strings.HasPrefix(clean, "turn:"):
		clean = strings.TrimPrefix(clean, "turn:")
	case strings.HasPrefix(clean, "turns:"):
		clean = strings.TrimPrefix(clean, "turns:")
	default:
		return "", errInvalidTurnURL
	}

	if idx := strings.Index(clean, "?"); idx != -1 {
		clean = clean[:idx]
	}
	clean = strings.TrimSpace(clean)
	if clean == "" || !strings.Contains(clean, ":") {
		return "", errInvalidTurnURL
	}

	return clean, nil
}

func newDeviceID() (string, error) {
	var data [16]byte
	if _, err := rand.Read(data[:]); err != nil {
		return "", err
	}

	data[6] = (data[6] & 0x0f) | 0x40
	data[8] = (data[8] & 0x3f) | 0x80

	encoded := hex.EncodeToString(data[:])

	return fmt.Sprintf("%s-%s-%s-%s-%s",
		encoded[0:8],
		encoded[8:12],
		encoded[12:16],
		encoded[16:20],
		encoded[20:32],
	), nil
}
