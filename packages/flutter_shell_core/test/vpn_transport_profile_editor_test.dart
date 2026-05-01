import 'package:flutter/material.dart';
import 'package:flutter_shell_core/src/control/runtime_execution_planning.dart';
import 'package:flutter_shell_core/vpn_transport_profile_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creates a generated-key draft and shows saved public key', (
    WidgetTester tester,
  ) async {
    TransportProfileStructuredDraft? savedDraft;
    var validateCalls = 0;

    await tester.pumpWidget(
      _EditorHarness(
        onValidate:
            (TransportProfileStructuredValidationRequest request) async {
              validateCalls += 1;
              return const TransportProfileStructuredValidationResult(
                valid: true,
              );
            },
        onSave: (TransportProfileStructuredDraft draft) async {
          savedDraft = draft;
          return TransportProfileStructuredSaveResult(
            profile: _status(),
            generatedKeys: const <TransportProfileGeneratedKey>[
              TransportProfileGeneratedKey(
                kind: TransportProfileKind.wireGuardNativeV1,
                field: TransportProfileStructuredFieldId.interfacePrivateKey,
                publicKey: 'saved-public-key',
                fingerprint: 'sha256:saved-public-key',
              ),
            ],
          );
        },
      ),
    );

    await tester.enterText(
      find.byKey(
        const ValueKey<String>('vpn-profile-editor-interface_addresses'),
      ),
      '10.45.0.2/32',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('vpn-profile-editor-peer_public_key')),
      'peer-public-key',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('vpn-profile-editor-endpoint')),
      '198.51.100.10:51820',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey<String>('vpn-profile-editor-peer_preshared_key'),
      ),
      'submitted-psk',
    );

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(validateCalls, 1);
    expect(
      savedDraft?.secretActions[TransportProfileStructuredFieldId
          .interfacePrivateKey],
      TransportProfileSecretUpdateAction.generateHost,
    );
    expect(
      savedDraft?.secretActions[TransportProfileStructuredFieldId
          .peerPresharedKey],
      TransportProfileSecretUpdateAction.replaceSubmitted,
    );
    expect(
      savedDraft?.fields[TransportProfileStructuredFieldId.interfaceAddresses],
      <String>['10.45.0.2/32'],
    );
    expect(
      savedDraft?.fields[TransportProfileStructuredFieldId.peerPublicKey],
      'peer-public-key',
    );
    expect(find.text('saved-public-key'), findsOneWidget);
    expect(_textFor(tester, 'vpn-profile-editor-peer_preshared_key'), isEmpty);
  });

  testWidgets(
    'shows field errors and clears submitted secrets on validation failure',
    (WidgetTester tester) async {
      var saveCalled = false;

      await tester.pumpWidget(
        _EditorHarness(
          mode: VPNTransportProfileEditorMode.edit,
          existingProfile: _status(),
          onValidate:
              (TransportProfileStructuredValidationRequest request) async {
                return const TransportProfileStructuredValidationResult(
                  valid: false,
                  errors: <TransportProfileFieldValidationError>[
                    TransportProfileFieldValidationError(
                      field: TransportProfileStructuredFieldId.allowedIps,
                      violation: 'malformed',
                      message: 'Allowed IPs are malformed',
                    ),
                  ],
                );
              },
          onSave: (TransportProfileStructuredDraft draft) async {
            saveCalled = true;
            return TransportProfileStructuredSaveResult(profile: _status());
          },
        ),
      );

      await _selectSecretAction(
        tester,
        TransportProfileStructuredFieldId.interfacePrivateKey,
        'Replace',
      );
      await _selectSecretAction(
        tester,
        TransportProfileStructuredFieldId.peerPresharedKey,
        'Replace',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('vpn-profile-editor-interface_private_key'),
        ),
        'submitted-private-key',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('vpn-profile-editor-peer_preshared_key'),
        ),
        'submitted-psk',
      );
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(saveCalled, isFalse);
      expect(find.text('Allowed IPs are malformed'), findsOneWidget);
      expect(
        _textFor(tester, 'vpn-profile-editor-interface_private_key'),
        isEmpty,
      );
      expect(
        _textFor(tester, 'vpn-profile-editor-peer_preshared_key'),
        isEmpty,
      );
    },
  );

  testWidgets('renders and saves an artificial non-WireGuard schema', (
    WidgetTester tester,
  ) async {
    TransportProfileStructuredDraft? savedDraft;
    const certificateField = TransportProfileStructuredFieldId('certificate');

    await tester.pumpWidget(
      _EditorHarness(
        schema: const TransportProfileEditableKindSchema(
          kind: TransportProfileKind('future_native_v1'),
          schemaVersion: 'future_native_v1.editor.v1',
          lifecycleActions: <TransportProfileLifecycleAction>[
            TransportProfileLifecycleAction.createStructured,
            TransportProfileLifecycleAction.validateDraft,
          ],
          fields: <TransportProfileStructuredFieldDescriptor>[
            TransportProfileStructuredFieldDescriptor(
              id: certificateField,
              valueKind: TransportProfileStructuredFieldValueKind.string,
              displayName: 'Certificate',
              supported: true,
            ),
          ],
        ),
        onValidate:
            (TransportProfileStructuredValidationRequest request) async {
              return const TransportProfileStructuredValidationResult(
                valid: true,
              );
            },
        onSave: (TransportProfileStructuredDraft draft) async {
          savedDraft = draft;
          return TransportProfileStructuredSaveResult(
            profile: _status(
              kind: const TransportProfileKind('future_native_v1'),
            ),
          );
        },
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('vpn-profile-editor-certificate')),
      'future-cert',
    );
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(savedDraft?.kind, const TransportProfileKind('future_native_v1'));
    expect(savedDraft?.fields[certificateField], 'future-cert');
    expect(savedDraft?.toJson().containsKey('peer_public_key'), isFalse);
  });

  testWidgets('blocks unsupported schema fields without saving', (
    WidgetTester tester,
  ) async {
    var saveCalled = false;

    await tester.pumpWidget(
      _EditorHarness(
        schema: const TransportProfileEditableKindSchema(
          kind: TransportProfileKind('future_native_v1'),
          schemaVersion: 'future_native_v1.editor.v1',
          lifecycleActions: <TransportProfileLifecycleAction>[
            TransportProfileLifecycleAction.createStructured,
          ],
          fields: <TransportProfileStructuredFieldDescriptor>[
            TransportProfileStructuredFieldDescriptor(
              id: TransportProfileStructuredFieldId('opaque_blob'),
              valueKind: TransportProfileStructuredFieldValueKind(
                'binary_blob',
              ),
              displayName: 'Opaque blob',
              supported: true,
            ),
          ],
        ),
        onValidate:
            (TransportProfileStructuredValidationRequest request) async {
              return const TransportProfileStructuredValidationResult(
                valid: true,
              );
            },
        onSave: (TransportProfileStructuredDraft draft) async {
          saveCalled = true;
          return TransportProfileStructuredSaveResult(
            profile: _status(
              kind: const TransportProfileKind('future_native_v1'),
            ),
          );
        },
      ),
    );

    expect(find.text('Profile schema is not supported'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('vpn-profile-editor-save')),
          )
          .onPressed,
      isNull,
    );
    expect(saveCalled, isFalse);
  });

  testWidgets('manager filters multiple profiles without owning VPN startup', (
    WidgetTester tester,
  ) async {
    var selectedProfile = '';
    var editedProfile = '';
    var validatedProfile = '';
    var forgottenProfile = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VPNTransportProfileManagerSurface(
            variant: VPNTransportProfileEditorVariant.desktop,
            profiles: <TransportProfileStatus>[
              _status(
                id: 'wg-profile',
                displayName: 'Phone WireGuard',
                actions: const <TransportProfileLifecycleAction>[
                  TransportProfileLifecycleAction.selectForStartup,
                  TransportProfileLifecycleAction.updateStructured,
                  TransportProfileLifecycleAction.validate,
                  TransportProfileLifecycleAction.forget,
                ],
              ),
              _status(
                id: 'future-profile',
                kind: const TransportProfileKind('future_native_v1'),
                displayName: 'Future native',
              ),
            ],
            requiredKinds: const <TransportProfileKind>[
              TransportProfileKind.wireGuardNativeV1,
            ],
            executionPlan: _androidVPNServicePlan,
            onCreate: () async {},
            onImport: () async {},
            onSelect: (TransportProfileStatus profile) async {
              selectedProfile = profile.id;
            },
            onEdit: (TransportProfileStatus profile) async {
              editedProfile = profile.id;
            },
            onValidate: (TransportProfileStatus profile) async {
              validatedProfile = profile.id;
            },
            onForget: (TransportProfileStatus profile) async {
              forgottenProfile = profile.id;
            },
          ),
        ),
      ),
    );

    expect(find.text('Phone WireGuard'), findsOneWidget);
    expect(find.text('Future native'), findsNothing);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
    expect(find.text('Disconnect'), findsNothing);
    expect(find.text('Start VPN'), findsNothing);
    expect(find.text('Stop VPN'), findsNothing);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('vpn-profile-manager-select-wg-profile'),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('vpn-profile-manager-edit-wg-profile')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('vpn-profile-manager-validate-wg-profile'),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('vpn-profile-manager-forget-wg-profile'),
      ),
    );
    await tester.pump();

    expect(selectedProfile, 'wg-profile');
    expect(editedProfile, 'wg-profile');
    expect(validatedProfile, 'wg-profile');
    expect(forgottenProfile, 'wg-profile');
  });
}

