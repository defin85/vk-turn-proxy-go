package clientcontrol

import (
	"fmt"
	"math"
	"reflect"
	"regexp"
	"sort"
	"strings"
	"unicode/utf8"
)

const (
	providerSettingsViolationRequired    = "required"
	providerSettingsViolationUnknown     = "unknown"
	providerSettingsViolationType        = "type"
	providerSettingsViolationEnum        = "enum"
	providerSettingsViolationPattern     = "pattern"
	providerSettingsViolationMinimum     = "minimum"
	providerSettingsViolationMaximum     = "maximum"
	providerSettingsViolationMinLength   = "min_length"
	providerSettingsViolationMaxLength   = "max_length"
	providerSettingsViolationPersistence = "persistence"
)

type providerSettingsValidationMode int

const (
	providerSettingsModeImmediate providerSettingsValidationMode = iota + 1
	providerSettingsModePersistedProfile
)

type ProviderSettingsValidationError struct {
	Field     string
	Violation string
	Message   string
}

func (e *ProviderSettingsValidationError) Error() string {
	if e == nil {
		return ""
	}
	if strings.TrimSpace(e.Message) != "" {
		return e.Message
	}
	switch {
	case strings.TrimSpace(e.Field) == "" && strings.TrimSpace(e.Violation) != "":
		return fmt.Sprintf("provider_settings failed %s validation", e.Violation)
	case strings.TrimSpace(e.Field) != "" && strings.TrimSpace(e.Violation) != "":
		return fmt.Sprintf("provider_settings.%s failed %s validation", e.Field, e.Violation)
	case strings.TrimSpace(e.Field) != "":
		return fmt.Sprintf("provider_settings.%s is invalid", e.Field)
	default:
		return "provider_settings is invalid"
	}
}

func validateProviderSettingsSchema(schema *ProviderSettingsSchema) error {
	if schema == nil {
		return nil
	}
	if strings.TrimSpace(schema.Type) != "object" {
		return fmt.Errorf("provider settings schema root must be type=object")
	}
	if schema.AdditionalProperties {
		return fmt.Errorf("provider settings schema root must set additionalProperties=false")
	}
	for key, property := range schema.Properties {
		trimmed := strings.TrimSpace(key)
		if trimmed == "" || trimmed != key {
			return fmt.Errorf("provider settings schema declares an invalid property key %q", key)
		}
		if err := validateProviderSettingPropertySchema(key, property); err != nil {
			return err
		}
	}
	for _, key := range schema.Required {
		trimmed := strings.TrimSpace(key)
		if trimmed == "" {
			return fmt.Errorf("provider settings schema required keys must not be empty")
		}
		if _, ok := schema.Properties[trimmed]; !ok {
			return fmt.Errorf("provider settings schema required field %q is not declared in properties", trimmed)
		}
	}
	for _, key := range schema.Order {
		trimmed := strings.TrimSpace(key)
		if trimmed == "" {
			return fmt.Errorf("provider settings schema x-vkturn-order keys must not be empty")
		}
		if _, ok := schema.Properties[trimmed]; !ok {
			return fmt.Errorf("provider settings schema x-vkturn-order references unknown field %q", trimmed)
		}
	}
	return nil
}

