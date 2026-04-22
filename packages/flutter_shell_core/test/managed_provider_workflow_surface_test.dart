import 'package:flutter/material.dart';
import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_i18n.dart';

const ProviderDescriptor _providerWithSettingsDescriptor = ProviderDescriptor(
  id: 'vk',
  displayName: 'VK Calls',
  description: 'Managed provider workflow test fixture.',
  inputKind: ProviderInputKind.link,
  authPosture: ProviderAuthPosture.account,
  browserPolicy: ProviderBrowserPolicy.externalRequired,
  artifactFamilies: <ArtifactFamily>[ArtifactFamily.conferenceRoom],
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
    },
  ),
);

void main() {
  testWidgets('shared managed provider workflow renders the mobile variant', (
    WidgetTester tester,
  ) async {
    await pumpShellCoreLocalizedTestApp(
      tester,
      child: SizedBox(
        width: 900,
        height: 860,
        child: ManagedProviderWorkflowBody(
          variant: ManagedProviderWorkflowVariant.mobile,
          supportedProviders: const <SupportedProviderDefinition>[
            SupportedProviderDefinition(id: 'vk'),
          ],
          providerDescriptors: const <ProviderDescriptor>[
            _providerWithSettingsDescriptor,
          ],
          selectedManagedProviderId: null,
          draft: ManagedProviderDraft.defaults(
            provider: 'vk',
          ).copyWith(name: 'VK Starter'),
          busy: false,
          onDraftChanged: (_) {},
          nameFieldKey: const ValueKey<String>('shared-mobile-provider-name'),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('managed-provider-workflow-body')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('shared-mobile-provider-name')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('managed-provider-selected-family-card'),
      ),
      findsOneWidget,
    );
    expect(find.text('Reusable provider settings'), findsOneWidget);
  });

  testWidgets('shared managed provider workflow renders the desktop variant', (
    WidgetTester tester,
  ) async {
    await pumpShellCoreLocalizedTestApp(
      tester,
      child: SizedBox(
        width: 1280,
        height: 900,
        child: ManagedProviderWorkflowBody(
          variant: ManagedProviderWorkflowVariant.desktop,
          supportedProviders: const <SupportedProviderDefinition>[
            SupportedProviderDefinition(id: 'vk'),
          ],
          providerDescriptors: const <ProviderDescriptor>[
            _providerWithSettingsDescriptor,
          ],
          selectedManagedProviderId: 'provider-config-1',
          draft: ManagedProviderDraft.defaults(
            provider: 'vk',
          ).copyWith(name: 'VK Europe'),
          busy: false,
          onDraftChanged: (_) {},
          nameFieldKey: const ValueKey<String>('shared-desktop-provider-name'),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('managed-provider-workflow-body')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('shared-desktop-provider-name')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('managed-provider-selected-family-card'),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('managed-provider-descriptor-summary')),
      240,
      scrollable: find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('managed-provider-workflow-body'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('managed-provider-descriptor-summary')),
      findsOneWidget,
    );
  });
}