class _EditorHarness extends StatelessWidget {
  const _EditorHarness({
    required this.onValidate,
    required this.onSave,
    this.mode = VPNTransportProfileEditorMode.create,
    this.existingProfile,
    this.schema,
  });

  final VPNTransportProfileEditorMode mode;
  final TransportProfileStatus? existingProfile;
  final TransportProfileEditableKindSchema? schema;
  final Future<TransportProfileStructuredValidationResult> Function(
    TransportProfileStructuredValidationRequest request,
  )
  onValidate;
  final Future<TransportProfileStructuredSaveResult> Function(
    TransportProfileStructuredDraft draft,
  )
  onSave;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: VPNTransportProfileEditorSurface(
          variant: VPNTransportProfileEditorVariant.mobile,
          mode: mode,
          schema: schema ?? _schema(),
          existingProfile: existingProfile,
          onValidate: onValidate,
          onSave: onSave,
        ),
      ),
    );
  }
}

TransportProfileEditableKindSchema _schema() {
  return const TransportProfileEditableKindSchema(
    kind: TransportProfileKind.wireGuardNativeV1,
    schemaVersion: 'wireguard_native_v1.structured_editor.v1',
    lifecycleActions: <TransportProfileLifecycleAction>[
      TransportProfileLifecycleAction.createStructured,
      TransportProfileLifecycleAction.updateStructured,
      TransportProfileLifecycleAction.validateDraft,
      TransportProfileLifecycleAction.generateKey,
    ],
    fields: <TransportProfileStructuredFieldDescriptor>[
      TransportProfileStructuredFieldDescriptor(
        id: TransportProfileStructuredFieldId.displayName,
        valueKind: TransportProfileStructuredFieldValueKind.string,
        displayName: 'Name',
        supported: true,
      ),
      TransportProfileStructuredFieldDescriptor(
        id: TransportProfileStructuredFieldId.interfacePrivateKey,
        valueKind: TransportProfileStructuredFieldValueKind.secretString,
        displayName: 'Private key',
        required: true,
        secret: true,
        generated: true,
        updatePreservable: true,
        supported: true,
        secretUpdateActions: <TransportProfileSecretUpdateAction>[
          TransportProfileSecretUpdateAction.preserveExisting,
          TransportProfileSecretUpdateAction.replaceSubmitted,
          TransportProfileSecretUpdateAction.generateHost,
        ],
      ),
      TransportProfileStructuredFieldDescriptor(
        id: TransportProfileStructuredFieldId.interfaceAddresses,
        valueKind: TransportProfileStructuredFieldValueKind.stringList,
        displayName: 'Interface addresses',
        required: true,
        supported: true,
      ),
      TransportProfileStructuredFieldDescriptor(
        id: TransportProfileStructuredFieldId.dnsServers,
        valueKind: TransportProfileStructuredFieldValueKind.stringList,
        displayName: 'DNS servers',
        supported: true,
      ),
      TransportProfileStructuredFieldDescriptor(
        id: TransportProfileStructuredFieldId.mtu,
        valueKind: TransportProfileStructuredFieldValueKind.integer,
        displayName: 'MTU',
        defaultInteger: 1280,
        supported: true,
      ),
      TransportProfileStructuredFieldDescriptor(
        id: TransportProfileStructuredFieldId.peerPublicKey,
        valueKind: TransportProfileStructuredFieldValueKind.string,
        displayName: 'Peer public key',
        required: true,
        supported: true,
      ),
      TransportProfileStructuredFieldDescriptor(
        id: TransportProfileStructuredFieldId.peerPresharedKey,
        valueKind: TransportProfileStructuredFieldValueKind.secretString,
        displayName: 'Peer preshared key',
        secret: true,
        updatePreservable: true,
        supported: true,
        secretUpdateActions: <TransportProfileSecretUpdateAction>[
          TransportProfileSecretUpdateAction.preserveExisting,
          TransportProfileSecretUpdateAction.replaceSubmitted,
        ],
      ),
      TransportProfileStructuredFieldDescriptor(
        id: TransportProfileStructuredFieldId.allowedIps,
        valueKind: TransportProfileStructuredFieldValueKind.stringList,
        displayName: 'Allowed IPs',
        required: true,
        defaultStringList: <String>['0.0.0.0/0'],
        supported: true,
      ),
      TransportProfileStructuredFieldDescriptor(
        id: TransportProfileStructuredFieldId.endpoint,
        valueKind: TransportProfileStructuredFieldValueKind.string,
        displayName: 'Endpoint',
        required: true,
        supported: true,
      ),
      TransportProfileStructuredFieldDescriptor(
        id: TransportProfileStructuredFieldId.persistentKeepalive,
        valueKind: TransportProfileStructuredFieldValueKind.integer,
        displayName: 'Persistent keepalive',
        supported: true,
      ),
    ],
  );
}

