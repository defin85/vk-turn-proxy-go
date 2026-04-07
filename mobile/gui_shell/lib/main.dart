import 'package:flutter/widgets.dart';
import 'package:mobile_gui_shell/src/app.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = MobileShellController(
    bridge: MobileHostBridgeFactory.fromEnvironment(),
    stateStore: await MobileShellStateStore.defaultStore(),
  );
  await controller.initialize();

  runApp(MobileShellApp(controller: controller));
}
