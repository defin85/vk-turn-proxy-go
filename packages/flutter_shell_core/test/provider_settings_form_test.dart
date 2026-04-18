import 'package:flutter/material.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_i18n.dart';

void main() {
  testWidgets(
    'provider settings form updates select fields when parent values change',
    (WidgetTester tester) async {
      const descriptor = ProviderDescriptor(
        id: 'wb-stream',
        displayName: 'WB Stream',
        inputKind: ProviderInputKind.link,
        authPosture: ProviderAuthPosture.staticSecret,
        browserPolicy: ProviderBrowserPolicy.notRequired,
        settingsSchema: ProviderSettingsSchema(
          type: 'object',
          additionalProperties: false,
          properties: <String, ProviderSettingProperty>{
            'region': ProviderSettingProperty(
              type: ProviderSettingType.string,
              control: ProviderSettingControl.select,
              persistence: ProviderSettingPersistence.profile,
              enumValues: <dynamic>['eu-west', 'ru-central'],
            ),
          },
          order: <String>['region'],
        ),
      );

      Widget buildForm(Map<String, dynamic> values) {
        return MaterialApp(
          home: Scaffold(
            body: ProviderSettingsForm(
              descriptor: descriptor,
              values: values,
              enabled: true,
              onChanged: (_) {},
            ),
          ),
        );
      }

      final field = find.byWidgetPredicate(
        (Widget widget) => widget is DropdownButtonFormField<dynamic>,
      );

      await tester.pumpWidget(
        buildForm(const <String, dynamic>{'region': 'eu-west'}),
      );
      expect(tester.state<FormFieldState<dynamic>>(field).value, 'eu-west');

      await tester.pumpWidget(
        buildForm(const <String, dynamic>{'region': 'ru-central'}),
      );
      await tester.pump();

      expect(tester.state<FormFieldState<dynamic>>(field).value, 'ru-central');
    },
  );

  testWidgets(
    'provider settings form resolves localized host labels for the active locale',
    (WidgetTester tester) async {
      const descriptor = ProviderDescriptor(
        id: 'wb-stream',
        displayName: 'WB Stream',
        inputKind: ProviderInputKind.link,
        authPosture: ProviderAuthPosture.staticSecret,
        browserPolicy: ProviderBrowserPolicy.notRequired,
        settingsSchema: ProviderSettingsSchema(
          type: 'object',
          additionalProperties: false,
          properties: <String, ProviderSettingProperty>{
            'region': ProviderSettingProperty(
              type: ProviderSettingType.string,
              title: 'Region',
              titleLocalized: <String, String>{'ru': 'Регион'},
              description: 'Choose provider region',
              descriptionLocalized: <String, String>{
                'ru': 'Выберите регион провайдера',
              },
              control: ProviderSettingControl.text,
              persistence: ProviderSettingPersistence.profile,
            ),
          },
          order: <String>['region'],
        ),
      );

      await pumpShellCoreLocalizedTestApp(
        tester,
        locale: AppLocale.ru,
        child: ProviderSettingsForm(
          descriptor: descriptor,
          values: const <String, dynamic>{},
          enabled: true,
          onChanged: (_) {},
        ),
      );

      expect(find.text('Регион'), findsOneWidget);
      expect(find.text('Выберите регион провайдера'), findsOneWidget);
    },
  );
}
