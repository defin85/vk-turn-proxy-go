import 'package:flutter/material.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/ui/dashboard_page.dart';

class DesktopShellApp extends StatefulWidget {
  const DesktopShellApp({super.key, required this.controller});

  final DesktopShellController controller;

  @override
  State<DesktopShellApp> createState() => _DesktopShellAppState();
}

class _DesktopShellAppState extends State<DesktopShellApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'vk-turn-proxy desktop shell',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
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
      ),
      home: DashboardPage(controller: widget.controller),
    );
  }
}
