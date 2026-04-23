import 'package:flutter/material.dart';
import 'package:flutter_shell_core/workflow_library_surface.dart' as workflow;
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';

enum _ManagedProviderLibraryMenuAction { openPresetBootstrap }

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
    final copy = context.shellText;
    return workflow.SavedProfilesLibrarySurface(
      variant: workflow.WorkflowLibrarySurfaceVariant.desktop,
      scrollKey: const ValueKey<String>('saved-profile-library-scroll'),
      profiles: profiles,
      activeProfileId: selectedProfileId,
      header: workflow.WorkflowSectionHeaderData(
        title: copy.desktopSavedProfilesLibraryTitle,
        subtitle: copy.desktopSavedProfilesLibrarySubtitle,
      ),
      headerAction: FilledButton.tonal(
        key: const ValueKey<String>('profile-create-draft-button'),
        onPressed: busy ? null : onCreateDraft,
        child: Text(t.commonNewDraft),
      ),
      hint: workflow.WorkflowHintData(
        icon: Icons.fact_check_outlined,
        title: copy.desktopReturnPathExplicitTitle,
        message: copy.desktopReturnPathExplicitMessage,
      ),
      emptyState: workflow.WorkflowEmptyStateData(
        message: copy.desktopNoSavedProfilesYetShort,
      ),
      itemBuilder: (BuildContext context, ProfileRecord profile, bool active) {
        return _ProfileCard(
          theme: theme,
          profile: profile,
          selected: active,
          onTap: () => onSelectProfile(profile.id),
        );
      },
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
    this.onOpenPresetBootstrap,
  });

  final List<ManagedProviderRecord> managedProviders;
  final String? selectedManagedProviderId;
  final ValueChanged<String> onSelectManagedProvider;
  final VoidCallback? onCreateManagedProvider;
  final VoidCallback? onOpenPresetBootstrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = context.shellText;
    return workflow.ManagedProvidersLibrarySurface(
      variant: workflow.WorkflowLibrarySurfaceVariant.desktop,
      scrollKey: const ValueKey<String>('managed-provider-library-scroll'),
      managedProviders: managedProviders,
      activeManagedProviderId: selectedManagedProviderId,
      header: workflow.WorkflowSectionHeaderData(
        title: copy.desktopProviderRecordsLibraryTitle,
        subtitle: copy.desktopProviderRecordsLibrarySubtitle,
      ),
      headerAction:
          onCreateManagedProvider == null && onOpenPresetBootstrap == null
          ? null
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (onOpenPresetBootstrap != null)
                  PopupMenuButton<_ManagedProviderLibraryMenuAction>(
                    key: const ValueKey<String>(
                      'managed-provider-more-actions-button',
                    ),
                    tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                    onSelected: (_ManagedProviderLibraryMenuAction action) {
                      switch (action) {
                        case _ManagedProviderLibraryMenuAction
                            .openPresetBootstrap:
                          onOpenPresetBootstrap!();
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<_ManagedProviderLibraryMenuAction>>[
                          PopupMenuItem<_ManagedProviderLibraryMenuAction>(
                            key: const ValueKey<String>(
                              'desktop-open-preset-bootstrap-button',
                            ),
                            value: _ManagedProviderLibraryMenuAction
                                .openPresetBootstrap,
                            child: Text(t.commonNewFromPreset),
                          ),
                        ],
                    icon: const Icon(Icons.more_horiz),
                  ),
                if (onCreateManagedProvider != null)
                  FilledButton.tonal(
                    key: const ValueKey<String>(
                      'managed-provider-create-button',
                    ),
                    onPressed: onCreateManagedProvider,
                    child: Text(copy.desktopNewRecord),
                  ),
              ],
            ),
      hint: workflow.WorkflowHintData(
        icon: Icons.tune_outlined,
        title: copy.desktopRecordsSeparateFromFamiliesTitle,
        message: copy.desktopRecordsSeparateFromFamiliesMessage,
      ),
      emptyState: workflow.WorkflowEmptyStateData(
        message: copy.desktopNoProviderRecordsYet,
      ),
      itemBuilder:
          (BuildContext context, ManagedProviderRecord provider, bool active) {
            return _ManagedProviderCard(
              theme: theme,
              provider: provider,
              selected: active,
              onTap: () => onSelectManagedProvider(provider.id),
            );
          },
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
    final copy = context.shellText;
    return ListView(
      key: const ValueKey<String>('preset-bootstrap-scroll'),
      primary: false,
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        workflow.WorkflowSectionHeader(
          variant: workflow.WorkflowLibrarySurfaceVariant.desktop,
          title: t.commonNewFromPreset,
          subtitle: copy.desktopNewFromPresetSubtitle,
        ),
        const SizedBox(height: 12),
        workflow.WorkflowHintCard(
          variant: workflow.WorkflowLibrarySurfaceVariant.desktop,
          icon: Icons.auto_awesome_outlined,
          title: copy.desktopPresetBootstrapExplicitTitle,
          message: copy.desktopPresetBootstrapExplicitMessage,
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
    final copy = context.shellText;
    return ListView(
      key: const ValueKey<String>('provider-family-chooser-scroll'),
      primary: false,
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        workflow.WorkflowSectionHeader(
          variant: workflow.WorkflowLibrarySurfaceVariant.desktop,
          title: t.commonProviderFamilies,
          subtitle: copy.desktopProviderFamiliesSubtitle,
        ),
        const SizedBox(height: 12),
        workflow.WorkflowHintCard(
          variant: workflow.WorkflowLibrarySurfaceVariant.desktop,
          icon: Icons.widgets_outlined,
          title: copy.desktopFamiliesReadonlyHereTitle,
          message: copy.desktopFamiliesReadonlyHereMessage,
        ),
        const SizedBox(height: 14),
        if (supportedProviders.isEmpty)
          workflow.WorkflowEmptyStateCard(
            variant: workflow.WorkflowLibrarySurfaceVariant.desktop,
            message: copy.desktopNoShippedProviderFamilies,
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
    final copy = context.shellText;
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
                label: availability.isAvailable
                    ? copy.available
                    : copy.unavailable,
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
              child: Text(copy.desktopUsePreset),
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
    final copy = context.shellText;
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
                    : copy.providerFamilyLabel(supportedProvider.title),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (supportedProvider != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  copy.appOwnedManagedRecord,
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
    final copy = context.shellText;
    final managedFieldLabel = switch (descriptor) {
      null => copy.noReusableFieldsYet,
      final ProviderDescriptor descriptor
          when descriptor.providerSettingsSupportError != null =>
        copy.schemaBlockedInShell,
      final ProviderDescriptor descriptor
          when descriptor.settingsSchema == null =>
        copy.noReusableFieldsYet,
      _ => copy.reusableFieldsReady,
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
                    label: availability.isAvailable
                        ? copy.available
                        : copy.unavailable,
                    accent: availability.isAvailable,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(provider.description, style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _MetaChip(
                    label: selected
                        ? copy.selectedFamily
                        : copy.desktopShippedByApp,
                  ),
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