func validateProviderSettingPropertySchema(
	key string,
	property ProviderSettingProperty,
) error {
	switch property.Type {
	case ProviderSettingTypeString,
		ProviderSettingTypeInteger,
		ProviderSettingTypeNumber,
		ProviderSettingTypeBoolean:
	default:
		return fmt.Errorf("provider setting %q is missing a supported scalar type", key)
	}
	switch property.Control {
	case ProviderSettingControlText,
		ProviderSettingControlTextarea,
		ProviderSettingControlSelect,
		ProviderSettingControlCheckbox,
		ProviderSettingControlPassword:
	default:
		return fmt.Errorf("provider setting %q is missing x-vkturn-control", key)
	}
	switch property.Persistence {
	case ProviderSettingPersistenceProfile,
		ProviderSettingPersistenceEphemeral:
	default:
		return fmt.Errorf("provider setting %q is missing x-vkturn-persistence", key)
	}
	if property.WriteOnly && property.Persistence != ProviderSettingPersistenceEphemeral {
		return fmt.Errorf("provider setting %q declares unsupported writeOnly %s persistence", key, property.Persistence)
	}
	if property.Control == ProviderSettingControlSelect && len(property.Enum) == 0 {
		return fmt.Errorf("provider setting %q uses select without enum values", key)
	}
	if property.Control == ProviderSettingControlCheckbox && property.Type != ProviderSettingTypeBoolean {
		return fmt.Errorf("provider setting %q uses checkbox but is not boolean", key)
	}
	if (property.MinLength != nil || property.MaxLength != nil || strings.TrimSpace(property.Pattern) != "") &&
		property.Type != ProviderSettingTypeString {
		return fmt.Errorf("provider setting %q uses string validation keywords but is not string", key)
	}
	if property.MinLength != nil && property.MaxLength != nil && *property.MinLength > *property.MaxLength {
		return fmt.Errorf("provider setting %q declares minLength greater than maxLength", key)
	}
	if (property.Minimum != nil || property.Maximum != nil) &&
		property.Type != ProviderSettingTypeInteger &&
		property.Type != ProviderSettingTypeNumber {
		return fmt.Errorf("provider setting %q uses numeric range keywords but is not numeric", key)
	}
	if property.Minimum != nil && property.Maximum != nil && *property.Minimum > *property.Maximum {
		return fmt.Errorf("provider setting %q declares minimum greater than maximum", key)
	}
	if strings.TrimSpace(property.Pattern) != "" {
		if _, err := regexp.Compile(property.Pattern); err != nil {
			return fmt.Errorf("provider setting %q declares invalid pattern: %w", key, err)
		}
	}
	if property.Default != nil {
		if _, err := normalizeProviderSettingScalarValue(key, property.Type, property.Default); err != nil {
			return fmt.Errorf("provider setting %q declares invalid default value: %w", key, err)
		}
	}
	for _, candidate := range property.Enum {
		if _, err := normalizeProviderSettingScalarValue(key, property.Type, candidate); err != nil {
			return fmt.Errorf("provider setting %q declares invalid enum value: %w", key, err)
		}
	}
	for _, candidate := range property.Examples {
		if _, err := normalizeProviderSettingScalarValue(key, property.Type, candidate); err != nil {
			return fmt.Errorf("provider setting %q declares invalid example value: %w", key, err)
		}
	}
	return nil
}

func normalizeProviderSettingsForDescriptor(
	descriptor ProviderDescriptor,
	settings ProviderSettings,
	mode providerSettingsValidationMode,
) (ProviderSettings, error) {
	normalizedInput, err := normalizeProviderSettingsKeys(settings)
	if err != nil {
		return nil, err
	}
	settings = normalizedInput

	schema := descriptor.SettingsSchema
	if schema == nil || len(schema.Properties) == 0 {
		if len(settings) == 0 {
			return nil, nil
		}
		key := firstProviderSettingsKey(settings)
		return nil, providerSettingsValidationError(
			key,
			providerSettingsViolationUnknown,
			"provider does not declare provider settings",
		)
	}

	normalized := make(ProviderSettings, len(settings))
	keys := sortedProviderSettingsKeys(settings)
	for _, key := range keys {
		property, ok := schema.Properties[key]
		if !ok {
			return nil, providerSettingsValidationError(
				key,
				providerSettingsViolationUnknown,
				fmt.Sprintf("provider_settings.%s is not declared by provider %q", key, descriptor.ID),
			)
		}
		if mode == providerSettingsModePersistedProfile {
			if property.WriteOnly || property.Persistence != ProviderSettingPersistenceProfile {
				return nil, providerSettingsValidationError(
					key,
					providerSettingsViolationPersistence,
					fmt.Sprintf("provider_settings.%s is prompt-only and cannot be persisted in saved profiles", key),
				)
			}
		}
		normalizedValue, err := normalizeProviderSettingValue(key, property, settings[key])
		if err != nil {
			return nil, err
		}
		normalized[key] = normalizedValue
	}

	for _, key := range schema.Required {
		property, ok := schema.Properties[key]
		if !ok {
			continue
		}
		if mode == providerSettingsModePersistedProfile &&
			(property.WriteOnly || property.Persistence != ProviderSettingPersistenceProfile) {
			continue
		}
		if _, ok := normalized[key]; ok {
			continue
		}
		return nil, providerSettingsValidationError(
			key,
			providerSettingsViolationRequired,
			fmt.Sprintf("provider_settings.%s is required", key),
		)
	}

	if len(normalized) == 0 {
		return nil, nil
	}
	return normalized, nil
}

