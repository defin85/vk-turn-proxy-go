import 'package:flutter/material.dart';
import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_i18n.dart';

void main() {
  testWidgets(
    'home workflow body renders shared product sections and actions',
    (WidgetTester tester) async {
      var primaryPressed = 0;
      var supportPressed = 0;
      var diagnosticsPressed = 0;
      var choicePressed = 0;

      await pumpShellCoreLocalizedTestApp(
        tester,
        child: SingleChildScrollView(
          child: HomeWorkflowBody(
            profileSummary: const HomeWorkflowProfileSummaryData(
              eyebrow: 'Current profile',
              title: 'VPS',
              subtitle: 'vk -> 127.0.0.1:56000',
              caption: 'Listening on 127.0.0.1:9001',
            ),
            primaryAction: HomeWorkflowPrimaryActionData(
              tone: ShellSemanticTone.info,
              eyebrow: 'Main action',
              title: 'VPN is off',
              subtitle: 'Start the current path.',
              leadingIcon: Icons.power_rounded,
              primaryAction: HomeWorkflowAction(
                label: 'Turn on VPN',
                icon: Icons.power_settings_new_rounded,
                onPressed: () => primaryPressed += 1,
              ),
              secondaryActions: <HomeWorkflowAction>[
                HomeWorkflowAction(
                  label: 'Open profiles',
                  style: HomeWorkflowActionStyle.tonal,
                  onPressed: () => supportPressed += 1,
                ),
              ],
            ),
            modeSection: HomeWorkflowModeSectionData(
              title: 'Current mode',
              summary: 'Proxy only',
              detail: 'Routing is unavailable.',
              choiceGroups: <HomeWorkflowChoiceGroup>[
                HomeWorkflowChoiceGroup(
                  options: <HomeWorkflowChoiceOption>[
                    HomeWorkflowChoiceOption(
                      label: 'Proxy only',
                      selected: true,
                      onSelected: () => choicePressed += 1,
                    ),
                  ],
                ),
              ],
            ),
            supportSection: HomeWorkflowSupportSectionData(
              title: 'Need deeper detail?',
              summary: 'Resolutions: 0, sessions: 0.',
              actions: <HomeWorkflowAction>[
                HomeWorkflowAction(
                  label: 'Open activity',
                  style: HomeWorkflowActionStyle.tonal,
                  onPressed: () => supportPressed += 1,
                ),
                HomeWorkflowAction(
                  label: 'Open diagnostics',
                  style: HomeWorkflowActionStyle.outlined,
                  onPressed: () => diagnosticsPressed += 1,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Current profile'), findsOneWidget);
      expect(find.text('VPS'), findsOneWidget);
      expect(find.text('Main action'), findsOneWidget);
      expect(find.text('Current mode'), findsOneWidget);
      expect(find.text('Need deeper detail?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Turn on VPN'));
      await tester.pump();
      final openActivity = find.widgetWithText(FilledButton, 'Open activity');
      await tester.ensureVisible(openActivity);
      await tester.tap(openActivity);
      await tester.pump();
      final openDiagnostics = find.widgetWithText(
        OutlinedButton,
        'Open diagnostics',
      );
      await tester.ensureVisible(openDiagnostics);
      await tester.tap(openDiagnostics);
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Proxy only'));
      await tester.pump();

      expect(primaryPressed, 1);
      expect(supportPressed, 1);
      expect(diagnosticsPressed, 1);
      expect(choicePressed, 1);
    },
  );

  testWidgets('home workflow body renders notice and empty-state actions', (
    WidgetTester tester,
  ) async {
    var resetPressed = 0;
    var addPressed = 0;

    await pumpShellCoreLocalizedTestApp(
      tester,
      child: SingleChildScrollView(
        child: HomeWorkflowBody(
          noticeMessage: 'Local state needs reset.',
          noticeAction: HomeWorkflowAction(
            label: 'Reset local state',
            style: HomeWorkflowActionStyle.outlined,
            onPressed: () => resetPressed += 1,
          ),
          emptyState: HomeWorkflowEmptyStateData(
            title: 'No saved profiles yet',
            message: 'Create or import a profile to continue.',
            actions: <HomeWorkflowAction>[
              HomeWorkflowAction(
                label: 'Add profile',
                onPressed: () => addPressed += 1,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Local state needs reset.'), findsOneWidget);
    expect(find.text('No saved profiles yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset local state'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add profile'));
    await tester.pump();

    expect(resetPressed, 1);
    expect(addPressed, 1);
  });
}
