import 'package:flutter/material.dart';

import '../control/control_plane_models.dart';
import '../control/runtime_execution_planning.dart';
import 'shell_visuals.dart';

class ProviderSourceCatalogSurface extends StatelessWidget {
  const ProviderSourceCatalogSurface({
    super.key,
    required this.sources,
    this.compact = false,
  });

  final List<RemoteProviderSourceDescriptor> sources;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourceCount = sources.length;
    return Container(
      key: const ValueKey<String>('provider-source-catalog'),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.muted,
        tone: sourceCount == 0
            ? ShellSemanticTone.attention
            : ShellSemanticTone.info,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Provider sources',
                  style:
                      (compact
                              ? theme.textTheme.titleSmall
                              : theme.textTheme.titleMedium)
                          ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              ShellToneBadge(
                label: sourceCount == 0 ? 'empty' : '$sourceCount',
                tone: sourceCount == 0
                    ? ShellSemanticTone.attention
                    : ShellSemanticTone.info,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sourceCount == 0
                ? 'No remote provider source catalog was reported by the host.'
                : 'Remote catalogs available for profile/provider selection.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (sourceCount > 0) ...<Widget>[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: compact ? 220 : 260),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: sources
                      .map(
                        (RemoteProviderSourceDescriptor source) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ProviderSourceCard(
                            source: source,
                            compact: compact,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderSourceCard extends StatelessWidget {
  const _ProviderSourceCard({required this.source, required this.compact});

  final RemoteProviderSourceDescriptor source;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _firstNonEmpty(<String>[
      source.displayName,
      source.sourceId,
      source.providerId,
    ]);
    final subtitleParts = <String>[
      if (source.providerId.trim().isNotEmpty) 'provider ${source.providerId}',
      if (source.sourceId.trim().isNotEmpty) 'source ${source.sourceId}',
      if (source.sourceFamily.trim().isNotEmpty) source.sourceFamily,
      if (source.generation > 0) 'gen ${source.generation}',
    ];
    final statusParts = <String>[
      if (source.validationStatus.trim().isNotEmpty)
        'validation ${source.validationStatus}',
      if (source.healthStatus.trim().isNotEmpty)
        'health ${source.healthStatus}',
      if (source.evidenceStatus.trim().isNotEmpty)
        'evidence ${source.evidenceStatus}',
    ];
    return Container(
      key: ValueKey<String>('provider-source-card-${source.sourceId}'),
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: shellSurfaceDecoration(
        context,
        style: ShellSurfaceStyle.highlight,
        tone: ShellSemanticTone.info,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style:
                          (compact
                                  ? theme.textTheme.titleSmall
                                  : theme.textTheme.titleMedium)
                              ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (subtitleParts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitleParts.join(' - '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (source.validationStatus.trim().isNotEmpty) ...<Widget>[
                const SizedBox(width: 10),
                ShellToneBadge(
                  label: source.validationStatus.trim(),
                  tone: _statusTone(source.validationStatus),
                ),
              ],
            ],
          ),
          if (source.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              source.description.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (statusParts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              statusParts.join(' - '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (source.artifactOffers.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: source.artifactOffers
                  .map(
                    (RemoteProviderArtifactOffer offer) =>
                        _ProviderArtifactOfferChip(offer: offer),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderArtifactOfferChip extends StatelessWidget {
  const _ProviderArtifactOfferChip({required this.offer});

  final RemoteProviderArtifactOffer offer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      _firstNonEmpty(<String>[offer.family, offer.offerId]),
      if (offer.accessMethods.isNotEmpty) offer.accessMethods.join('/'),
      if (offer.compatibleProfileKinds.isNotEmpty)
        offer.compatibleProfileKinds
            .map((TransportProfileKind kind) => kind.value)
            .join('/'),
    ].where((String part) => part.trim().isNotEmpty).toList(growable: false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        parts.isEmpty ? 'artifact' : parts.join(' - '),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

ShellSemanticTone _statusTone(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == 'valid' ||
      normalized == 'healthy' ||
      normalized == 'ready' ||
      normalized == 'fresh') {
    return ShellSemanticTone.ready;
  }
  if (normalized == 'invalid' ||
      normalized == 'failed' ||
      normalized == 'unsupported') {
    return ShellSemanticTone.danger;
  }
  return ShellSemanticTone.info;
}

String _firstNonEmpty(Iterable<String> values) {
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return 'unknown';
}