func redactProviderSettingsForOrdinaryRead(
	descriptor ProviderDescriptor,
	settings ProviderSettings,
) ProviderSettings {
	if len(settings) == 0 {
		return nil
	}

	schema := descriptor.SettingsSchema
	if schema == nil || len(schema.Properties) == 0 {
		return nil
	}

	redacted := make(ProviderSettings, len(settings))
	for _, key := range sortedProviderSettingsKeys(settings) {
		property, ok := schema.Properties[key]
		if !ok {
			continue
		}
		if property.WriteOnly || property.Persistence != ProviderSettingPersistenceProfile {
			continue
		}
		redacted[key] = settings[key]
	}
	if len(redacted) == 0 {
		return nil
	}
	return redacted
}

func normalizeProviderSettingValue(
	field string,
	property ProviderSettingProperty,
	value any,
) (any, error) {
	normalizedValue, err := normalizeProviderSettingScalarValue(field, property.Type, value)
	if err != nil {
		return nil, err
	}

	if len(property.Enum) > 0 {
		matched := false
		for _, candidate := range property.Enum {
			normalizedCandidate, enumErr := normalizeProviderSettingScalarValue(field, property.Type, candidate)
			if enumErr != nil {
				return nil, fmt.Errorf("provider setting %q declares invalid enum value: %w", field, enumErr)
			}
			if reflect.DeepEqual(normalizedCandidate, normalizedValue) {
				matched = true
				break
			}
		}
		if !matched {
			return nil, providerSettingsValidationError(
				field,
				providerSettingsViolationEnum,
				fmt.Sprintf("provider_settings.%s must match one of the declared enum values", field),
			)
		}
	}

	switch property.Type {
	case ProviderSettingTypeString:
		text := normalizedValue.(string)
		if property.MinLength != nil && utf8.RuneCountInString(text) < *property.MinLength {
			return nil, providerSettingsValidationError(
				field,
				providerSettingsViolationMinLength,
				fmt.Sprintf("provider_settings.%s must be at least %d characters", field, *property.MinLength),
			)
		}
		if property.MaxLength != nil && utf8.RuneCountInString(text) > *property.MaxLength {
			return nil, providerSettingsValidationError(
				field,
				providerSettingsViolationMaxLength,
				fmt.Sprintf("provider_settings.%s must be at most %d characters", field, *property.MaxLength),
			)
		}
		if strings.TrimSpace(property.Pattern) != "" {
			re, err := regexp.Compile(property.Pattern)
			if err != nil {
				return nil, fmt.Errorf("provider setting %q declares invalid pattern: %w", field, err)
			}
			if !re.MatchString(text) {
				return nil, providerSettingsValidationError(
					field,
					providerSettingsViolationPattern,
					fmt.Sprintf("provider_settings.%s does not match the required pattern", field),
				)
			}
		}
	case ProviderSettingTypeInteger:
		number := float64(normalizedValue.(int64))
		if property.Minimum != nil && number < *property.Minimum {
			return nil, providerSettingsValidationError(
				field,
				providerSettingsViolationMinimum,
				fmt.Sprintf("provider_settings.%s must be at least %s", field, formatProviderSettingsNumber(*property.Minimum)),
			)
		}
		if property.Maximum != nil && number > *property.Maximum {
			return nil, providerSettingsValidationError(
				field,
				providerSettingsViolationMaximum,
				fmt.Sprintf("provider_settings.%s must be at most %s", field, formatProviderSettingsNumber(*property.Maximum)),
			)
		}
	case ProviderSettingTypeNumber:
		number := normalizedValue.(float64)
		if property.Minimum != nil && number < *property.Minimum {
			return nil, providerSettingsValidationError(
				field,
				providerSettingsViolationMinimum,
				fmt.Sprintf("provider_settings.%s must be at least %s", field, formatProviderSettingsNumber(*property.Minimum)),
			)
		}
		if property.Maximum != nil && number > *property.Maximum {
			return nil, providerSettingsValidationError(
				field,
				providerSettingsViolationMaximum,
				fmt.Sprintf("provider_settings.%s must be at most %s", field, formatProviderSettingsNumber(*property.Maximum)),
			)
		}
	}

	return normalizedValue, nil
}

