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
              profiles: const <ProfileRecord>[],
              providerDescriptors: _providerDescriptors,
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
              profiles: const <ProfileRecord>[],
              providerDescriptors: _providerDescriptors,
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
}
