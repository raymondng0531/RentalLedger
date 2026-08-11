import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/theme/app_theme.dart';
import 'package:rental_ledger/core/widgets/status_badge.dart';

void main() {
  group('StatusBadge.colorFor', () {
    test('pending maps to orange', () {
      expect(StatusBadge.colorFor('pending'), AppTheme.statusPending);
    });

    test('approved maps to blue', () {
      expect(StatusBadge.colorFor('approved'), AppTheme.statusApproved);
    });

    test('paid maps to green', () {
      expect(StatusBadge.colorFor('paid'), AppTheme.statusPaid);
    });

    test('rejected maps to red', () {
      expect(StatusBadge.colorFor('rejected'), AppTheme.statusRejected);
    });

    test('direct payment maps to purple', () {
      expect(StatusBadge.colorFor('Direct Payment'), AppTheme.statusDirectPayment);
    });

    test('unknown status maps to grey', () {
      expect(StatusBadge.colorFor('weird'), Colors.grey);
    });

    test('is case-insensitive', () {
      expect(StatusBadge.colorFor('PENDING'), AppTheme.statusPending);
    });
  });

  group('StatusBadge widget', () {
    testWidgets('renders the status text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadge(status: 'pending')),
        ),
      );

      expect(find.text('pending'), findsOneWidget);
    });

    testWidgets('renders with correct color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusBadge(status: 'approved')),
        ),
      );

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppTheme.statusApproved.withAlpha(30));
    });
  });
}
