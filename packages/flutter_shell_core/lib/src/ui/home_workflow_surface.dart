import 'package:flutter/material.dart';

import 'shell_visuals.dart';

enum HomeWorkflowActionStyle { filled, tonal, outlined, text }

@immutable
class HomeWorkflowAction {
  const HomeWorkflowAction({
    required this.label,
    this.onPressed,
    this.icon,
    this.style = HomeWorkflowActionStyle.filled,
    this.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final HomeWorkflowActionStyle style;
  final Key? key;
}

@immutable
class HomeWorkflowChoiceOption {
  const HomeWorkflowChoiceOption({
    required this.label,
    required this.selected,
    this.onSelected,
    this.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final Key? key;
}

@immutable
class HomeWorkflowChoiceGroup {
  const HomeWorkflowChoiceGroup({this.label, required this.options});

  final String? label;
  final List<HomeWorkflowChoiceOption> options;
}

@immutable
class HomeWorkflowEmptyStateData {
  const HomeWorkflowEmptyStateData({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String message;
  final List<HomeWorkflowAction> actions;
}

@immutable
class HomeWorkflowProfileSummaryData {
  const HomeWorkflowProfileSummaryData({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.caption,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String? caption;
}

@immutable
class HomeWorkflowPrimaryActionData {
  const HomeWorkflowPrimaryActionData({
    required this.tone,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.primaryAction,
    this.annotation,
    this.secondaryActions = const <HomeWorkflowAction>[],
  });

  final ShellSemanticTone tone;
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final HomeWorkflowAction primaryAction;
  final String? annotation;
  final List<HomeWorkflowAction> secondaryActions;
}

@immutable
class HomeWorkflowModeSectionData {
  const HomeWorkflowModeSectionData({
    required this.title,
    required this.summary,
    this.detail,
    this.choiceGroups = const <HomeWorkflowChoiceGroup>[],
  });

  final String title;
  final String summary;
  final String? detail;
  final List<HomeWorkflowChoiceGroup> choiceGroups;
}

@immutable
class HomeWorkflowSupportSectionData {
  const HomeWorkflowSupportSectionData({
    required this.title,
    required this.summary,
    required this.actions,
  });

  final String title;
  final String summary;
  final List<HomeWorkflowAction> actions;
}

class HomeWorkflowBody extends StatelessWidget {
  const HomeWorkflowBody({
    super.key,
    this.noticeMessage,
    this.noticeAction,
    this.emptyState,
    this.profileSummary,
    this.primaryAction,
    this.modeSection,
    this.supportSection,
  });

  final String? noticeMessage;
  final HomeWorkflowAction? noticeAction;
  final HomeWorkflowEmptyStateData? emptyState;
  final HomeWorkflowProfileSummaryData? profileSummary;
  final HomeWorkflowPrimaryActionData? primaryAction;
  final HomeWorkflowModeSectionData? modeSection;
  final HomeWorkflowSupportSectionData? supportSection;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final trimmedNotice = noticeMessage?.trim() ?? '';
    if (trimmedNotice.isNotEmpty) {
      children.add(ShellNoticeBanner(message: trimmedNotice));
    }
    if (noticeAction != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 12));
      }
      children.add(
        Align(
          alignment: Alignment.centerLeft,
          child: _HomeWorkflowButton(action: noticeAction!),
        ),
      );
    }

    final topSection = profileSummary != null
        ? _HomeWorkflowProfileSummaryCard(data: profileSummary!)
        : (emptyState != null
              ? _HomeWorkflowEmptyStateCard(data: emptyState!)
              : null);
    if (topSection != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 12));
      }
      children.add(topSection);
    }

    if (primaryAction != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 16));
      }
      children.add(_HomeWorkflowPrimaryActionCard(data: primaryAction!));
    }

    if (modeSection != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 16));
      }
      children.add(_HomeWorkflowModeSection(data: modeSection!));
    }

    if (supportSection != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 16));
      }
      children.add(_HomeWorkflowSupportSection(data: supportSection!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _HomeWorkflowEmptyStateCard extends StatelessWidget {
  const _HomeWorkflowEmptyStateCard({required this.data});

  final HomeWorkflowEmptyStateData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              data.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(data.message, style: theme.textTheme.bodyMedium),
            if (data.actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: data.actions
                    .map(
                      (HomeWorkflowAction action) =>
                          _HomeWorkflowButton(action: action),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeWorkflowProfileSummaryCard extends StatelessWidget {
  const _HomeWorkflowProfileSummaryCard({required this.data});

  final HomeWorkflowProfileSummaryData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.neutral,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              data.eyebrow,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(data.subtitle, style: theme.textTheme.bodyMedium),
            if ((data.caption?.trim() ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                data.caption!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeWorkflowModeSection extends StatelessWidget {
  const _HomeWorkflowModeSection({required this.data});

  final HomeWorkflowModeSectionData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.muted,
        tone: ShellSemanticTone.neutral,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              data.title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(data.summary, style: theme.textTheme.bodySmall),
            if ((data.detail?.trim() ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                data.detail!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            for (final HomeWorkflowChoiceGroup group
                in data.choiceGroups) ...<Widget>[
              if ((group.label?.trim() ?? '').isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  group.label!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else
                const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: group.options
                    .map(
                      (HomeWorkflowChoiceOption option) => ChoiceChip(
                        key: option.key,
                        selected: option.selected,
                        label: Text(option.label),
                        onSelected: option.onSelected == null
                            ? null
                            : (_) => option.onSelected!.call(),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeWorkflowPrimaryActionCard extends StatelessWidget {
  const _HomeWorkflowPrimaryActionCard({required this.data});

  final HomeWorkflowPrimaryActionData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.shellVisuals.tone(data.tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.container,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              data.eyebrow,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: palette.onContainer,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: palette.border.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      data.leadingIcon,
                      color: palette.onContainer,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        data.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(data.subtitle, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            if ((data.annotation?.trim() ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                data.annotation!,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: _HomeWorkflowButton(
                action: data.primaryAction,
                expandWidth: true,
                filledBackgroundColor: palette.onContainer,
                filledForegroundColor: Colors.white,
                minimumHeight: 68,
                borderRadius: 18,
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (data.secondaryActions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: data.secondaryActions
                    .map(
                      (HomeWorkflowAction action) =>
                          _HomeWorkflowButton(action: action),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeWorkflowSupportSection extends StatelessWidget {
  const _HomeWorkflowSupportSection({required this.data});

  final HomeWorkflowSupportSectionData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          data.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          data.summary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (data.actions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: data.actions
                .map(
                  (HomeWorkflowAction action) =>
                      _HomeWorkflowButton(action: action),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _HomeWorkflowButton extends StatelessWidget {
  const _HomeWorkflowButton({
    required this.action,
    this.expandWidth = false,
    this.filledBackgroundColor,
    this.filledForegroundColor,
    this.minimumHeight,
    this.borderRadius,
    this.textStyle,
  });

  final HomeWorkflowAction action;
  final bool expandWidth;
  final Color? filledBackgroundColor;
  final Color? filledForegroundColor;
  final double? minimumHeight;
  final double? borderRadius;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius == null
        ? null
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius!),
          );
    final child = switch (action.style) {
      HomeWorkflowActionStyle.filled =>
        action.icon == null
            ? FilledButton(
                key: action.key,
                onPressed: action.onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: filledBackgroundColor,
                  foregroundColor: filledForegroundColor,
                  minimumSize: minimumHeight == null
                      ? null
                      : Size.fromHeight(minimumHeight!),
                  shape: radius,
                  textStyle: textStyle,
                ),
                child: Text(action.label),
              )
            : FilledButton.icon(
                key: action.key,
                onPressed: action.onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: filledBackgroundColor,
                  foregroundColor: filledForegroundColor,
                  minimumSize: minimumHeight == null
                      ? null
                      : Size.fromHeight(minimumHeight!),
                  shape: radius,
                  textStyle: textStyle,
                ),
                icon: Icon(action.icon),
                label: Text(action.label),
              ),
      HomeWorkflowActionStyle.tonal =>
        action.icon == null
            ? FilledButton.tonal(
                key: action.key,
                onPressed: action.onPressed,
                child: Text(action.label),
              )
            : FilledButton.tonalIcon(
                key: action.key,
                onPressed: action.onPressed,
                icon: Icon(action.icon),
                label: Text(action.label),
              ),
      HomeWorkflowActionStyle.outlined =>
        action.icon == null
            ? OutlinedButton(
                key: action.key,
                onPressed: action.onPressed,
                child: Text(action.label),
              )
            : OutlinedButton.icon(
                key: action.key,
                onPressed: action.onPressed,
                icon: Icon(action.icon),
                label: Text(action.label),
              ),
      HomeWorkflowActionStyle.text =>
        action.icon == null
            ? TextButton(
                key: action.key,
                onPressed: action.onPressed,
                child: Text(action.label),
              )
            : TextButton.icon(
                key: action.key,
                onPressed: action.onPressed,
                icon: Icon(action.icon),
                label: Text(action.label),
              ),
    };

    if (!expandWidth) {
      return child;
    }
    return SizedBox(width: double.infinity, child: child);
  }
}
