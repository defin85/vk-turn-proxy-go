import 'package:flutter/material.dart';

import '../control/control_plane_models.dart';

enum WorkflowLibrarySurfaceVariant { desktop, mobile }

class WorkflowSectionHeaderData {
  const WorkflowSectionHeaderData({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

class WorkflowHintData {
  const WorkflowHintData({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;
}

class WorkflowEmptyStateData {
  const WorkflowEmptyStateData({required this.message, this.title});

  final String? title;
  final String message;
}

typedef SavedProfileLibraryItemBuilder =
    Widget Function(BuildContext context, ProfileRecord profile, bool active);

typedef ManagedProviderLibraryItemBuilder =
    Widget Function(
      BuildContext context,
      ManagedProviderRecord provider,
      bool active,
    );

class SavedProfilesLibrarySurface extends StatelessWidget {
  const SavedProfilesLibrarySurface({
    super.key,
    required this.variant,
    required this.profiles,
    required this.activeProfileId,
    required this.itemBuilder,
    required this.emptyState,
    this.scrollKey,
    this.header,
    this.headerAction,
    this.hint,
  });

  final WorkflowLibrarySurfaceVariant variant;
  final List<ProfileRecord> profiles;
  final String? activeProfileId;
  final SavedProfileLibraryItemBuilder itemBuilder;
  final WorkflowEmptyStateData emptyState;
  final Key? scrollKey;
  final WorkflowSectionHeaderData? header;
  final Widget? headerAction;
  final WorkflowHintData? hint;

  @override
  Widget build(BuildContext context) {
    return _WorkflowLibrarySurface<ProfileRecord>(
      key: key,
      variant: variant,
      surfaceKey: ValueKey<String>(
        'saved-profiles-library-surface-${variant.name}',
      ),
      scrollKey: scrollKey,
      header: header,
      headerAction: headerAction,
      hint: hint,
      emptyState: emptyState,
      items: profiles,
      itemBuilder: (BuildContext context, ProfileRecord profile, bool active) {
        return itemBuilder(context, profile, active);
      },
      isActive: (ProfileRecord profile) => activeProfileId == profile.id,
    );
  }
}

class ManagedProvidersLibrarySurface extends StatelessWidget {
  const ManagedProvidersLibrarySurface({
    super.key,
    required this.variant,
    required this.managedProviders,
    required this.activeManagedProviderId,
    required this.itemBuilder,
    required this.emptyState,
    this.scrollKey,
    this.header,
    this.headerAction,
    this.hint,
  });

  final WorkflowLibrarySurfaceVariant variant;
  final List<ManagedProviderRecord> managedProviders;
  final String? activeManagedProviderId;
  final ManagedProviderLibraryItemBuilder itemBuilder;
  final WorkflowEmptyStateData emptyState;
  final Key? scrollKey;
  final WorkflowSectionHeaderData? header;
  final Widget? headerAction;
  final WorkflowHintData? hint;

  @override
  Widget build(BuildContext context) {
    return _WorkflowLibrarySurface<ManagedProviderRecord>(
      key: key,
      variant: variant,
      surfaceKey: ValueKey<String>(
        'managed-providers-library-surface-${variant.name}',
      ),
      scrollKey: scrollKey,
      header: header,
      headerAction: headerAction,
      hint: hint,
      emptyState: emptyState,
      items: managedProviders,
      itemBuilder:
          (BuildContext context, ManagedProviderRecord provider, bool active) =>
              itemBuilder(context, provider, active),
      isActive: (ManagedProviderRecord provider) =>
          activeManagedProviderId == provider.id,
    );
  }
}

class WorkflowSectionHeader extends StatelessWidget {
  const WorkflowSectionHeader({
    super.key,
    required this.variant,
    required this.title,
    required this.subtitle,
  });

  final WorkflowLibrarySurfaceVariant variant;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = switch (variant) {
      WorkflowLibrarySurfaceVariant.desktop => theme.textTheme.titleSmall,
      WorkflowLibrarySurfaceVariant.mobile => theme.textTheme.titleMedium,
    }?.copyWith(fontWeight: FontWeight.w700);
    final subtitleStyle = switch (variant) {
      WorkflowLibrarySurfaceVariant.desktop => theme.textTheme.bodySmall,
      WorkflowLibrarySurfaceVariant.mobile => theme.textTheme.bodyMedium,
    }?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: titleStyle),
        const SizedBox(height: 4),
        Text(subtitle, style: subtitleStyle),
      ],
    );
  }
}

class WorkflowHintCard extends StatelessWidget {
  const WorkflowHintCard({
    super.key,
    required this.variant,
    required this.icon,
    required this.title,
    required this.message,
  });

