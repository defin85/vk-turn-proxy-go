import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_gui_shell/src/control/control_plane_models.dart';
import 'package:mobile_gui_shell/src/control/profile_draft.dart';
import 'package:mobile_gui_shell/src/ui/profile_editor.dart';

const ProviderDescriptor _providerWithSettingsDescriptor = ProviderDescriptor(
  id: 'wb-stream',
  displayName: 'WB Stream',
  description: 'Descriptor-driven provider settings test fixture.',
  inputKind: ProviderInputKind.link,
  authPosture: ProviderAuthPosture.account,
  browserPolicy: ProviderBrowserPolicy.notRequired,
  artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
  settingsSchema: ProviderSettingsSchema(
    type: 'object',
    additionalProperties: false,
    requiredKeys: <String>['region'],
    properties: <String, ProviderSettingProperty>{
      'region': ProviderSettingProperty(
        type: ProviderSettingType.string,
        title: 'Region',
        enumValues: <dynamic>['ru-central', 'eu-west'],
        defaultValue: 'ru-central',
        control: ProviderSettingControl.select,
        persistence: ProviderSettingPersistence.profile,
      ),
      'device_pin': ProviderSettingProperty(
        type: ProviderSettingType.string,
        title: 'Device PIN',
        writeOnly: true,
        control: ProviderSettingControl.password,
        persistence: ProviderSettingPersistence.ephemeral,
      ),
    },
  ),
);

const ProviderDescriptor _unsupportedProviderSettingsDescriptor =
    ProviderDescriptor(
      id: 'unsupported-provider',
      displayName: 'Unsupported provider',
      inputKind: ProviderInputKind.link,
      authPosture: ProviderAuthPosture.account,
      browserPolicy: ProviderBrowserPolicy.notRequired,
      artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
      settingsSchema: ProviderSettingsSchema(
        type: 'object',
        additionalProperties: false,
        properties: <String, ProviderSettingProperty>{
          'device_pin': ProviderSettingProperty(
            type: ProviderSettingType.string,
            title: 'Device PIN',
            writeOnly: true,
            control: ProviderSettingControl.password,
            persistence: ProviderSettingPersistence.profile,
          ),
        },
      ),
    );

void main() {
  testWidgets(
    'mobile profile editor renders descriptor-driven provider settings',
    (WidgetTester tester) async {
      final baseDraft = ProfileDraft.defaults();
      final draft = baseDraft.copyWith(
        spec: baseDraft.spec.copyWith(
          provider: 'wb-stream',
          link: 'https://wb.example.test/invite/abc',
          providerSettings: <String, dynamic>{
            'region': 'eu-west',
            'device_pin': '123456',
          },
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 1400,
              child: ProfileEditorPanel(
                profiles: const <ProfileRecord>[],
                providerDescriptors: const <ProviderDescriptor>[
                  _providerWithSettingsDescriptor,
                ],
                selectedProfileId: 'profile-1',
                draft: draft,
                busy: false,
                onSelectProfile: (_) {},
                onDraftChanged: (_) {},
                onSave: () async {},
                onDelete: () async {},
                onReset: () {},
                onResolve: () async {},
                onStart: () async {},
              ),
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Provider settings'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Provider settings'), findsOneWidget);
      expect(find.text('Region'), findsOneWidget);
      expect(find.text('Device PIN'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile profile editor shows fail-closed warning for unsupported schema',
    (WidgetTester tester) async {
      final baseDraft = ProfileDraft.defaults();
      final draft = baseDraft.copyWith(
        spec: baseDraft.spec.copyWith(
          provider: 'unsupported-provider',
          link: 'https://example.test/invite/abc',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 1400,
              child: ProfileEditorPanel(
                profiles: const <ProfileRecord>[],
                providerDescriptors: const <ProviderDescriptor>[
                  _unsupportedProviderSettingsDescriptor,
                ],
                selectedProfileId: 'profile-1',
                draft: draft,
                busy: false,
                onSelectProfile: (_) {},
                onDraftChanged: (_) {},
                onSave: () async {},
                onDelete: () async {},
                onReset: () {},
                onResolve: () async {},
                onStart: () async {},
              ),
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.textContaining('cannot render the provider settings schema'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('cannot render the provider settings schema'),
        findsOneWidget,
      );
    },
  );
}
