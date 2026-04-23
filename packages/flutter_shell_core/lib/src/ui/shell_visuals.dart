import 'package:flutter/material.dart';

enum ShellSemanticTone { neutral, info, ready, attention, danger }

enum ShellSurfaceStyle { muted, highlight, chrome }

@immutable
class ShellTonePalette {
  const ShellTonePalette({
    required this.container,
    required this.onContainer,
    required this.accent,
    Color? border,
  }) : border = border ?? accent;

  final Color container;
  final Color onContainer;
  final Color accent;
  final Color border;
}

@immutable
class ShellVisualTheme extends ThemeExtension<ShellVisualTheme> {
  const ShellVisualTheme({
    required this.chromeSurface,
    required this.mutedSurface,
    required this.highlightSurface,
    required this.overlaySurface,
    required this.neutralTone,
    required this.infoTone,
    required this.readyTone,
    required this.attentionTone,
    required this.dangerTone,
  });

  const ShellVisualTheme.relayDockLight()
    : chromeSurface = const Color(0xFFF7F2E8),
      mutedSurface = const Color(0xFFF3EDE2),
      highlightSurface = const Color(0xFFFFFBF6),
      overlaySurface = const Color(0xFFFDF7EC),
      neutralTone = const ShellTonePalette(
        container: Color(0xFFE5ECF6),
        onContainer: Color(0xFF35516D),
        accent: Color(0xFF35516D),
        border: Color(0xFF6B7E95),
      ),
      infoTone = const ShellTonePalette(
        container: Color(0xFFE6EDF7),
        onContainer: Color(0xFF245070),
        accent: Color(0xFF245070),
        border: Color(0xFF6B8AA2),
      ),
      readyTone = const ShellTonePalette(
        container: Color(0xFFE2F4E8),
        onContainer: Color(0xFF1E6A3B),
        accent: Color(0xFF1E6A3B),
        border: Color(0xFF4E8864),
      ),
      attentionTone = const ShellTonePalette(
        container: Color(0xFFFFF1D6),
        onContainer: Color(0xFF7E5514),
        accent: Color(0xFF9A6A22),
        border: Color(0xFFC59A49),
      ),
      dangerTone = const ShellTonePalette(
        container: Color(0xFFFFE3E0),
        onContainer: Color(0xFF7A1F16),
        accent: Color(0xFFB3261E),
        border: Color(0xFFD86E63),
      );

  final Color chromeSurface;
  final Color mutedSurface;
  final Color highlightSurface;
  final Color overlaySurface;
  final ShellTonePalette neutralTone;
  final ShellTonePalette infoTone;
  final ShellTonePalette readyTone;
  final ShellTonePalette attentionTone;
  final ShellTonePalette dangerTone;

  ShellTonePalette tone(ShellSemanticTone tone) {
    return switch (tone) {
      ShellSemanticTone.neutral => neutralTone,
      ShellSemanticTone.info => infoTone,
      ShellSemanticTone.ready => readyTone,
      ShellSemanticTone.attention => attentionTone,
      ShellSemanticTone.danger => dangerTone,
    };
  }

  @override
  ShellVisualTheme copyWith({
    Color? chromeSurface,
    Color? mutedSurface,
    Color? highlightSurface,
    Color? overlaySurface,
    ShellTonePalette? neutralTone,
    ShellTonePalette? infoTone,
    ShellTonePalette? readyTone,
    ShellTonePalette? attentionTone,
    ShellTonePalette? dangerTone,
  }) {
    return ShellVisualTheme(
      chromeSurface: chromeSurface ?? this.chromeSurface,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      highlightSurface: highlightSurface ?? this.highlightSurface,
      overlaySurface: overlaySurface ?? this.overlaySurface,
      neutralTone: neutralTone ?? this.neutralTone,
      infoTone: infoTone ?? this.infoTone,
      readyTone: readyTone ?? this.readyTone,
      attentionTone: attentionTone ?? this.attentionTone,
      dangerTone: dangerTone ?? this.dangerTone,
    );
  }

