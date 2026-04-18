import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/app.dart';
import 'package:gui_shell/src/control/desktop_shell_controller.dart';

Future<void> pumpDesktopShellTestApp(
  WidgetTester tester, {
  required DesktopShellController controller,
  AppLocale locale = AppLocale.en,
}) async {
  addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));
  await locale.build();
  LocaleSettings.setLocaleSync(locale);
  await tester.pumpWidget(DesktopShellApp(controller: controller));
  await tester.pump();
}
