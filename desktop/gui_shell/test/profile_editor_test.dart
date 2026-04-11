import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/control/control_plane_models.dart';
import 'package:gui_shell/src/control/profile_draft.dart';
import 'package:gui_shell/src/ui/profile_editor.dart';

void main() {
  testWidgets(
    'VK draft uses invite-first workflow with collapsed runtime defaults',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 1200,
              child: ProfileEditorPanel(
                profiles: const <ProfileRecord>[],
                selectedProfileId: 'profile-1',
                draft: ProfileDraft.defaults(),
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

      expect(find.text('Standard VK invite workflow'), findsOneWidget);
      expect(
        find.textContaining('organizer or dispatcher creates the VK call'),
        findsOneWidget,
      );
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
    },
  );

  testWidgets('non-VK draft keeps runtime defaults inline', (
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
              profiles: const <ProfileRecord>[],
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

    expect(find.text('Standard VK invite workflow'), findsNothing);
    expect(find.text('Operator-managed runtime defaults'), findsNothing);
    expect(find.text('Local UDP listen'), findsOneWidget);
    expect(find.text('Peer address'), findsOneWidget);
  });
}
