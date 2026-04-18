import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/app.dart';
import 'package:mobile_gui_shell/src/control/mobile_shell_controller.dart';

Future<void> pumpMobileShellTestApp(
  WidgetTester tester, {
  required MobileShellController controller,
  AppLocale locale = AppLocale.en,
}) async {
  addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));
  await locale.build();
  LocaleSettings.setLocaleSync(locale);
  await tester.pumpWidget(MobileShellApp(controller: controller));
  await tester.pump();
}
