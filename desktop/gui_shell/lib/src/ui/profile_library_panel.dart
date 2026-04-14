import 'package:flutter/material.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';

class SavedProfilesLibrarySurface extends StatelessWidget {
  const SavedProfilesLibrarySurface({
    super.key,
    required this.profiles,
    required this.selectedProfileId,
    required this.busy,
    required this.onSelectProfile,
    required this.onCreateDraft,
  });

  final List<ProfileRecord> profiles;
  final String? selectedProfileId;
  final bool busy;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onCreateDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey<String>('saved-profile-library-scroll'),
      primary: false,
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _LibrarySectionHeader(
                title: 'Saved profiles',
                subtitle:
                    'Browse saved operator workspaces intentionally, then return to the active editor without leaving the main path permanently split.',
              ),
            ),
            FilledButton.tonal(
              key: const ValueKey<String>('profile-create-draft-button'),
              onPressed: busy ? null : onCreateDraft,
              child: const Text('New draft'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _LibraryHintCard(
          icon: Icons.fact_check_outlined,
          title: 'Return path stays explicit',
          message:
              'Selecting a saved profile updates the active workflow and closes this secondary surface.',
        ),
        const SizedBox(height: 14),
        if (profiles.isEmpty)
          const _EmptyCard(message: 'No saved profiles yet.')
        else
          ...profiles.map(
            (ProfileRecord profile) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProfileCard(
                theme: theme,
                profile: profile,
                selected: selectedProfileId == profile.id,
                onTap: () => onSelectProfile(profile.id),
              ),
            ),
          ),
      ],
    );
  }
}

class ManagedProvidersLibrarySurface extends StatelessWidget {
  const ManagedProvidersLibrarySurface({
    super.key,
    required this.managedProviders,
    required this.selectedManagedProviderId,
    required this.onSelectManagedProvider,
    this.onCreateManagedProvider,
  });

  final List<ManagedProviderRecord> managedProviders;
  final String? selectedManagedProviderId;
  final ValueChanged<String> onSelectManagedProvider;
  final VoidCallback? onCreateManagedProvider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey<String>('managed-provider-library-scroll'),
      primary: false,
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: _LibrarySectionHeader(
                title: 'Managed records',
                subtitle:
                    'Reusable provider-owned values stay available on demand instead of occupying the default first screen.',
              ),
            ),
            if (onCreateManagedProvider != null)
              FilledButton.tonal(
                key: const ValueKey<String>('managed-provider-create-button'),
                onPressed: onCreateManagedProvider,
                child: const Text('New record'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const _LibraryHintCard(
          icon: Icons.tune_outlined,
          title: 'Reusable data stays secondary',
          message:
              'Choose an existing managed record here, or close this surface to continue the active editor unchanged.',
        ),
        const SizedBox(height: 14),
        if (managedProviders.isEmpty)
          const _EmptyCard(
            message:
                'No managed records yet. Create one from the active provider workflow when you need reusable non-secret values.',
          )
        else
          ...managedProviders.map(
            (ManagedProviderRecord provider) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ManagedProviderCard(
                theme: theme,
                provider: provider,
                selected: selectedManagedProviderId == provider.id,
                onTap: () => onSelectManagedProvider(provider.id),
              ),
            ),
          ),
      ],
    );
  }
}

class PresetBootstrapSurface extends StatelessWidget {
  const PresetBootstrapSurface({
    super.key,
    required this.presets,
    required this.providerDescriptors,
    required this.busy,
    required this.onApplyPreset,
  });

  final List<ProviderPreset> presets;
  final List<ProviderDescriptor> providerDescriptors;
  final bool busy;
  final ValueChanged<ProviderPreset> onApplyPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey<String>('preset-bootstrap-scroll'),
      primary: false,
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        const _LibrarySectionHeader(
          title: 'New from preset',
          subtitle:
              'Start from a curated provider seed only when you intentionally ask for it.',
        ),
        const SizedBox(height: 12),
        const _LibraryHintCard(
          icon: Icons.auto_awesome_outlined,
          title: 'Preset bootstrap stays explicit',
          message:
              'Unavailable presets remain visible and honest here, but they no longer occupy the default provider workspace.',
        ),
        const SizedBox(height: 14),
        ...presets.map((ProviderPreset preset) {
          final availability = preset.availabilityFor(providerDescriptors);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PresetCard(
              theme: theme,
              preset: preset,
              availability: availability,
              busy: busy,
              onApply: () => onApplyPreset(preset),
            ),
          );
        }),
      ],
    );
  }
}

