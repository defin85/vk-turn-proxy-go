import 'package:flutter/material.dart';
import 'package:flutter_shell_core/flutter_shell_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_i18n.dart';

void main() {
  testWidgets('support resolutions surface renders mobile empty state', (
    WidgetTester tester,
  ) async {
    await pumpShellCoreLocalizedTestApp(
      tester,
      child: SizedBox(
        width: 420,
        height: 360,
        child: SupportResolutionsSurface(
          variant: SupportContentSurfaceVariant.mobile,
          resolutions: const <ResolutionRecord>[],
          selectedResolutionId: null,
          busy: false,
          challengeForResolution: (_) => null,
          actionsForResolution:
              (ResolutionRecord resolution, ChallengeRecord? challenge) =>
                  SupportResolutionActions(onSelect: () {}),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('support-resolutions-surface-mobile')),
      findsOneWidget,
    );
    expect(find.text('Resolutions'), findsOneWidget);
  });

  testWidgets('support sessions surface renders desktop empty state', (
    WidgetTester tester,
  ) async {
    await pumpShellCoreLocalizedTestApp(
      tester,
      child: SizedBox(
        width: 800,
        height: 420,
        child: SupportSessionsSurface(
          variant: SupportContentSurfaceVariant.desktop,
          sessions: const <SessionRecord>[],
          selectedSessionId: null,
          busy: false,
          challengeForSession: (_) => null,
          actionsForSession:
              (SessionRecord session, ChallengeRecord? challenge) =>
                  SupportSessionActions(
                    onSelect: () {},
                    onStop: () async {},
                    onExport: () async {},
                  ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('support-sessions-surface-desktop')),
      findsOneWidget,
    );
    expect(find.text('Sessions'), findsOneWidget);
  });

  testWidgets(
    'support diagnostics overview and event stream expose shared keys',
    (WidgetTester tester) async {
      await pumpShellCoreLocalizedTestApp(
        tester,
        child: Column(
          children: <Widget>[
            Expanded(
              child: SizedBox(
                width: 800,
                child: SupportDiagnosticsOverviewSurface(
                  variant: SupportContentSurfaceVariant.desktop,
                  children: <Widget>[
                    Container(
                      key: const ValueKey<String>('desktop-overview-card'),
                      color: Colors.amber,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                width: 420,
                child: SupportEventStreamSurface(
                  variant: SupportContentSurfaceVariant.mobile,
                  events: <EventRecord>[
                    EventRecord(
                      id: 'event-1',
                      timestamp: DateTime.utc(2026, 4, 23, 9, 0),
                      sessionId: 'session-1',
                      type: EventType.challengeUpdated,
                      stage: 'provider_resolve',
                      message: 'Browser handoff opened',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>(
            'support-diagnostics-overview-surface-desktop',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('desktop-overview-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('support-event-stream-surface-mobile'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('challenge_updated'), findsOneWidget);
    },
  );
}
