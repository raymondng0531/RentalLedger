import 'package:flutter/material.dart';

/// Compresses a header as it scrolls toward the top of its viewport.
///
/// Unlike a pinned header this stays inside the scroll flow: as the user
/// scrolls the item up toward (and past) the top edge it shrinks and fades —
/// a scroll-linked cue that "this section is leaving the view" — without
/// restructuring the page into a sliver layout.
class ScrollLinkedCompress extends StatefulWidget {
  const ScrollLinkedCompress({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ScrollLinkedCompress> createState() => _ScrollLinkedCompressState();
}

class _ScrollLinkedCompressState extends State<ScrollLinkedCompress> {
  final GlobalKey _boxKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    final scrollable = Scrollable.of(context);
    final scrollPosition = scrollable.position;

    return AnimatedBuilder(
      animation: scrollPosition,
      builder: (context, _) {
        // Progress 0 → 1 as the header's top edge scrolls PAST the viewport's
        // top. At rest the header sits below the viewport top (distance > 0),
        // so progress is 0 and it renders at full opacity and size; it only
        // fades and shrinks once it actually starts leaving the top edge.
        // The scale pivots on the top edge, so the reported position is
        // stable — no feedback between scale and progress.
        var progress = 0.0;
        final itemBox = _boxKey.currentContext?.findRenderObject();
        final scrollableBox = scrollable.context.findRenderObject();
        if (itemBox is RenderBox && scrollableBox is RenderBox) {
          final itemTop = itemBox.localToGlobal(Offset.zero).dy;
          final viewportTop = scrollableBox.localToGlobal(Offset.zero).dy;
          final distance = itemTop - viewportTop;
          // distance > 0 → below the top edge → 0. distance <= -96 → fully
          // past the top edge → 1. (Was `1 - distance / 96`, which faded the
          // header at rest — the balance card rendered at ~54% opacity.)
          progress = (-distance / 96).clamp(0.0, 1.0).toDouble();
        }

        return Opacity(
          opacity: 1.0 - 0.55 * progress,
          child: Transform.scale(
            scale: 1.0 - 0.04 * progress,
            alignment: Alignment.topCenter,
            child: KeyedSubtree(key: _boxKey, child: widget.child),
          ),
        );
      },
    );
  }
}
