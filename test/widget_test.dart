import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/app/app.dart';

void main() {
  testWidgets('GuardCall app shell navigation smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GuardCallApp());
    await tester.pumpAndSettle();

    // Verify Home screen content is visible
    expect(find.text('GuardCall'), findsOneWidget);
    expect(find.text('Protection Active'), findsOneWidget);
    expect(find.text('Start Demo Call'), findsOneWidget);

    // Tap on Calls destination
    await tester.tap(find.text('Calls'));
    await tester.pumpAndSettle();
    expect(find.text('No Active Call'), findsOneWidget);

    // Tap on History destination
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Risk History'), findsOneWidget);

    // Tap on Family destination
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    expect(find.text('Family Circle'), findsOneWidget);

    // Tap on Settings destination
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Accessibility & Motion'), findsOneWidget);
  });
}
