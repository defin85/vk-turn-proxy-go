import 'package:flutter/widgets.dart';

import 'i18n/strings.g.dart';

AppLocale? parseShellLocale(String? rawLocale) {
  final normalized = rawLocale?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  try {
    return AppLocaleUtils.parse(normalized);
  } catch (_) {
    return null;
  }
}

String shellLocaleTag(AppLocale locale) {
  return locale.flutterLocale.toLanguageTag();
}

String currentShellLocaleTag() {
  return shellLocaleTag(LocaleSettings.currentLocale);
}

Future<void> restoreShellLocale(String? rawLocale) async {
  final locale = parseShellLocale(rawLocale);
  if (locale == null) {
    await LocaleSettings.useDeviceLocale();
    return;
  }
  await LocaleSettings.setLocale(locale);
}

String shellLocaleDisplayName(BuildContext context, AppLocale locale) {
  return switch (locale) {
    AppLocale.en => t.localeEnglish,
    AppLocale.ru => t.localeRussian,
  };
}
