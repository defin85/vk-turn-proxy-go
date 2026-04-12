import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:gui_shell/src/ui/profile_editor.dart';

const List<ProviderDescriptor> _providerDescriptors = <ProviderDescriptor>[
  ProviderDescriptor(
    id: 'vk',
    displayName: 'VK Calls',
    description:
        'Invite-first provider with browser-mediated continuation that resolves into transport-ready TURN credentials.',
    inputKind: ProviderInputKind.link,
    authPosture: ProviderAuthPosture.guestOrAccount,
    browserPolicy: ProviderBrowserPolicy.externalRequired,
    challengeModes: <ProviderChallengeMode>[ProviderChallengeMode.browser],
    artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
  ),
  ProviderDescriptor(
    id: 'generic-turn',
    displayName: 'Generic TURN',
    description:
        'Static TURN handoff for deterministic transport testing and operator-driven runtime startup.',
    inputKind: ProviderInputKind.link,
    authPosture: ProviderAuthPosture.staticSecret,
    browserPolicy: ProviderBrowserPolicy.notRequired,
    artifactFamilies: <ArtifactFamily>[ArtifactFamily.genericTurn],
  ),
];

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
  testWidgets('VK draft renders descriptor-driven browser workflow details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 1200,
            child: ProfileEditorPanel(
              providerDescriptors: _providerDescriptors,
              selectedProfileId: 'profile-1',
              draft: ProfileDraft.defaults(),
              busy: false,
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

    expect(find.text('VK Calls'), findsWidgets);
    expect(find.textContaining('external browser'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Operator-managed runtime defaults'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Operator-managed runtime defaults'), findsOneWidget);
    expect(find.text('Inspect or edit runtime defaults'), findsOneWidget);
    expect(find.text('Start saved profile'), findsOneWidget);
    expect(find.text('Local UDP listen'), findsNothing);

    await tester.tap(find.text('Inspect or edit runtime defaults'));
    await tester.pumpAndSettle();

    expect(find.text('Local UDP listen'), findsOneWidget);
    expect(find.text('Peer address'), findsOneWidget);
  });

  testWidgets('generic-turn draft renders static-secret descriptor details', (
    WidgetTester tester,
  ) async {
    final baseDraft = ProfileDraft.defaults();
    final draft = baseDraft.copyWith(
      spec: baseDraft.spec.copyWith(
        provider: 'generic-turn',
        link: 'generic-turn://turn-user:turn-pass@turn.example.test:3478',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 1200,
            child: ProfileEditorPanel(
              providerDescriptors: _providerDescriptors,
              selectedProfileId: 'profile-1',
              draft: draft,
              busy: false,
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

    expect(find.text('Generic TURN'), findsWidgets);
    expect(find.textContaining('static secret input'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Operator-managed runtime defaults'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Operator-managed runtime defaults'), findsOneWidget);
  });

  testWidgets('provider settings schema renders generic fields', (
    WidgetTester tester,
  ) async {
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
            height: 1200,
            child: ProfileEditorPanel(
              providerDescriptors: const <ProviderDescriptor>[
                _providerWithSettingsDescriptor,
              ],
              selectedProfileId: 'profile-1',
              draft: draft,
              busy: false,
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
  });

  testWidgets('unsupported provider settings schema renders blocking warning', (
    WidgetTester tester,
  ) async {
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
            height: 1200,
            child: ProfileEditorPanel(
              providerDescriptors: const <ProviderDescriptor>[
                _unsupportedProviderSettingsDescriptor,
              ],
              selectedProfileId: 'profile-1',
              draft: draft,
              busy: false,
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
  });
}
