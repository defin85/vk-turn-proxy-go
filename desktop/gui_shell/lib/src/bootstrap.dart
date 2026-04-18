import 'dart:async';

import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter/widgets.dart';
import 'package:gui_shell/src/app.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';

const bool _designReferenceMode = bool.fromEnvironment(
  'VKTP_DESIGN_REFERENCES',
);

Future<void> runDesktopShellEntrypoint({bool ensureInitialized = true}) async {
  if (ensureInitialized) {
    WidgetsFlutterBinding.ensureInitialized();
  }

  final stateStore = FileDesktopShellStateStore();
  try {
    final persistedState = await stateStore.load();
    await restoreShellLocale(persistedState?.localeTag);
  } catch (_) {
    await restoreShellLocale(null);
  }

  if (_designReferenceMode) {
    runApp(const DesktopShellDesignReferencesApp());
    return;
  }

  final client = ControlPlaneClient.localhost(
    localeTagProvider: currentShellLocaleTag,
  );
  final controller = DesktopShellController(
    api: client,
    supervisor: DesktopHostSupervisor(
      client: client,
      listenAddress: ControlPlaneClient.defaultListenAddress,
      locator: const DefaultSidecarLocator(),
    ),
    stateStore: stateStore,
  );
  unawaited(controller.initialize());

  runApp(DesktopShellApp(controller: controller));
}
