import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_gui_shell/src/app.dart';
import 'package:mobile_gui_shell/src/control/mobile_host_bridge.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_state_store.dart';

Future<void> main() async {
  enableFlutterDriverExtension(enableTextEntryEmulation: false);
  WidgetsFlutterBinding.ensureInitialized();

  final controller = MobileShellController(
    bridge: await MobileHostBridgeFactory.fromEnvironment(),
    stateStore: await MobileShellStateStore.defaultStore(),
  );
  await controller.initialize();
  await _seedDriverInvite(controller);

  runApp(MobileShellApp(controller: controller));
}

Future<void> _seedDriverInvite(MobileShellController controller) async {
  const invite =
      'https://vk.com/call/join/nZQ-WqsQ8Fy3AOPEyc-pF_JWXzNLSqgvF3ypfP1DWJc';

  final profileId = controller.selectedProfileId?.trim() ?? '';
  if (profileId.isEmpty) {
    return;
  }
  if (controller.draft.spec.link.trim().isNotEmpty) {
    return;
  }

  controller.updateDraft(
    controller.draft.copyWith(
      spec: controller.draft.spec.copyWith(link: invite),
    ),
  );
  await controller.saveDraft();
}
