import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_shell/src/app.dart';

void main() {
  testWidgets('design reference mode shows switchable desktop concepts', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1680, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const DesktopShellDesignReferencesApp());
    await tester.pumpAndSettle();

    expect(find.text('Desktop shell reference directions'), findsOneWidget);
    expect(find.text('Command Center'), findsWidgets);
    expect(find.text('Focused Workflow'), findsOneWidget);
    expect(find.text('Split Canvas'), findsOneWidget);
    expect(find.text('Operator shell'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('reference-concept-focusedWorkflow')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('One-path editor for the common operator flow.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('reference-concept-splitCanvas')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Productive split canvas'), findsOneWidget);
  });
}
