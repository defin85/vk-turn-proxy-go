import 'package:flutter/material.dart';
import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_shell_i18n/flutter_shell_i18n.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_i18n.dart';

const ProviderDescriptor _providerWithSettingsDescriptor = ProviderDescriptor(
  id: 'wb-stream',
  displayName: 'WB Stream',
  description: 'Descriptor-driven provider settings test fixture.',
  inputKind: ProviderInputKind.link,
  authPosture: ProviderAuthPosture.account,
  browserPolicy: ProviderBrowserPolicy.externalRequired,
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

void main() {
  testWidgets('shared profile workflow body renders the mobile variant', (
    WidgetTester tester,
  ) async {
    final baseDraft = ProfileDraft.defaults();
    final draft = baseDraft.copyWith(
      spec: baseDraft.spec.copyWith(
        provider: 'wb-stream',
        link: 'https://wb.example.test/invite/abc',
      ),
    );

    await pumpShellCoreLocalizedTestApp(
      tester,
      child: SingleChildScrollView(
        child: SizedBox(
          width: 900,
          child: ProfileWorkflowBody(
            variant: ProfileWorkflowVariant.mobile,
            providerDescriptors: const <ProviderDescriptor>[
              _providerWithSettingsDescriptor,
            ],
            managedProviders: const <ManagedProviderRecord>[],
            selectedProfileId: 'profile-1',
            draft: draft,
            busy: false,
            onDraftChanged: (_) {},
            onActivateManagedProviderMode: ({String? managedProviderId}) {},
            onUseCustomProvider: () {},
            leadingChildren: const <Widget>[Text('Saved profiles slot')],
            bottomChildren: const <Widget>[Text('Footer slot')],
            nameFieldKey: ValueKey<String>('shared-mobile-name-field'),
            providerFieldKey: ValueKey<String>('shared-mobile-provider-field'),
          ),
        ),
      ),
    );

    expect(find.text('Saved profiles slot'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('shared-mobile-name-field')),
      findsOneWidget,
    );
    expect(find.text('Provider details'), findsOneWidget);

    await tester.tap(find.text('Provider details'));
    await tester.pumpAndSettle();

    final copy = tester.element(find.byType(MaterialApp)).shellText;
    final labels = tester
        .widgetList<ShellToneBadge>(find.byType(ShellToneBadge))
        .map((ShellToneBadge badge) => badge.label)
        .toList(growable: false);

    expect(
      labels,
      contains(
        copy.tagBrowser(_providerWithSettingsDescriptor.browserPolicy.label),
      ),
    );
    expect(find.text('Footer slot'), findsOneWidget);
  });

  testWidgets('shared profile workflow body renders the desktop variant', (
    WidgetTester tester,
  ) async {
    final baseDraft = ProfileDraft.defaults();
    final draft = baseDraft.copyWith(
      spec: baseDraft.spec.copyWith(
        provider: 'wb-stream',
        link: 'https://wb.example.test/invite/abc',
      ),
      providerBinding: const ProfileProviderBinding(
        mode: ProfileProviderMode.managed,
        managedProviderId: 'provider-config-1',
      ),
    );

    await pumpShellCoreLocalizedTestApp(
      tester,
      child: SingleChildScrollView(
        child: SizedBox(
          width: 1400,
          child: ProfileWorkflowBody(
            variant: ProfileWorkflowVariant.desktop,
            providerDescriptors: const <ProviderDescriptor>[
              _providerWithSettingsDescriptor,
            ],
            managedProviders: <ManagedProviderRecord>[
              ManagedProviderRecord(
                id: 'provider-config-1',
                provider: 'wb-stream',
                name: 'WB Europe',
                providerSettings: const <String, dynamic>{'region': 'eu-west'},
                createdAt: DateTime.utc(2026, 4, 12, 18, 0),
                updatedAt: DateTime.utc(2026, 4, 12, 18, 1),
              ),
            ],
            selectedManagedProviderId: 'provider-config-1',
            selectedProfileId: 'profile-1',
            draft: draft,
            busy: false,
            onDraftChanged: (_) {},
            onActivateManagedProviderMode: ({String? managedProviderId}) {},
            onUseCustomProvider: () {},
            trailingChildren: const <Widget>[Text('Desktop trailing slot')],
            nameFieldKey: ValueKey<String>('shared-desktop-name-field'),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('shared-desktop-name-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-provider-record-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-managed-provider-family')),
      findsOneWidget,
    );
    expect(find.text('Desktop trailing slot'), findsOneWidget);
    expect(find.text('Runtime defaults'), findsOneWidget);
  });

  testWidgets('connections field can be cleared before entering a new value', (
    WidgetTester tester,
  ) async {
    var draft = ProfileDraft.defaults();

    await pumpShellCoreLocalizedTestApp(
      tester,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return SingleChildScrollView(
            child: SizedBox(
              width: 900,
              child: ProfileWorkflowBody(
                variant: ProfileWorkflowVariant.mobile,
                providerDescriptors: const <ProviderDescriptor>[],
                managedProviders: const <ManagedProviderRecord>[],
                draft: draft,
                busy: false,
                onDraftChanged: (ProfileDraft next) {
                  setState(() {
                    draft = next;
                  });
                },
                onActivateManagedProviderMode: ({String? managedProviderId}) {},
                onUseCustomProvider: () {},
              ),
            ),
          );
        },
      ),
    );

    await tester.ensureVisible(find.text('Advanced runtime controls'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced runtime controls'));
    await tester.pumpAndSettle();

    final connectionsField = find.byWidgetPredicate((Widget widget) {
      return widget is TextField &&
          widget.decoration?.labelText == 'Connections';
    });
    expect(connectionsField, findsOneWidget);
    expect(tester.widget<TextField>(connectionsField).controller?.text, '1');

    await tester.enterText(connectionsField, '');
    await tester.pump();

    expect(tester.widget<TextField>(connectionsField).controller?.text, '');
    expect(draft.spec.connections, 1);

    await tester.enterText(connectionsField, '4');
    await tester.pump();

    expect(tester.widget<TextField>(connectionsField).controller?.text, '4');
    expect(draft.spec.connections, 4);
  });
}
