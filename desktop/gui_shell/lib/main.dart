import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gui_shell/src/app.dart';
import 'package:gui_shell/src/control/control_plane_client.dart';
import 'package:gui_shell/src/control/desktop_host_supervisor.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';
import 'package:gui_shell/src/control/shell_state_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final client = ControlPlaneClient.localhost();
  final controller = DesktopShellController(
    api: client,
    supervisor: DesktopHostSupervisor(
      client: client,
      listenAddress: ControlPlaneClient.defaultListenAddress,
      locator: const DefaultSidecarLocator(),
    ),
    stateStore: FileDesktopShellStateStore(),
  );
  unawaited(controller.initialize());

  runApp(DesktopShellApp(controller: controller));
}
