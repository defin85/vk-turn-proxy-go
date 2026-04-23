import 'package:flutter/material.dart';
import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_i18n.dart';

void main() {
  testWidgets('shared saved-profile library surface renders desktop framing', (
    WidgetTester tester,
  ) async {
    await pumpShellCoreLocalizedTestApp(
      tester,
      child: SizedBox(
        width: 800,
        height: 640,
        child: SavedProfilesLibrarySurface(
          variant: WorkflowLibrarySurfaceVariant.desktop,
          profiles: const <ProfileRecord>[],
          activeProfileId: null,
          header: const WorkflowSectionHeaderData(
            title: 'Saved profiles',
            subtitle: 'Choose an invite or draft from the shared library.',
          ),
          headerAction: FilledButton(
            onPressed: () {},
            child: const Text('New draft'),
          ),
          hint: const WorkflowHintData(
            icon: Icons.fact_check_outlined,
            title: 'Return path stays explicit',
            message:
                'Desktop keeps the route switcher outside the shared list.',
          ),
          emptyState: const WorkflowEmptyStateData(
            message: 'No saved profiles yet.',
          ),
          itemBuilder:
              (BuildContext context, ProfileRecord profile, bool active) =>
                  const SizedBox.shrink(),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>('saved-profiles-library-surface-desktop'),
      ),
      findsOneWidget,
    );
    expect(find.text('Saved profiles'), findsOneWidget);
    expect(find.text('New draft'), findsOneWidget);
    expect(find.text('Return path stays explicit'), findsOneWidget);
    expect(find.text('No saved profiles yet.'), findsOneWidget);
  });

  testWidgets('shared managed-provider library surface renders mobile rows', (
    WidgetTester tester,
  ) async {
    await pumpShellCoreLocalizedTestApp(
      tester,
      child: SizedBox(
        width: 420,
        child: ManagedProvidersLibrarySurface(
          variant: WorkflowLibrarySurfaceVariant.mobile,
          managedProviders: <ManagedProviderRecord>[
            ManagedProviderRecord(
              id: 'provider-1',
              provider: 'vk',
              name: 'VK Europe',
              providerSettings: const <String, dynamic>{'region': 'eu-west'},
              createdAt: DateTime.utc(2026, 4, 23, 10, 0),
              updatedAt: DateTime.utc(2026, 4, 23, 10, 1),
            ),
            ManagedProviderRecord(
              id: 'provider-2',
              provider: 'generic-turn',
              name: 'Static TURN',
              providerSettings: const <String, dynamic>{},
              createdAt: DateTime.utc(2026, 4, 23, 10, 2),
              updatedAt: DateTime.utc(2026, 4, 23, 10, 3),
            ),
          ],
          activeManagedProviderId: 'provider-2',
          emptyState: const WorkflowEmptyStateData(
            title: 'No saved providers yet',
            message: 'Create one from the shared workflow root.',
          ),
          itemBuilder:
              (
                BuildContext context,
                ManagedProviderRecord provider,
                bool active,
              ) => ListTile(
                key: ValueKey<String>('managed-provider-row-${provider.id}'),
                title: Text(provider.name),
                trailing: active ? const Icon(Icons.check) : null,
              ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>('managed-providers-library-surface-mobile'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('managed-provider-row-provider-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('managed-provider-row-provider-2')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
