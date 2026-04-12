package provider

import "context"

type providerSettingsContextKey struct{}

func WithSettings(ctx context.Context, settings ProviderSettings) context.Context {
	if ctx == nil {
		ctx = context.Background()
	}
	if len(settings) == 0 {
		return ctx
	}
	return context.WithValue(ctx, providerSettingsContextKey{}, cloneProviderSettings(settings))
}

func SettingsFromContext(ctx context.Context) ProviderSettings {
	if ctx == nil {
		return nil
	}
	settings, _ := ctx.Value(providerSettingsContextKey{}).(ProviderSettings)
	return cloneProviderSettings(settings)
}
