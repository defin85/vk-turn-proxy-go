import 'package:flutter/material.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';

class DesktopWorkflowPane extends StatelessWidget {
  const DesktopWorkflowPane({
    super.key,
    required this.section,
    required this.presets,
    required this.providerDescriptors,
    required this.managedProviders,
    required this.profiles,
    required this.selectedProfileId,
    required this.selectedManagedProviderId,
    required this.busy,
    required this.onApplyPreset,
    required this.onSelectManagedProvider,
    required this.onCreateManagedProvider,
    required this.onSelectProfile,
    required this.onCreateDraft,
  });

  final DesktopShellSection section;
  final List<ProviderPreset> presets;
  final List<ProviderDescriptor> providerDescriptors;
  final List<ManagedProviderRecord> managedProviders;
  final List<ProfileRecord> profiles;
  final String? selectedProfileId;
  final String? selectedManagedProviderId;
  final bool busy;
  final ValueChanged<ProviderPreset> onApplyPreset;
  final ValueChanged<String> onSelectManagedProvider;
  final VoidCallback onCreateManagedProvider;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onCreateDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (section) {
      DesktopShellSection.profileWorkflow => _buildProfilesPane(theme),
      DesktopShellSection.providerWorkflow => _buildProvidersPane(theme),
    };
  }

  Widget _buildProfilesPane(ThemeData theme) {
    return Card(
      child: ListView(
        key: const ValueKey<String>('profile-workflow-library-scroll'),
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _sectionHeader(
                  theme,
                  title: 'Saved profiles',
                  subtitle:
                      'Browse saved snapshots and keep the active profile workflow separate from reusable provider records.',
                ),
              ),
              FilledButton.tonal(
                key: const ValueKey<String>('profile-create-draft-button'),
                onPressed: busy ? null : onCreateDraft,
                child: const Text('New draft'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoCard(
            theme,
            icon: Icons.inventory_2_outlined,
            title: 'Profile workflow',
            message:
                'Resolve, start, and save runtime snapshots from the active task pane. Managed providers stay in the separate provider workflow.',
          ),
          const SizedBox(height: 16),
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
    );
  }

  Widget _buildProvidersPane(ThemeData theme) {
    return Card(
      child: ListView(
        key: const ValueKey<String>('provider-workflow-library-scroll'),
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _sectionHeader(
                  theme,
                  title: 'Providers',
                  subtitle:
                      'App-owned managed records live here. Presets remain seed actions for new records, not a separate provider taxonomy.',
                ),
              ),
              FilledButton.tonal(
                key: const ValueKey<String>('managed-provider-create-button'),
                onPressed: busy ? null : onCreateManagedProvider,
                child: const Text('New record'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoCard(
            theme,
            icon: Icons.tune_outlined,
            title: 'Managed-provider workflow',
            message:
                'Create or edit app-owned managed records here, then apply one by snapshot to the active profile workflow.',
          ),
          const SizedBox(height: 16),
          _sectionHeader(
            theme,
            title: 'Presets',
            subtitle: 'Curated seed actions for shipped provider families.',
          ),
          const SizedBox(height: 10),
          ...presets.map((ProviderPreset preset) {
            final availability = preset.availabilityFor(providerDescriptors);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _presetCard(theme, preset, availability),
            );
          }),
          const SizedBox(height: 18),
          _sectionHeader(
            theme,
            title: 'Managed records',
            subtitle:
                'Reusable non-secret provider-owned values stored in shell state.',
          ),
          const SizedBox(height: 10),
          if (managedProviders.isEmpty)
            _emptyCard(
              theme,
              'No managed records yet. Create one from the app-owned catalog and keep runtime-only inputs in profile drafts.',
            )
          else
            ...managedProviders.map(
              (ManagedProviderRecord config) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _providerConfigCard(theme, config),
              ),
            ),
        ],
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

  Widget _infoCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
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
                  style: theme.textTheme.titleSmall?.copyWith(
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

  Widget _providerConfigCard(ThemeData theme, ManagedProviderRecord config) {
    final selected = selectedManagedProviderId == config.id;
    final accent = config.isAvailable;
    final supportedProvider = supportedProviderDefinitionFor(config.provider);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey<String>('managed-provider-item-${config.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => onSelectManagedProvider(config.id),
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
                supportedProvider == null
                    ? config.provider
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
    final selected = selectedProfileId == profile.id;
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