  @override
  ShellVisualTheme lerp(ThemeExtension<ShellVisualTheme>? other, double t) {
    if (other is! ShellVisualTheme) {
      return this;
    }
    return ShellVisualTheme(
      chromeSurface: Color.lerp(chromeSurface, other.chromeSurface, t)!,
      mutedSurface: Color.lerp(mutedSurface, other.mutedSurface, t)!,
      highlightSurface: Color.lerp(
        highlightSurface,
        other.highlightSurface,
        t,
      )!,
      overlaySurface: Color.lerp(overlaySurface, other.overlaySurface, t)!,
      neutralTone: _lerpTone(neutralTone, other.neutralTone, t),
      infoTone: _lerpTone(infoTone, other.infoTone, t),
      readyTone: _lerpTone(readyTone, other.readyTone, t),
      attentionTone: _lerpTone(attentionTone, other.attentionTone, t),
      dangerTone: _lerpTone(dangerTone, other.dangerTone, t),
    );
  }

  static ShellTonePalette _lerpTone(
    ShellTonePalette a,
    ShellTonePalette b,
    double t,
  ) {
    return ShellTonePalette(
      container: Color.lerp(a.container, b.container, t)!,
      onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      border: Color.lerp(a.border, b.border, t)!,
    );
  }
}

extension ShellVisualContext on BuildContext {
  ShellVisualTheme get shellVisuals =>
      Theme.of(this).extension<ShellVisualTheme>() ??
      const ShellVisualTheme.relayDockLight();
}

ThemeData buildRelayDockShellTheme() {
  const primary = Color(0xFF214B66);
  const secondary = Color(0xFFB36A37);
  const tertiary = Color(0xFF678D73);
  const surface = Color(0xFFF7F2E8);
  const scaffold = Color(0xFFEEE7DA);
  const cardColor = Color(0xFFFFFBF6);
  const outline = Color(0xFFD8D0C5);
  const inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    borderSide: BorderSide(color: outline),
  );
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF2D6A8A),
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffold,
    dividerColor: outline,
    cardTheme: const CardThemeData(
      elevation: 0,
      color: cardColor,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      // Outline floating labels in M3 need the default top headroom.
      contentPadding: EdgeInsets.fromLTRB(14, 20, 14, 12),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    ),
    extensions: const <ThemeExtension<dynamic>>[
      ShellVisualTheme.relayDockLight(),
    ],
  );
}

BoxDecoration shellSurfaceDecoration(
  BuildContext context, {
  ShellSurfaceStyle style = ShellSurfaceStyle.muted,
  ShellSemanticTone tone = ShellSemanticTone.neutral,
  BorderRadiusGeometry borderRadius = const BorderRadius.all(
    Radius.circular(18),
  ),
}) {
  final theme = Theme.of(context);
  final visuals = context.shellVisuals;
  final palette = visuals.tone(tone);
  var background = switch (style) {
    ShellSurfaceStyle.muted => visuals.mutedSurface,
    ShellSurfaceStyle.highlight => visuals.highlightSurface,
    ShellSurfaceStyle.chrome => visuals.chromeSurface,
  };
  Color borderColor;
  if (tone == ShellSemanticTone.neutral) {
    borderColor = theme.colorScheme.outlineVariant.withValues(
      alpha: style == ShellSurfaceStyle.chrome ? 0.22 : 0.14,
    );
  } else {
    final overlayAlpha = switch (style) {
      ShellSurfaceStyle.muted => 0.08,
      ShellSurfaceStyle.highlight => 0.06,
      ShellSurfaceStyle.chrome => 0.10,
    };
    background = Color.alphaBlend(
      palette.accent.withValues(alpha: overlayAlpha),
      background,
    );
    borderColor = palette.border.withValues(alpha: 0.22);
  }

  return BoxDecoration(
    color: background,
    borderRadius: borderRadius,
    border: Border.all(color: borderColor),
  );
}

class ShellToneBadge extends StatelessWidget {
  const ShellToneBadge({
    super.key,
    required this.label,
    this.tone = ShellSemanticTone.neutral,
    this.icon,
    this.padding,
  });

  final String label;
  final ShellSemanticTone tone;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.shellVisuals.tone(tone);
    final theme = Theme.of(context);
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.container,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: palette.accent),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: theme.textTheme.labelMedium?.copyWith(
                color: palette.onContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShellNoticeBanner extends StatelessWidget {
  const ShellNoticeBanner({
    super.key,
    required this.message,
    this.tone = ShellSemanticTone.attention,
    this.icon = Icons.info_outline,
    this.compact = false,
  });

  final String message;
  final ShellSemanticTone tone;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.shellVisuals.tone(tone);
    final theme = Theme.of(context);
    return Card(
      color: palette.container,
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Row(
          children: <Widget>[
            Icon(icon, size: compact ? 18 : 22, color: palette.accent),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Text(
                message,
                style:
                    (compact
                            ? theme.textTheme.bodySmall
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(color: palette.onContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
