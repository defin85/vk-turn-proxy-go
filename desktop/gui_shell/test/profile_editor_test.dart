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
    final baseDraft = ProfileDraft.defaults();
    final draft = baseDraft.copyWith(
      spec: baseDraft.spec.copyWith(
        provider: 'vk',
        link: 'https://vk.com/call/join/test',
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
              availableProviderConfigs: const <ProviderConfigRecord>[],
              selectedProfileId: 'profile-1',
              draft: draft,
              busy: false,
              onDraftChanged: (_) {},
              onApplyProviderConfig: (_) {},
              onSave: () async {},
              onDelete: () async {},
              onReset: () {},
              onResolve: () async {},
              onStart: () async {},
              onPreparePortableExport: () => null,
              onCopyPortableExportText: (_) async {},
              onSavePortableExportFile: (_) async {},
              onImportPortableFromFile: () async => null,
              onPreviewPortableImport: (_) => null,
              onConfirmPortableImport: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Advanced runtime controls'),
      300,
      scrollable: _profileWorkspaceScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced runtime controls'));
    await tester.pumpAndSettle();

    expect(find.text('Advanced runtime controls'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('profile-start-action')),
      findsOneWidget,
    );
    expect(find.text('Local UDP listen'), findsOneWidget);
    expect(find.text('Peer address'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Provider details'),
      300,
      scrollable: _profileWorkspaceScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Provider details'));
    await tester.pumpAndSettle();

    expect(find.text('VK Calls'), findsWidgets);
    expect(
      find.textContaining('requires an external browser when challenge'),
      findsOneWidget,
    );
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
              availableProviderConfigs: const <ProviderConfigRecord>[],
              selectedProfileId: 'profile-1',
              draft: draft,
              busy: false,
              onDraftChanged: (_) {},
              onApplyProviderConfig: (_) {},
              onSave: () async {},
              onDelete: () async {},
              onReset: () {},
              onResolve: () async {},
              onStart: () async {},
              onPreparePortableExport: () => null,
              onCopyPortableExportText: (_) async {},
              onSavePortableExportFile: (_) async {},
              onImportPortableFromFile: () async => null,
              onPreviewPortableImport: (_) => null,
              onConfirmPortableImport: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Advanced runtime controls'),
      300,
      scrollable: _profileWorkspaceScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced runtime controls'));
    await tester.pumpAndSettle();

    expect(find.text('Advanced runtime controls'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Provider details'),
      300,
      scrollable: _profileWorkspaceScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Provider details'));
    await tester.pumpAndSettle();

    expect(find.text('Generic TURN'), findsWidgets);
    expect(find.textContaining('static secret input'), findsOneWidget);
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
              availableProviderConfigs: const <ProviderConfigRecord>[],
              selectedProfileId: 'profile-1',
              draft: draft,
              busy: false,
              onDraftChanged: (_) {},
              onApplyProviderConfig: (_) {},
              onSave: () async {},
              onDelete: () async {},
              onReset: () {},
              onResolve: () async {},
              onStart: () async {},
              onPreparePortableExport: () => null,
              onCopyPortableExportText: (_) async {},
              onSavePortableExportFile: (_) async {},
              onImportPortableFromFile: () async => null,
              onPreviewPortableImport: (_) => null,
              onConfirmPortableImport: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Provider settings'),
      300,
      scrollable: _profileWorkspaceScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Provider settings'));
    await tester.pumpAndSettle();

    expect(find.text('Provider settings'), findsOneWidget);
    expect(find.text('Region'), findsOneWidget);
    expect(find.text('Device PIN'), findsOneWidget);
  });

  testWidgets('desktop lane uses desktop workflow before the old 1100 cutoff', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final baseDraft = ProfileDraft.defaults();
    final draft = baseDraft.copyWith(
      name: 'alpha',
      providerBinding: const ProfileProviderBinding(
        mode: ProfileProviderMode.managed,
        managedProviderId: 'provider-1',
      ),
      spec: baseDraft.spec.copyWith(
        provider: 'vk',
        link: 'https://vk.com/call/join/test',
      ),
    );
    final timestamp = DateTime(2026);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1080,
            height: 900,
            child: ProfileEditorPanel(
              providerDescriptors: _providerDescriptors,
              managedProviders: <ManagedProviderRecord>[
                ManagedProviderRecord(
                  id: 'provider-1',
                  provider: 'vk',
                  name: 'Test1',
                  providerSettings: const <String, dynamic>{},
                  createdAt: timestamp,
                  updatedAt: timestamp,
                ),
              ],
              initialManagedProviderId: 'provider-1',
              selectedProfileId: 'profile-1',
              draft: draft,
              busy: false,
              onDraftChanged: (_) {},
              onActivateManagedProviderMode: ({String? managedProviderId}) {},
              onUseCustomProvider: () {},
              onSave: () async {},
              onDelete: () async {},
              onReset: () {},
              onResolve: () async {},
              onStart: () async {},
              onPreparePortableExport: () => null,
              onCopyPortableExportText: (_) async {},
              onSavePortableExportFile: (_) async {},
              onImportPortableFromFile: () async => null,
              onPreviewPortableImport: (_) => null,
              onConfirmPortableImport: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Runtime defaults'), findsOneWidget);
    expect(find.text('Provider mode'), findsNothing);
    expect(find.text('Advanced runtime controls'), findsNothing);
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
              availableProviderConfigs: const <ProviderConfigRecord>[],
              selectedProfileId: 'profile-1',
              draft: draft,
              busy: false,
              onDraftChanged: (_) {},
              onApplyProviderConfig: (_) {},
              onSave: () async {},
              onDelete: () async {},
              onReset: () {},
              onResolve: () async {},
              onStart: () async {},
              onPreparePortableExport: () => null,
              onCopyPortableExportText: (_) async {},
              onSavePortableExportFile: (_) async {},
              onImportPortableFromFile: () async => null,
              onPreviewPortableImport: (_) => null,
              onConfirmPortableImport: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Provider settings'),
      300,
      scrollable: _profileWorkspaceScrollable(),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('cannot render the provider settings schema'),
      findsOneWidget,
    );
  });

  testWidgets('secondary profile actions live in the overflow menu', (
    WidgetTester tester,
  ) async {
    final baseDraft = ProfileDraft.defaults();
    final draft = baseDraft.copyWith(
      name: 'alpha',
      spec: baseDraft.spec.copyWith(
        provider: 'vk',
        link: 'https://vk.com/call/join/test',
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
              availableProviderConfigs: const <ProviderConfigRecord>[],
              selectedProfileId: 'profile-1',
              draft: draft,
              busy: false,
              onDraftChanged: (_) {},
              onApplyProviderConfig: (_) {},
              onSave: () async {},
              onDelete: () async {},
              onReset: () {},
              onResolve: () async {},
              onStart: () async {},
              onPreparePortableExport: () => null,
              onCopyPortableExportText: (_) async {},
              onSavePortableExportFile: (_) async {},
              onImportPortableFromFile: () async => null,
              onPreviewPortableImport: (_) => null,
              onConfirmPortableImport: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('profile-portable-export-action')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-reset-action')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('profile-editor-more-actions-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('profile-reset-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-portable-export-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-portable-import-file-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('profile-portable-import-paste-action'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-delete-action')),
      findsOneWidget,
    );
  });
}

Finder _profileWorkspaceScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey<String>('profile-workspace-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
}
