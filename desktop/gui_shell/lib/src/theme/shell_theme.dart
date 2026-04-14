import 'package:flutter/material.dart';

ThemeData buildDesktopShellTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF9D5A31),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF1F4B57),
          secondary: const Color(0xFF9D5A31),
          tertiary: const Color(0xFF6F8D6A),
          surface: const Color(0xFFF4EEE3),
        ),
    scaffoldBackgroundColor: const Color(0xFFEDE7DB),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: Color(0xFFFFFBF5),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
  );
}