TransportProfileStatus _status({
  String id = 'profile-1',
  TransportProfileKind kind = TransportProfileKind.wireGuardNativeV1,
  String displayName = 'WireGuard',
  List<TransportProfileLifecycleAction> actions =
      const <TransportProfileLifecycleAction>[],
  List<TransportProfileDefaultBinding> defaultFor =
      const <TransportProfileDefaultBinding>[],
}) {
  final now = DateTime.utc(2026);
  return TransportProfileStatus(
    id: id,
    kind: kind,
    version: 'v1',
    displayName: displayName,
    validation: const TransportProfileValidationStatus(
      state: TransportProfileValidationState.valid,
    ),
    compatibility: const TransportProfileCompatibilityStatus(
      state: TransportProfileCompatibilityState.compatible,
    ),
    secretMaterialRef: const TransportProfileSecretMaterialRef(
      kind: TransportProfileMaterialSource.structuredEditor,
      ref: 'secret-ref',
    ),
    actions: actions,
    defaultFor: defaultFor,
    importedAt: now,
    updatedAt: now,
  );
}

const _androidVPNServicePlan = RuntimeExecutionPlan(
  accessMethod: RuntimeAccessMethod.turnCredentials,
  carrierFamily: RuntimeCarrierFamily.turnDatagram,
  engineFamily: RuntimeEngineFamily.wireguardNative,
  hostAdapter: RuntimeHostAdapter.androidVpnService,
);

String _textFor(WidgetTester tester, String key) {
  final field = tester.widget<TextField>(find.byKey(ValueKey<String>(key)));
  return field.controller?.text ?? '';
}

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.byKey(const ValueKey<String>('vpn-profile-editor-save'));
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save);
}

Future<void> _selectSecretAction(
  WidgetTester tester,
  TransportProfileStructuredFieldId field,
  String label,
) async {
  final action = find.byKey(
    ValueKey<String>('vpn-profile-editor-${field.value}-action'),
  );
  await tester.ensureVisible(action);
  await tester.pump();
  await tester.tap(action);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