class SupportedProviderChooserSurface extends StatelessWidget {
  const SupportedProviderChooserSurface({
    super.key,
    required this.supportedProviders,
    required this.providerDescriptors,
    required this.selectedProviderId,
    required this.busy,
    required this.onSelectProvider,
  });

  final List<SupportedProviderDefinition> supportedProviders;
  final List<ProviderDescriptor> providerDescriptors;
  final String selectedProviderId;
  final bool busy;
  final ValueChanged<String> onSelectProvider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey<String>('provider-family-chooser-scroll'),
      primary: false,
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        const _LibrarySectionHeader(
          title: 'Provider families',
          subtitle:
              'Choose the shipped family deliberately, then return to one managed-record editor instead of browsing a permanent catalog beside it.',
        ),
        const SizedBox(height: 12),
        const _LibraryHintCard(
          icon: Icons.widgets_outlined,
          title: 'App-owned family chooser',
          message:
              'The catalog belongs to the shipped shell. Host descriptors only overlay current availability and field support.',
        ),
        const SizedBox(height: 14),
        if (supportedProviders.isEmpty)
          const _EmptyCard(
            message:
                'This build does not advertise any shipped provider families yet.',
          )
        else
          ...supportedProviders.map((SupportedProviderDefinition provider) {
            final availability = provider.availabilityFor(providerDescriptors);
            final descriptor = availability.descriptor;
            final selected =
                provider.id.trim().toLowerCase() ==
                selectedProviderId.trim().toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SupportedProviderCard(
                theme: theme,
                provider: provider,
                descriptor: descriptor,
                availability: availability,
                selected: selected,
                enabled: !busy,
                onTap: () => onSelectProvider(provider.id),
              ),
            );
          }),
      ],
    );
  }
}

class _LibrarySectionHeader extends StatelessWidget {
  const _LibrarySectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LibraryHintCard extends StatelessWidget {
  const _LibraryHintCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.28,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.theme,
    required this.preset,
    required this.availability,
    required this.busy,
    required this.onApply,
  });

  final ThemeData theme;
  final ProviderPreset preset;
  final ProviderPresetAvailability availability;
  final bool busy;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('preset-card-${preset.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  preset.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusChip(
                label: availability.isAvailable ? 'Available' : 'Unavailable',
                accent: availability.isAvailable,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(preset.description, style: theme.textTheme.bodySmall),
          if (!availability.isAvailable) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              availability.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              key: ValueKey<String>('preset-use-${preset.id}'),
              onPressed: busy || !availability.isAvailable ? null : onApply,
              child: const Text('Use preset'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagedProviderCard extends StatelessWidget {
  const _ManagedProviderCard({
    required this.theme,
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final ThemeData theme;
  final ManagedProviderRecord provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final supportedProvider = supportedProviderDefinitionFor(provider.provider);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey<String>('managed-provider-item-${provider.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      provider.name.isEmpty ? provider.id : provider.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusChip(
                    label: provider.availability.state.label,
                    accent: provider.isAvailable,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                supportedProvider == null
                    ? provider.provider
                    : 'Provider family: ${supportedProvider.title}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (supportedProvider != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  'App-owned managed record',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (provider.availability.message.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  provider.availability.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.theme,
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final ThemeData theme;
  final ProfileRecord profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey<String>('profile-library-item-${profile.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                profile.name.isEmpty ? profile.id : profile.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                profile.spec.provider,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${profile.spec.listenAddress} -> ${profile.spec.peerAddress}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportedProviderCard extends StatelessWidget {
  const _SupportedProviderCard({
    required this.theme,
    required this.provider,
    required this.descriptor,
    required this.availability,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ThemeData theme;
  final SupportedProviderDefinition provider;
  final ProviderDescriptor? descriptor;
  final SupportedProviderAvailability availability;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final managedFieldLabel = switch (descriptor) {
      null => 'No reusable fields yet',
      final ProviderDescriptor descriptor
          when descriptor.providerSettingsSupportError != null =>
        'Schema blocked in this shell',
      final ProviderDescriptor descriptor when descriptor.settingsSchema == null =>
        'No reusable fields yet',
      _ => 'Reusable fields ready',
    };

    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey<String>('supported-provider-card-${provider.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      provider.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusChip(
                    label: availability.isAvailable ? 'Available' : 'Unavailable',
                    accent: availability.isAvailable,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                provider.description,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _MetaChip(label: selected ? 'Selected family' : 'Shipped by app'),
                  _MetaChip(label: managedFieldLabel),
                ],
              ),
              if (availability.message.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  availability.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.accent});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (accent ? theme.colorScheme.primary : theme.colorScheme.error)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: accent ? theme.colorScheme.primary : theme.colorScheme.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
