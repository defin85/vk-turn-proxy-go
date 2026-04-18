import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_gui_shell/src/app.dart';
import 'package:mobile_gui_shell/src/control/control_plane_client.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final stateStore = await MobileShellStateStore.defaultStore();
  try {
    final persistedState = await stateStore.load();
    await restoreShellLocale(persistedState?.localeTag);
  } catch (_) {
    await restoreShellLocale(null);
  }

  final controller = MobileShellController(
    bridge: await MobileHostBridgeFactory.fromEnvironment(
      clientFactory: (Uri baseUri) => ControlPlaneClient(
        baseUri: baseUri,
        localeTagProvider: currentShellLocaleTag,
      ),
    ),
    stateStore: stateStore,
  );
  await controller.initialize();

  runApp(MobileShellApp(controller: controller));
}