func normalizeProviderSettingScalarValue(
	field string,
	valueType ProviderSettingType,
	value any,
) (any, error) {
	switch valueType {
	case ProviderSettingTypeString:
		text, ok := value.(string)
		if !ok {
			return nil, providerSettingsTypeError(field, valueType)
		}
		return text, nil
	case ProviderSettingTypeBoolean:
		boolean, ok := value.(bool)
		if !ok {
			return nil, providerSettingsTypeError(field, valueType)
		}
		return boolean, nil
	case ProviderSettingTypeInteger:
		number, ok := normalizeProviderInteger(value)
		if !ok {
			return nil, providerSettingsTypeError(field, valueType)
		}
		return number, nil
	case ProviderSettingTypeNumber:
		number, ok := normalizeProviderNumber(value)
		if !ok {
			return nil, providerSettingsTypeError(field, valueType)
		}
		return number, nil
	default:
		return nil, fmt.Errorf("provider setting %q declares unsupported type %q", field, valueType)
	}
}

func normalizeProviderInteger(value any) (int64, bool) {
	switch typed := value.(type) {
	case int:
		return int64(typed), true
	case int8:
		return int64(typed), true
	case int16:
		return int64(typed), true
	case int32:
		return int64(typed), true
	case int64:
		return typed, true
	case uint:
		if uint64(typed) > math.MaxInt64 {
			return 0, false
		}
		return int64(typed), true
	case uint8:
		return int64(typed), true
	case uint16:
		return int64(typed), true
	case uint32:
		return int64(typed), true
	case uint64:
		if typed > math.MaxInt64 {
			return 0, false
		}
		return int64(typed), true
	case float32:
		return normalizeProviderInteger(float64(typed))
	case float64:
		if math.IsNaN(typed) || math.IsInf(typed, 0) || math.Trunc(typed) != typed {
			return 0, false
		}
		if typed < math.MinInt64 || typed > math.MaxInt64 {
			return 0, false
		}
		return int64(typed), true
	default:
		return 0, false
	}
}

func normalizeProviderNumber(value any) (float64, bool) {
	switch typed := value.(type) {
	case int:
		return float64(typed), true
	case int8:
		return float64(typed), true
	case int16:
		return float64(typed), true
	case int32:
		return float64(typed), true
	case int64:
		return float64(typed), true
	case uint:
		return float64(typed), true
	case uint8:
		return float64(typed), true
	case uint16:
		return float64(typed), true
	case uint32:
		return float64(typed), true
	case uint64:
		return float64(typed), true
	case float32:
		return float64(typed), true
	case float64:
		if math.IsNaN(typed) || math.IsInf(typed, 0) {
			return 0, false
		}
		return typed, true
	default:
		return 0, false
	}
}

func providerSettingsTypeError(field string, valueType ProviderSettingType) error {
	return providerSettingsValidationError(
		field,
		providerSettingsViolationType,
		fmt.Sprintf("provider_settings.%s must be a %s value", field, valueType),
	)
}

func providerSettingsValidationError(
	field string,
	violation string,
	message string,
) error {
	return &ProviderSettingsValidationError{
		Field:     strings.TrimSpace(field),
		Violation: strings.TrimSpace(violation),
		Message:   strings.TrimSpace(message),
	}
}

func sortedProviderSettingsKeys(settings ProviderSettings) []string {
	keys := make([]string, 0, len(settings))
	for key := range settings {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func firstProviderSettingsKey(settings ProviderSettings) string {
	normalized, err := normalizeProviderSettingsKeys(settings)
	if err != nil {
		return ""
	}
	keys := sortedProviderSettingsKeys(normalized)
	if len(keys) == 0 {
		return ""
	}
	return keys[0]
}

func normalizeProviderSettingsKeys(settings ProviderSettings) (ProviderSettings, error) {
	if len(settings) == 0 {
		return nil, nil
	}

	normalized := make(ProviderSettings, len(settings))
	for key, value := range settings {
		trimmed := strings.TrimSpace(key)
		if trimmed == "" {
			return nil, providerSettingsValidationError(
				"",
				providerSettingsViolationUnknown,
				"provider_settings keys must not be empty",
			)
		}
		if _, exists := normalized[trimmed]; exists {
			return nil, providerSettingsValidationError(
				trimmed,
				providerSettingsViolationUnknown,
				fmt.Sprintf("provider_settings.%s is duplicated", trimmed),
			)
		}
		normalized[trimmed] = value
	}
	return normalized, nil
}

func formatProviderSettingsNumber(value float64) string {
	if math.Trunc(value) == value {
		return fmt.Sprintf("%.0f", value)
	}
	return fmt.Sprintf("%g", value)
}
