import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/widgets/empty_state.dart';

void main() {
  testWidgets('shows title and description', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: 'No expenses',
            description: 'Submit one to get started.',
          ),
        ),
      ),
    );

    expect(find.text('No expenses'), findsOneWidget);
    expect(find.text('Submit one to get started.'), findsOneWidget);
  });

  testWidgets('shows action button and calls callback', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: 'Empty',
            actionLabel: 'Add Item',
            onActionTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Add Item'), findsOneWidget);

    await tester.tap(find.text('Add Item'));
    expect(tapped, isTrue);
  });

  testWidgets('hides action when not provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(title: 'Empty'),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsNothing);
  });
}
