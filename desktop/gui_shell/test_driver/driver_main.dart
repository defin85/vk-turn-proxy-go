import 'package:flutter_driver/driver_extension.dart';
import 'package:gui_shell/src/bootstrap.dart';

void main() {
  enableFlutterDriverExtension(enableTextEntryEmulation: false);
  runDesktopShellEntrypoint(ensureInitialized: false);
}
