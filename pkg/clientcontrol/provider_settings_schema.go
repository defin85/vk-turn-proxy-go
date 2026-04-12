package clientcontrol

type ProviderSettings map[string]any

type ProviderSettingsSchema struct {
	Type                 string                             `json:"type"`
	Properties           map[string]ProviderSettingProperty `json:"properties,omitempty"`
	Required             []string                           `json:"required,omitempty"`
	AdditionalProperties bool                               `json:"additionalProperties"`
	Order                []string                           `json:"x-vkturn-order,omitempty"`
}

type ProviderSettingType string

const (
	ProviderSettingTypeString  ProviderSettingType = "string"
	ProviderSettingTypeInteger ProviderSettingType = "integer"
	ProviderSettingTypeNumber  ProviderSettingType = "number"
	ProviderSettingTypeBoolean ProviderSettingType = "boolean"
)

type ProviderSettingControl string

const (
	ProviderSettingControlText     ProviderSettingControl = "text"
	ProviderSettingControlTextarea ProviderSettingControl = "textarea"
	ProviderSettingControlSelect   ProviderSettingControl = "select"
	ProviderSettingControlCheckbox ProviderSettingControl = "checkbox"
	ProviderSettingControlPassword ProviderSettingControl = "password"
)

type ProviderSettingPersistence string

const (
	ProviderSettingPersistenceProfile   ProviderSettingPersistence = "profile"
	ProviderSettingPersistenceEphemeral ProviderSettingPersistence = "ephemeral"
)

type ProviderSettingProperty struct {
	Type        ProviderSettingType        `json:"type"`
	Title       string                     `json:"title,omitempty"`
	Description string                     `json:"description,omitempty"`
	Enum        []any                      `json:"enum,omitempty"`
	Default     any                        `json:"default,omitempty"`
	Examples    []any                      `json:"examples,omitempty"`
	WriteOnly   bool                       `json:"writeOnly,omitempty"`
	MinLength   *int                       `json:"minLength,omitempty"`
	MaxLength   *int                       `json:"maxLength,omitempty"`
	Pattern     string                     `json:"pattern,omitempty"`
	Minimum     *float64                   `json:"minimum,omitempty"`
	Maximum     *float64                   `json:"maximum,omitempty"`
	Control     ProviderSettingControl     `json:"x-vkturn-control,omitempty"`
	Persistence ProviderSettingPersistence `json:"x-vkturn-persistence,omitempty"`
}

func cloneProviderSettings(settings ProviderSettings) ProviderSettings {
	if len(settings) == 0 {
		return nil
	}
	out := make(ProviderSettings, len(settings))
	for key, value := range settings {
		out[key] = value
	}
	return out
}

func cloneProviderSettingsSchema(schema *ProviderSettingsSchema) *ProviderSettingsSchema {
	if schema == nil {
		return nil
	}

	clone := &ProviderSettingsSchema{
		Type:                 schema.Type,
		Required:             append([]string(nil), schema.Required...),
		AdditionalProperties: schema.AdditionalProperties,
		Order:                append([]string(nil), schema.Order...),
	}
	if len(schema.Properties) > 0 {
		clone.Properties = make(map[string]ProviderSettingProperty, len(schema.Properties))
		for key, property := range schema.Properties {
			clone.Properties[key] = cloneProviderSettingProperty(property)
		}
	}
	return clone
}

func cloneProviderSettingProperty(property ProviderSettingProperty) ProviderSettingProperty {
	return ProviderSettingProperty{
		Type:        property.Type,
		Title:       property.Title,
		Description: property.Description,
		Enum:        append([]any(nil), property.Enum...),
		Default:     property.Default,
		Examples:    append([]any(nil), property.Examples...),
		WriteOnly:   property.WriteOnly,
		MinLength:   cloneIntPointer(property.MinLength),
		MaxLength:   cloneIntPointer(property.MaxLength),
		Pattern:     property.Pattern,
		Minimum:     cloneFloat64Pointer(property.Minimum),
		Maximum:     cloneFloat64Pointer(property.Maximum),
		Control:     property.Control,
		Persistence: property.Persistence,
	}
}

func cloneIntPointer(value *int) *int {
	if value == nil {
		return nil
	}
	clone := *value
	return &clone
}

func cloneFloat64Pointer(value *float64) *float64 {
	if value == nil {
		return nil
	}
	clone := *value
	return &clone
}
