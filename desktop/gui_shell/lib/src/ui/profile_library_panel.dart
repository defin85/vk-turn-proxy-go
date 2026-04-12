import 'package:flutter/material.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';

class ProfileLibraryPanel extends StatelessWidget {
  const ProfileLibraryPanel({
    super.key,
    required this.presets,
    required this.providerDescriptors,
    required this.providerConfigs,
    required this.profiles,
    required this.selectedProfileId,
    required this.selectedProviderConfigId,
    required this.activeSurface,
    required this.busy,
    required this.onApplyPreset,
    required this.onSelectProviderConfig,
    required this.onCreateProviderConfig,
    required this.onSelectProfile,
    required this.onCreateDraft,
  });

  final List<ProviderPreset> presets;
  final List<ProviderDescriptor> providerDescriptors;
  final List<ProviderConfigRecord> providerConfigs;
  final List<ProfileRecord> profiles;
  final String? selectedProfileId;
  final String? selectedProviderConfigId;
  final DesktopWorkspaceSurface activeSurface;
  final bool busy;
  final ValueChanged<ProviderPreset> onApplyPreset;
  final ValueChanged<String> onSelectProviderConfig;
  final VoidCallback onCreateProviderConfig;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onCreateDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Libraries',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Presets, reusable provider configs, and saved profiles stay distinct so the active workspace can focus on one operator task at a time.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _activeWorkspaceCard(theme),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                key: const ValueKey<String>('workflow-library-scroll'),
                children: <Widget>[
                  _sectionHeader(
                    theme,
                    title: 'Presets',
                    subtitle:
                        'Curated bootstrap cards for the main provider families.',
                  ),
                  const SizedBox(height: 10),
                  ...presets.map((ProviderPreset preset) {
                    final availability = preset.availabilityFor(
                      providerDescriptors,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _presetCard(theme, preset, availability),
                    );
                  }),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _sectionHeader(
                          theme,
                          title: 'Provider configs',
                          subtitle:
                              'Reusable non-secret provider settings keyed to one provider.',
                        ),
                      ),
                      FilledButton.tonal(
                        key: const ValueKey<String>(
                          'provider-config-create-button',
                        ),
                        onPressed: busy ? null : onCreateProviderConfig,
                        child: const Text('New'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (providerConfigs.isEmpty)
                    _emptyCard(
                      theme,
                      'No provider configs yet. Create them when the connected host advertises descriptor-driven provider settings.',
                    )
                  else
                    ...providerConfigs.map(
                      (ProviderConfigRecord config) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _providerConfigCard(theme, config),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _sectionHeader(
                          theme,
                          title: 'Saved profiles',
                          subtitle:
                              'Runtime snapshots that can resolve or start from the active workspace.',
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: busy ? null : onCreateDraft,
                        child: const Text('New draft'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (profiles.isEmpty)
                    _emptyCard(theme, 'No saved profiles yet.')
                  else
                    ...profiles.map(
                      (ProfileRecord profile) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _profileCard(theme, profile),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    ThemeData theme, {
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
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

  Widget _activeWorkspaceCard(ThemeData theme) {
    final isProfile = activeSurface == DesktopWorkspaceSurface.profile;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            (isProfile ? theme.colorScheme.primary : theme.colorScheme.tertiary)
                .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isProfile ? Icons.edit_note_outlined : Icons.tune_outlined,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isProfile
                      ? 'Profile workspace active'
                      : 'Provider config workspace active',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isProfile
                      ? 'Resolve, start, and save runtime snapshots from the active draft.'
                      : 'Edit reusable provider-only settings separately from runtime defaults.',
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

  Widget _presetCard(
    ThemeData theme,
    ProviderPreset preset,
    ProviderPresetAvailability availability,
  ) {
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
              _statusChip(
                theme,
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
              onPressed: busy || !availability.isAvailable
                  ? null
                  : () => onApplyPreset(preset),
              child: const Text('Use preset'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerConfigCard(ThemeData theme, ProviderConfigRecord config) {
    final selected =
        activeSurface == DesktopWorkspaceSurface.providerConfig &&
        selectedProviderConfigId == config.id;
    final accent = config.isAvailable;
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey<String>('provider-config-item-${config.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => onSelectProviderConfig(config.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      config.name.isEmpty ? config.id : config.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _statusChip(
                    theme,
                    label: config.availability.state.label,
                    accent: accent,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                config.provider,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (config.availability.message.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  config.availability.message,
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

  Widget _profileCard(ThemeData theme, ProfileRecord profile) {
    final selected =
        activeSurface == DesktopWorkspaceSurface.profile &&
        selectedProfileId == profile.id;
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey<String>('profile-library-item-${profile.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => onSelectProfile(profile.id),
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

  Widget _emptyCard(ThemeData theme, String message) {
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

  Widget _statusChip(
    ThemeData theme, {
    required String label,
    required bool accent,
  }) {
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
