import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/widgets/breakpoints.dart';
import 'package:rental_ledger/core/widgets/responsive_page.dart';

void main() {
  // Sets the simulated window size for a test and always resets it after.
  Future<void> withSurface(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('caps and centers content on a wide viewport', (tester) async {
    await withSurface(tester, const Size(1280, 800));
    final childKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsivePage(
            maxWidth: AppContentWidth.form,
            child: SizedBox(
              key: childKey,
              width: double.infinity,
              height: 100,
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(childKey));
    expect(size.width, AppContentWidth.form, reason: 'capped at maxWidth');
    expect(size.height, 100);

    final topLeft = tester.getTopLeft(find.byKey(childKey));
    expect(topLeft.dx, closeTo((1280 - AppContentWidth.form) / 2, 0.1),
        reason: 'horizontally centered');
    expect(topLeft.dy, 0, reason: 'top-aligned, not vertically centered');
  });

  testWidgets('uses the detail default when maxWidth is omitted', (tester) async {
    await withSurface(tester, const Size(1280, 800));
    final childKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsivePage(
            child: SizedBox(
              key: childKey,
              width: double.infinity,
              height: 100,
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(childKey)).width, AppContentWidth.detail);
  });

  testWidgets('is a no-op on a narrow (mobile) viewport', (tester) async {
    await withSurface(tester, const Size(360, 800));
    final childKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsivePage(
            maxWidth: AppContentWidth.form,
            child: SizedBox(
              key: childKey,
              width: double.infinity,
              height: 100,
            ),
          ),
        ),
      ),
    );

    // The child fills the viewport — the wrapper must NOT narrow mobile
    // content below the screen width.
    expect(tester.getSize(find.byKey(childKey)).width, 360);
    expect(tester.getTopLeft(find.byKey(childKey)).dx, 0,
        reason: 'not re-centered when there is no headroom');
  });

  testWidgets('wraps a full-page scroll view: capped, centered and scrollable',
      (tester) async {
    await withSurface(tester, const Size(1280, 800));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsivePage(
            maxWidth: AppContentWidth.form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(
                  30,
                  (i) => SizedBox(height: 40, child: Text('row $i')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(SingleChildScrollView)).width,
        AppContentWidth.form);

    // Fling upward: the content is taller than the viewport and must scroll
    // (the last row moves into view) without any overflow/exceptions.
    await tester.fling(
        find.byType(SingleChildScrollView), const Offset(0, -800), 1000);
    await tester.pumpAndSettle();

    final lastRowTop = tester.getTopLeft(find.text('row 29')).dy;
    expect(lastRowTop, lessThan(800), reason: 'scrolled down into the list');
  });
}
