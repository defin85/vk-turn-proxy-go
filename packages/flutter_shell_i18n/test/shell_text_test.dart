import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> _pumpLocaleContext(
  WidgetTester tester,
  AppLocale locale,
) async {
  await locale.build();
  LocaleSettings.setLocaleSync(locale);

  late BuildContext capturedContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          capturedContext = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump();
  return capturedContext;
}

void main() {
  tearDown(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  testWidgets('shared desktop shell text stays available in English', (
    WidgetTester tester,
  ) async {
    final context = await _pumpLocaleContext(tester, AppLocale.en);
    final copy = context.shellText;

    expect(
      copy.desktopSavedProfilesRouteDetail,
      'Choose a saved profile, or return to the active profile editor without losing the current draft.',
    );
    expect(copy.desktopInspector, 'Inspector');
    expect(copy.desktopPlatformTunnelModes, 'Platform tunnel modes');
    expect(copy.desktopNoSessionsYet, 'No active or recent sessions yet.');
    expect(copy.continueInBrowser, 'Continue in browser');
    expect(shellLocaleDisplayName(context, AppLocale.ru), 'Russian');
  });

  testWidgets('shared desktop shell text stays available in Russian', (
    WidgetTester tester,
  ) async {
    final context = await _pumpLocaleContext(tester, AppLocale.ru);
    final copy = context.shellText;

    expect(
      copy.desktopSavedProfilesRouteDetail,
      'Выберите сохраненный профиль или вернитесь в активный редактор профиля, не теряя текущий черновик.',
    );
    expect(copy.desktopInspector, 'Инспектор');
    expect(
      copy.desktopPlatformTunnelModes,
      'Платформенные туннельные режимы',
    );
    expect(copy.desktopNoSessionsYet, 'Активных или недавних сессий пока нет.');
    expect(copy.continueInBrowser, 'Продолжить в браузере');
    expect(shellLocaleDisplayName(context, AppLocale.en), 'Английский');
  });
}
