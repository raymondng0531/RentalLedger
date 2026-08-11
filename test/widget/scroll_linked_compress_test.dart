import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/widgets/scroll_linked_compress.dart';

/// Regression tests for the scroll-linked compress header.
///
/// The progress formula was previously inverted (`1 - distance / 96`), which
/// faded the header even at rest — on the Dashboard the balance card rendered
/// at ~54% opacity, i.e. the "washed-out" appearance users saw after
/// navigating back from Profile. At rest the header must be fully opaque, and
/// it must only fade once it actually scrolls past the top edge.
void main() {
  /// Stateful harness so a test can force a parent rebuild *after* layout.
  /// That guarantees [ScrollLinkedCompress] re-runs its position builder with
  /// the header's box already resolved, at whatever offset the test chose.
  Widget buildHarness(ScrollController controller) {
    return _Harness(controller: controller);
  }

  /// The Opacity owned by [ScrollLinkedCompress] (not any framework one).
  Finder compressOpacity() {
    return find.descendant(
      of: find.byType(ScrollLinkedCompress),
      matching: find.byType(Opacity),
    );
  }

  testWidgets('header is fully opaque at rest (no washout)', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(buildHarness(controller));
    // Force a rebuild after layout so the builder resolves the header's box
    // at the resting offset (0).
    tester.state<_HarnessState>(find.byType(_Harness)).bump();
    await tester.pump();

    final opacity = tester.widget<Opacity>(compressOpacity().first);
    expect(opacity.opacity, closeTo(1.0, 0.001));
  });

  testWidgets('header fades once it scrolls past the top edge', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(buildHarness(controller));

    // Scroll the header most of the way past the viewport's top edge (it
    // stays in the tree at this offset), lay out, then force the rebuild so
    // the builder reads the resolved box at the scrolled offset.
    controller.jumpTo(100);
    await tester.pump();
    tester.state<_HarnessState>(find.byType(_Harness)).bump();
    await tester.pump();

    final opacity = tester.widget<Opacity>(compressOpacity().first);
    expect(opacity.opacity, lessThan(0.6));
  });
}

class _Harness extends StatefulWidget {
  const _Harness({required this.controller});

  final ScrollController controller;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int _tick = 0;

  void bump() => setState(() => _tick++);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: widget.controller,
          cacheExtent: 600,
          children: [
            const SizedBox(height: 8),
            // A changing color makes the child widget instance differ on each
            // rebuild, so ScrollLinkedCompress actually rebuilds and its
            // position builder re-runs.
            ScrollLinkedCompress(
              child: ColoredBox(
                color: Color(0xFF00897B + _tick),
                child: const SizedBox(height: 130),
              ),
            ),
            // Tall enough that the list can actually scroll.
            const SizedBox(height: 1000),
          ],
        ),
      ),
    );
  }
}
