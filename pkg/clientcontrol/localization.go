package clientcontrol

import (
	"fmt"
	"net/http"
	"slices"
	"strconv"
	"strings"
)

type LocalizedTextMap map[string]string

type acceptLanguagePreference struct {
	tag   string
	q     float64
	order int
}

func cloneLocalizedTextMap(values LocalizedTextMap) LocalizedTextMap {
	if len(values) == 0 {
		return nil
	}
	clone := make(LocalizedTextMap, len(values))
	for key, value := range values {
		normalizedKey := normalizeLocaleTag(key)
		trimmedValue := strings.TrimSpace(value)
		if normalizedKey == "" || trimmedValue == "" {
			continue
		}
		clone[normalizedKey] = trimmedValue
	}
	if len(clone) == 0 {
		return nil
	}
	return clone
}

func requestedDisplayLocale(r *http.Request) string {
	if r == nil {
		return ""
	}
	preferences := parseAcceptLanguage(r.Header.Get("Accept-Language"))
	for _, preference := range preferences {
		switch localeBaseLanguage(preference.tag) {
		case "ru":
			return "ru"
		case "en":
			return "en"
		}
	}
	return ""
}

func parseAcceptLanguage(header string) []acceptLanguagePreference {
	if strings.TrimSpace(header) == "" {
		return nil
	}
	parts := strings.Split(header, ",")
	preferences := make([]acceptLanguagePreference, 0, len(parts))
	for index, part := range parts {
		segment := strings.TrimSpace(part)
		if segment == "" {
			continue
		}
		tag := segment
		quality := 1.0
		if semi := strings.Index(segment, ";"); semi >= 0 {
			tag = strings.TrimSpace(segment[:semi])
			for _, attr := range strings.Split(segment[semi+1:], ";") {
				key, value, ok := strings.Cut(strings.TrimSpace(attr), "=")
				if !ok || !strings.EqualFold(strings.TrimSpace(key), "q") {
					continue
				}
				parsedQuality, err := strconv.ParseFloat(strings.TrimSpace(value), 64)
				if err != nil {
					quality = 0
					break
				}
				quality = parsedQuality
			}
		}
		normalizedTag := normalizeLocaleTag(tag)
		if normalizedTag == "" || normalizedTag == "*" || quality <= 0 {
			continue
		}
		preferences = append(preferences, acceptLanguagePreference{
			tag:   normalizedTag,
			q:     quality,
			order: index,
		})
	}
	slices.SortStableFunc(preferences, func(left, right acceptLanguagePreference) int {
		switch {
		case left.q > right.q:
			return -1
		case left.q < right.q:
			return 1
		case left.order < right.order:
			return -1
		case left.order > right.order:
			return 1
		default:
			return 0
		}
	})
	return preferences
}

func normalizeLocaleTag(raw string) string {
	normalized := strings.TrimSpace(strings.ReplaceAll(raw, "_", "-"))
	if normalized == "" {
		return ""
	}
	return strings.ToLower(normalized)
}

func localeBaseLanguage(tag string) string {
	normalized := normalizeLocaleTag(tag)
	if normalized == "" {
		return ""
	}
	if language, _, ok := strings.Cut(normalized, "-"); ok {
		return language
	}
	return normalized
}

func localizedTextForLocale(
	locale string,
	translations map[string]string,
) LocalizedTextMap {
	normalizedLocale := normalizeLocaleTag(locale)
	if normalizedLocale == "" || len(translations) == 0 {
		return nil
	}
	if text, ok := translations[normalizedLocale]; ok && strings.TrimSpace(text) != "" {
		return LocalizedTextMap{normalizedLocale: strings.TrimSpace(text)}
	}
	baseLanguage := localeBaseLanguage(normalizedLocale)
	if baseLanguage == "" {
		return nil
	}
	if text, ok := translations[baseLanguage]; ok && strings.TrimSpace(text) != "" {
		return LocalizedTextMap{baseLanguage: strings.TrimSpace(text)}
	}
	return nil
}

func localizeProviderDescriptors(
	descriptors []ProviderDescriptor,
	locale string,
) []ProviderDescriptor {
	if len(descriptors) == 0 {
		return nil
	}
	out := make([]ProviderDescriptor, 0, len(descriptors))
	for _, descriptor := range descriptors {
		out = append(out, localizeProviderDescriptor(descriptor, locale))
	}
	return out
}

func localizeProviderDescriptor(
	descriptor ProviderDescriptor,
	locale string,
) ProviderDescriptor {
	descriptor.DisplayNameLocalized = localizedTextForLocale(
		locale,
		providerDisplayNameTranslations(descriptor.ID),
	)
	descriptor.DescriptionLocalized = localizedTextForLocale(
		locale,
		providerDescriptionTranslations(descriptor.ID),
	)
	if descriptor.SettingsSchema == nil || len(descriptor.SettingsSchema.Properties) == 0 {
		return descriptor
	}

	descriptor.SettingsSchema = cloneProviderSettingsSchema(descriptor.SettingsSchema)
	for key, property := range descriptor.SettingsSchema.Properties {
		property.TitleLocalized = localizedTextForLocale(
			locale,
			providerSettingTitleTranslations(descriptor.ID, key),
		)
		property.DescriptionLocalized = localizedTextForLocale(
			locale,
			providerSettingDescriptionTranslations(descriptor.ID, key),
		)
		descriptor.SettingsSchema.Properties[key] = property
	}
	return descriptor
}

