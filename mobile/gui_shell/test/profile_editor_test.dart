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
        additionalProperties: true,
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
    'mobile profile editor progressively discloses provider and runtime sections',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
            body: SingleChildScrollView(
              child: SizedBox(
                width: 900,
                child: ProfileEditorPanel(
                  profiles: const <ProfileRecord>[],
                  providerDescriptors: const <ProviderDescriptor>[
                    _providerWithSettingsDescriptor,
                  ],
                  availableProviderConfigs: const <ProviderConfigRecord>[],
                  selectedProfileId: 'profile-1',
                  draft: draft,
                  busy: false,
                  onSelectProfile: (_) {},
                  onDraftChanged: (_) {},
                  onApplyProviderConfig: (_) {},
                  onSave: () async {},
                  onDelete: () async {},
                  onReset: () {},
                  onResolve: () async {},
                  onStart: () async {},
                  onPreparePortableExport: () => null,
                  onCopyPortableExportText: (_) async {},
                  onSharePortableExportText: (_) async {},
                  onSharePortableExportFile: (_) async {},
                  onImportPortableFromFile: () async => null,
                  onPreviewPortableImport: (_) => null,
                  onConfirmPortableImport: (_) async {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Provider settings'), findsOneWidget);
      expect(find.text('Region'), findsNothing);
      expect(find.text('Device PIN'), findsNothing);
      expect(find.text('TURN override'), findsNothing);

      await tester.tap(find.text('Provider settings'));
      await tester.pumpAndSettle();

      expect(find.text('Region'), findsOneWidget);
      expect(find.text('Device PIN'), findsOneWidget);

      await tester.ensureVisible(find.text('Advanced runtime controls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced runtime controls'));
      await tester.pumpAndSettle();

      expect(find.text('TURN override'), findsOneWidget);
      expect(find.text('Bind interface'), findsOneWidget);
    },
  );

  testWidgets(
    'mobile profile editor shows fail-closed warning for unsupported schema',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
            body: SingleChildScrollView(
              child: SizedBox(
                width: 900,
                child: ProfileEditorPanel(
                  profiles: const <ProfileRecord>[],
                  providerDescriptors: const <ProviderDescriptor>[
                    _unsupportedProviderSettingsDescriptor,
                  ],
                  availableProviderConfigs: const <ProviderConfigRecord>[],
                  selectedProfileId: 'profile-1',
                  draft: draft,
                  busy: false,
                  onSelectProfile: (_) {},
                  onDraftChanged: (_) {},
                  onApplyProviderConfig: (_) {},
                  onSave: () async {},
                  onDelete: () async {},
                  onReset: () {},
                  onResolve: () async {},
                  onStart: () async {},
                  onPreparePortableExport: () => null,
                  onCopyPortableExportText: (_) async {},
                  onSharePortableExportText: (_) async {},
                  onSharePortableExportFile: (_) async {},
                  onImportPortableFromFile: () async => null,
                  onPreviewPortableImport: (_) => null,
                  onConfirmPortableImport: (_) async {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.textContaining('cannot render the provider settings schema'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'mobile profile editor keeps the keyboard open when naming a managed profile',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final managedProvider = ManagedProviderRecord(
        id: 'provider-config-1',
        provider: 'wb-stream',
        name: 'WB Europe',
        providerSettings: const <String, dynamic>{'region': 'eu-west'},
        createdAt: DateTime.utc(2026, 4, 17, 12, 0),
        updatedAt: DateTime.utc(2026, 4, 17, 12, 1),
      );
      var draft = ProfileDraft.defaults();
      var showNotice = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    if (showNotice) ...<Widget>[
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Managed provider applied'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ProfileEditorPanel(
                      key: const ValueKey<String>('profile-editor-harness'),
                      profiles: const <ProfileRecord>[],
                      providerDescriptors: const <ProviderDescriptor>[
                        _providerWithSettingsDescriptor,
                      ],
                      managedProviders: <ManagedProviderRecord>[
                        managedProvider,
                      ],
                      initialManagedProviderId: managedProvider.id,
                      selectedProfileId: null,
                      draft: draft,
                      busy: false,
                      onSelectProfile: (_) {},
                      onDraftChanged: (ProfileDraft nextDraft) {
                        setState(() {
                          draft = nextDraft;
                          showNotice = false;
                        });
                      },
                      onActivateManagedProviderMode:
                          ({String? managedProviderId}) {
                            final selectedId =
                                managedProviderId ?? managedProvider.id;
                            expect(selectedId, managedProvider.id);
                            setState(() {
                              draft = draft.applyManagedProvider(
                                managedProvider,
                              );
                              showNotice = true;
                            });
                          },
                      onUseCustomProvider: () {
                        setState(() {
                          draft = draft.asCustomProvider();
                          showNotice = false;
                        });
                      },
                      onSave: () async {},
                      onDelete: () async {},
                      onReset: () {},
                      onResolve: () async {},
                      onStart: () async {},
                      onPreparePortableExport: () => null,
                      onCopyPortableExportText: (_) async {},
                      onSharePortableExportText: (_) async {},
                      onSharePortableExportFile: (_) async {},
                      onImportPortableFromFile: () async => null,
                      onPreviewPortableImport: (_) => null,
                      onConfirmPortableImport: (_) async {},
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Managed provider'));
      await tester.pumpAndSettle();

      expect(find.text('Managed provider applied'), findsOneWidget);

      final nameField = find.byKey(
        const ValueKey<String>('profile-editor-name-field'),
      );
      await tester.showKeyboard(nameField);
      await tester.pump();

      expect(tester.testTextInput.isVisible, isTrue);

      tester.testTextInput.enterText('a');
      await tester.pumpAndSettle();

      final editable = tester.state<EditableTextState>(
        find.descendant(of: nameField, matching: find.byType(EditableText)),
      );
      expect(find.text('Managed provider applied'), findsNothing);
      expect(editable.widget.controller.text, 'a');
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );
}
