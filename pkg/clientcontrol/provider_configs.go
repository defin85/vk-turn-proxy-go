package clientcontrol

import (
	"errors"
	"fmt"
	"sort"
	"strings"
)

func (h *Host) UpsertProviderConfig(config ProviderConfig) (ProviderConfig, error) {
	normalized, err := h.normalizeProviderConfig(config, false)
	if err != nil {
		return ProviderConfig{}, err
	}
	return h.storeProviderConfig(normalized), nil
}

func (h *Host) RestoreProviderConfig(config ProviderConfig) (ProviderConfig, error) {
	normalized, err := h.normalizeProviderConfig(config, true)
	if err != nil {
		return ProviderConfig{}, err
	}
	return h.storeProviderConfig(normalized), nil
}

func (h *Host) storeProviderConfig(normalized ProviderConfig) ProviderConfig {
	h.mu.Lock()
	defer h.mu.Unlock()

	now := h.now().UTC()
	if strings.TrimSpace(normalized.ID) == "" {
		normalized.ID = h.newID()
	}

	if existing, ok := h.providerConfigs[normalized.ID]; ok {
		normalized.CreatedAt = existing.CreatedAt
		normalized.UpdatedAt = now
	} else {
		if normalized.CreatedAt.IsZero() {
			normalized.CreatedAt = now
		}
		if normalized.UpdatedAt.IsZero() {
			normalized.UpdatedAt = normalized.CreatedAt
		}
	}

	normalized.ProviderSettings = cloneProviderSettings(normalized.ProviderSettings)
	normalized.Availability = ProviderConfigAvailability{}
	h.providerConfigs[normalized.ID] = normalized
	return h.decorateProviderConfig(normalized)
}

func (h *Host) DeleteProviderConfig(configID string) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, ok := h.providerConfigs[configID]; !ok {
		return ErrProviderConfigNotFound
	}
	delete(h.providerConfigs, configID)
	return nil
}

func (h *Host) ProviderConfig(configID string) (ProviderConfig, error) {
	h.mu.Lock()
	config, ok := h.providerConfigs[configID]
	h.mu.Unlock()
	if !ok {
		return ProviderConfig{}, ErrProviderConfigNotFound
	}
	return h.decorateProviderConfig(config), nil
}

func (h *Host) ProviderConfigs() []ProviderConfig {
	h.mu.Lock()
	out := make([]ProviderConfig, 0, len(h.providerConfigs))
	for _, config := range h.providerConfigs {
		out = append(out, config)
	}
	h.mu.Unlock()

	sort.Slice(out, func(i, j int) bool {
		leftProvider := strings.TrimSpace(strings.ToLower(out[i].Provider))
		rightProvider := strings.TrimSpace(strings.ToLower(out[j].Provider))
		if leftProvider != rightProvider {
			return leftProvider < rightProvider
		}
		leftName := strings.TrimSpace(strings.ToLower(out[i].Name))
		rightName := strings.TrimSpace(strings.ToLower(out[j].Name))
		if leftName != rightName {
			return leftName < rightName
		}
		return out[i].ID < out[j].ID
	})

	for i := range out {
		out[i] = h.decorateProviderConfig(out[i])
	}
	return out
}

func (h *Host) normalizeProviderConfig(config ProviderConfig, allowRestore bool) (ProviderConfig, error) {
	config.ID = strings.TrimSpace(config.ID)
	config.Provider = strings.TrimSpace(config.Provider)
	config.Name = strings.TrimSpace(config.Name)
	config.ProviderSettings = cloneProviderSettings(config.ProviderSettings)

	if config.Provider == "" {
		return ProviderConfig{}, errors.New("provider is required")
	}
	if config.Name == "" {
		return ProviderConfig{}, errors.New("name is required")
	}

	restoreCandidate := allowRestore &&
		config.ID != "" &&
		!config.CreatedAt.IsZero() &&
		!config.UpdatedAt.IsZero()
	descriptor, err := h.providerDescriptor(config.Provider)
	if err != nil {
		if restoreCandidate && config.ID != "" {
			return config, nil
		}
		return ProviderConfig{}, err
	}
	if descriptor.SettingsSchema == nil || len(descriptor.SettingsSchema.Properties) == 0 {
		if restoreCandidate && config.ID != "" {
			return config, nil
		}
		return ProviderConfig{}, fmt.Errorf(
			"provider %q does not declare reusable provider settings",
			config.Provider,
		)
	}

	settings, err := normalizeProviderSettingsForDescriptor(
		descriptor,
		config.ProviderSettings,
		providerSettingsModePersistedProviderConfig,
	)
	if err != nil {
		if restoreCandidate && config.ID != "" {
			return config, nil
		}
		return ProviderConfig{}, err
	}
	config.ProviderSettings = settings
	return config, nil
}

func (h *Host) decorateProviderConfig(config ProviderConfig) ProviderConfig {
	config.Provider = strings.TrimSpace(config.Provider)
	config.Name = strings.TrimSpace(config.Name)
	config.ProviderSettings = cloneProviderSettings(config.ProviderSettings)

	availability, normalizedSettings := h.providerConfigAvailability(config)
	config.Availability = availability
	if availability.State == ProviderConfigAvailabilityAvailable {
		config.ProviderSettings = normalizedSettings
	}
	return config
}

func (h *Host) providerConfigAvailability(
	config ProviderConfig,
) (ProviderConfigAvailability, ProviderSettings) {
	descriptor, err := h.providerDescriptor(config.Provider)
	if err != nil {
		return ProviderConfigAvailability{
			State: ProviderConfigAvailabilityProviderUnavailable,
			Message: fmt.Sprintf(
				"provider %q is not advertised by the current host",
				config.Provider,
			),
		}, cloneProviderSettings(config.ProviderSettings)
	}
	if descriptor.SettingsSchema == nil || len(descriptor.SettingsSchema.Properties) == 0 {
		return ProviderConfigAvailability{
			State: ProviderConfigAvailabilitySchemaUnsupported,
			Message: fmt.Sprintf(
				"provider %q does not currently advertise a supported provider_settings_schema",
				config.Provider,
			),
		}, cloneProviderSettings(config.ProviderSettings)
	}

	normalized, err := normalizeProviderSettingsForDescriptor(
		descriptor,
		config.ProviderSettings,
		providerSettingsModePersistedProviderConfig,
	)
	if err != nil {
		availability := ProviderConfigAvailability{
			State:   ProviderConfigAvailabilitySettingsInvalid,
			Message: err.Error(),
		}
		var settingsErr *ProviderSettingsValidationError
		if errors.As(err, &settingsErr) {
			availability.Field = settingsErr.Field
			availability.Violation = settingsErr.Violation
		}
		return availability, cloneProviderSettings(config.ProviderSettings)
	}
	return ProviderConfigAvailability{
		State: ProviderConfigAvailabilityAvailable,
	}, normalized
}
