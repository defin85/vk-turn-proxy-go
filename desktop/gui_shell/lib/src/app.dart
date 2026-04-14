import 'package:flutter/material.dart';
import 'package:gui_shell/src/design/design_reference_gallery_page.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/theme/shell_theme.dart';
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
      theme: buildDesktopShellTheme(),
      home: DashboardPage(controller: widget.controller),
    );
  }
}

class DesktopShellDesignReferencesApp extends StatelessWidget {
  const DesktopShellDesignReferencesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'vk-turn-proxy desktop shell references',
      debugShowCheckedModeBanner: false,
      theme: buildDesktopShellTheme(),
      home: const DesignReferenceGalleryPage(),
    );
  }
}