  final WorkflowLibrarySurfaceVariant variant;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundAlpha = switch (variant) {
      WorkflowLibrarySurfaceVariant.desktop => 0.28,
      WorkflowLibrarySurfaceVariant.mobile => 0.18,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: backgroundAlpha,
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

class WorkflowEmptyStateCard extends StatelessWidget {
  const WorkflowEmptyStateCard({
    super.key,
    required this.variant,
    required this.message,
    this.title,
  });

  final WorkflowLibrarySurfaceVariant variant;
  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (variant) {
      WorkflowLibrarySurfaceVariant.desktop => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: _EmptyStateText(
          variant: variant,
          title: title,
          message: message,
        ),
      ),
      WorkflowLibrarySurfaceVariant.mobile => _EmptyStateText(
        variant: variant,
        title: title,
        message: message,
      ),
    };
  }
}

class _WorkflowLibrarySurface<T> extends StatelessWidget {
  const _WorkflowLibrarySurface({
    super.key,
    required this.variant,
    required this.surfaceKey,
    required this.emptyState,
    required this.items,
    required this.itemBuilder,
    required this.isActive,
    this.scrollKey,
    this.header,
    this.headerAction,
    this.hint,
  });

  final WorkflowLibrarySurfaceVariant variant;
  final Key surfaceKey;
  final Key? scrollKey;
  final WorkflowSectionHeaderData? header;
  final Widget? headerAction;
  final WorkflowHintData? hint;
  final WorkflowEmptyStateData emptyState;
  final List<T> items;
  final Widget Function(BuildContext context, T item, bool active) itemBuilder;
  final bool Function(T item) isActive;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: surfaceKey,
      child: switch (variant) {
        WorkflowLibrarySurfaceVariant.desktop => _buildDesktop(context),
        WorkflowLibrarySurfaceVariant.mobile => _buildMobile(context),
      },
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final children = <Widget>[
      ..._buildHeader(context),
      ..._buildHint(),
      if (items.isEmpty)
        WorkflowEmptyStateCard(
          variant: variant,
          title: emptyState.title,
          message: emptyState.message,
        )
      else
        ..._desktopItems(context),
    ];
    return ListView(
      key: scrollKey,
      primary: false,
      padding: const EdgeInsets.all(20),
      children: children,
    );
  }

  Widget _buildMobile(BuildContext context) {
    final children = <Widget>[
      ..._buildHeader(context),
      ..._buildHint(),
      if (items.isEmpty)
        WorkflowEmptyStateCard(
          variant: variant,
          title: emptyState.title,
          message: emptyState.message,
        )
      else
        ..._mobileItems(context),
    ];
    return Card(
      child: Padding(
        padding: EdgeInsets.all(items.isEmpty ? 18 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  List<Widget> _buildHeader(BuildContext context) {
    if (header == null && headerAction == null) {
      return const <Widget>[];
    }
    return <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (header != null)
            Expanded(
              child: WorkflowSectionHeader(
                variant: variant,
                title: header!.title,
                subtitle: header!.subtitle,
              ),
            ),
          if (headerAction != null) ...<Widget>[
            if (header != null) const SizedBox(width: 12),
            headerAction!,
          ],
        ],
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildHint() {
    if (hint == null) {
      return const <Widget>[];
    }
    return <Widget>[
      WorkflowHintCard(
        variant: variant,
        icon: hint!.icon,
        title: hint!.title,
        message: hint!.message,
      ),
      const SizedBox(height: 14),
    ];
  }

  List<Widget> _desktopItems(BuildContext context) {
    return items
        .map(
          (T item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: itemBuilder(context, item, isActive(item)),
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _mobileItems(BuildContext context) {
    final children = <Widget>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      children.add(itemBuilder(context, item, isActive(item)));
      if (index != items.length - 1) {
        children.add(const Divider(height: 1));
      }
    }
    return children;
  }
}

class _EmptyStateText extends StatelessWidget {
  const _EmptyStateText({
    required this.variant,
    required this.title,
    required this.message,
  });

  final WorkflowLibrarySurfaceVariant variant;
  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = switch (variant) {
      WorkflowLibrarySurfaceVariant.desktop => theme.textTheme.titleMedium,
      WorkflowLibrarySurfaceVariant.mobile => theme.textTheme.titleLarge,
    }?.copyWith(fontWeight: FontWeight.w700);
    final messageStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Text(title!, style: titleStyle),
          const SizedBox(height: 6),
        ],
        Text(message, style: messageStyle),
      ],
    );
  }
}