func localizeProviderConfigs(
	configs []ProviderConfig,
	locale string,
) []ProviderConfig {
	if len(configs) == 0 {
		return nil
	}
	out := make([]ProviderConfig, 0, len(configs))
	for _, config := range configs {
		out = append(out, localizeProviderConfig(config, locale))
	}
	return out
}

func localizeProviderConfig(config ProviderConfig, locale string) ProviderConfig {
	config.Availability = localizeProviderConfigAvailability(
		config.Provider,
		config.Availability,
		locale,
	)
	return config
}

func localizeProviderConfigAvailability(
	providerID string,
	availability ProviderConfigAvailability,
	locale string,
) ProviderConfigAvailability {
	availability.MessageLocalized = nil
	if strings.TrimSpace(availability.Message) == "" {
		return availability
	}

	message := localizedAvailabilityMessage(providerID, availability, locale)
	if strings.TrimSpace(message) == "" {
		return availability
	}

	availability.MessageLocalized = localizedTextForLocale(locale, map[string]string{
		normalizeLocaleTag(locale): message,
	})
	return availability
}

func localizedAvailabilityMessage(
	providerID string,
	availability ProviderConfigAvailability,
	locale string,
) string {
	if localeBaseLanguage(locale) != "ru" {
		return ""
	}

	providerLabel := strings.TrimSpace(providerID)
	if providerLabel == "" {
		providerLabel = "провайдер"
	}

	switch availability.State {
	case ProviderConfigAvailabilityProviderUnavailable:
		return fmt.Sprintf(
			"Провайдер %q не объявлен текущим хостом.",
			providerLabel,
		)
	case ProviderConfigAvailabilitySchemaUnsupported:
		return fmt.Sprintf(
			"Провайдер %q сейчас не объявляет поддерживаемую схему provider_settings.",
			providerLabel,
		)
	case ProviderConfigAvailabilitySettingsInvalid:
		field := strings.TrimSpace(availability.Field)
		switch strings.TrimSpace(availability.Violation) {
		case providerSettingsViolationRequired:
			return fmt.Sprintf("Поле provider_settings.%s обязательно.", field)
		case providerSettingsViolationUnknown:
			return fmt.Sprintf("Поле provider_settings.%s не объявлено провайдером.", field)
		case providerSettingsViolationType:
			return fmt.Sprintf("Поле provider_settings.%s имеет неверный тип.", field)
		case providerSettingsViolationEnum:
			return fmt.Sprintf("Поле provider_settings.%s должно совпадать с одним из допустимых значений.", field)
		case providerSettingsViolationPattern:
			return fmt.Sprintf("Поле provider_settings.%s не соответствует требуемому формату.", field)
		case providerSettingsViolationMinimum:
			return fmt.Sprintf("Значение provider_settings.%s ниже допустимого минимума.", field)
		case providerSettingsViolationMaximum:
			return fmt.Sprintf("Значение provider_settings.%s выше допустимого максимума.", field)
		case providerSettingsViolationMinLength:
			return fmt.Sprintf("Значение provider_settings.%s слишком короткое.", field)
		case providerSettingsViolationMaxLength:
			return fmt.Sprintf("Значение provider_settings.%s слишком длинное.", field)
		case providerSettingsViolationPersistence:
			return fmt.Sprintf(
				"Поле provider_settings.%s нельзя сохранять в повторно используемой конфигурации провайдера.",
				field,
			)
		default:
			if field != "" {
				return fmt.Sprintf(
					"Поле provider_settings.%s не прошло проверку %s.",
					field,
					strings.TrimSpace(availability.Violation),
				)
			}
		}
	}
	return ""
}

func providerDisplayNameTranslations(providerID string) map[string]string {
	switch strings.TrimSpace(strings.ToLower(providerID)) {
	case "vk":
		return map[string]string{"ru": "Звонки VK"}
	default:
		return nil
	}
}

func providerDescriptionTranslations(providerID string) map[string]string {
	switch strings.TrimSpace(strings.ToLower(providerID)) {
	case "vk":
		return map[string]string{
			"ru": "Провайдер со сценарием «сначала инвайт, потом браузер», который завершает разрешение и возвращает готовые для транспорта TURN-учетные данные.",
		}
	case "generic-turn":
		return map[string]string{
			"ru": "Статическая передача TURN-параметров для детерминированного тестирования транспорта и запуска рантайма под управлением оператора.",
		}
	default:
		return nil
	}
}

func providerSettingTitleTranslations(
	providerID string,
	fieldKey string,
) map[string]string {
	_ = providerID
	switch strings.TrimSpace(strings.ToLower(fieldKey)) {
	case "region":
		return map[string]string{"ru": "Регион"}
	case "device_index":
		return map[string]string{"ru": "Индекс устройства"}
	case "device_pin":
		return map[string]string{"ru": "PIN устройства"}
	case "device_alias":
		return map[string]string{"ru": "Алиас устройства"}
	default:
		return nil
	}
}

func providerSettingDescriptionTranslations(
	providerID string,
	fieldKey string,
) map[string]string {
	_ = providerID
	switch strings.TrimSpace(strings.ToLower(fieldKey)) {
	case "region":
		return map[string]string{"ru": "Выберите регион, который должен использовать провайдер."}
	case "device_index":
		return map[string]string{"ru": "Укажите индекс устройства, которое хост должен использовать для этого профиля."}
	case "device_pin":
		return map[string]string{"ru": "Введите PIN устройства только для текущего запроса."}
	case "device_alias":
		return map[string]string{"ru": "Укажите операторское имя устройства для этого провайдера."}
	default:
		return nil
	}
}
