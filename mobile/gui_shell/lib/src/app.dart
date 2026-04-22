import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_shell_core/shell_visuals.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/ui/dashboard_page.dart';
import 'package:mobile_gui_shell/src/ui/owned_browser_challenge.dart';

class MobileShellApp extends StatefulWidget {
  const MobileShellApp({
    super.key,
    required this.controller,
    this.ownedBrowserChallengeRunner =
        const WebViewOwnedBrowserChallengeRunner(),
  });

  final MobileShellController controller;
  final OwnedBrowserChallengeRunner ownedBrowserChallengeRunner;

  @override
  State<MobileShellApp> createState() => _MobileShellAppState();
}

class _MobileShellAppState extends State<MobileShellApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.onAppLifecycleStateChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    return TranslationProvider(
      child: Builder(
        builder: (BuildContext context) {
          final localeData = TranslationProvider.of(context);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: localeData.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            onGenerateTitle: (BuildContext context) => context.t.appMobileTitle,
            theme: buildRelayDockShellTheme(),
            home: DashboardPage(
              controller: widget.controller,
              ownedBrowserChallengeRunner: widget.ownedBrowserChallengeRunner,
            ),
          );
        },
      ),
    );
  }
}
