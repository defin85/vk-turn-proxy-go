import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpShellCoreLocalizedTestApp(
  WidgetTester tester, {
  required Widget child,
  AppLocale locale = AppLocale.en,
}) async {
  addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.en));
  await locale.build();
  LocaleSettings.setLocaleSync(locale);
  await tester.pumpWidget(
    TranslationProvider(
      child: Builder(
        builder: (BuildContext context) {
          final translations = TranslationProvider.of(context);
          return MaterialApp(
            locale: translations.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(body: child),
          );
        },
      ),
    ),
  );
  await tester.pump();
}
