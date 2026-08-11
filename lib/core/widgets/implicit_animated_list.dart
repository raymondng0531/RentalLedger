import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import 'animated_entrance.dart';

/// An [AnimatedList] that automatically animates insertions and removals
/// whenever [items] changes.
///
/// Works well with stream-driven lists: pass the new list from your provider
/// and this widget diffs against the previous list by [itemKey], sliding new
/// items in and sliding removed items out (SizeTransition + FadeTransition,
/// per Emil's motion philosophy — ease-out, under 300ms).
///
/// Notes:
/// - Items that stay present but change content (e.g. a bill being marked
///   paid) are NOT re-animated by this widget — that's the caller's job
///   (wrap the item in an [AnimatedSwitcher] if you want content transitions).
/// - Items are assumed to keep their relative order. Reorders are applied
///   without animation.
class ImplicitAnimatedList<T> extends StatefulWidget {
  const ImplicitAnimatedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemKey,
    this.insertDuration = AppDurations.standard,
    this.removeDuration = AppDurations.micro,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.initialStagger = Duration.zero,
    this.entranceDuration = AppDurations.pageTransition,
  });

  final List<T> items;

  /// Builds the visual content for a single item.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Returns a stable, unique key for an item (e.g. its id).
  final String Function(T item) itemKey;

  final Duration insertDuration;
  final Duration removeDuration;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  /// Whether the underlying [AnimatedList] should shrink-wrap its content.
  /// Set `true` (with [NeverScrollableScrollPhysics]) when embedding the list
  /// inside another scrollable (e.g. the dashboard's outer ListView).
  final bool shrinkWrap;

  /// When non-zero, the *initial* items animate in one-by-one (sequential
  /// reveal, [initialStagger] apart) instead of appearing instantly. Real-time
  /// inserts after the first load keep the existing single-item slide-in.
  /// Defaults to zero, which preserves "appear instantly on first load".
  final Duration initialStagger;

  /// Item entrance duration used with [initialStagger].
  final Duration entranceDuration;

  @override
  State<ImplicitAnimatedList<T>> createState() =>
      _ImplicitAnimatedListState<T>();
}

class _ImplicitAnimatedListState<T> extends State<ImplicitAnimatedList<T>> {
  final GlobalKey<AnimatedListState> _listKey =
      GlobalKey<AnimatedListState>();
  late List<T> _items;

  /// True until the first data diff runs, so the initial items can stagger in.
  bool _staggeredInitial = true;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
  }

  @override
  void didUpdateWidget(ImplicitAnimatedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.items, widget.items)) return;

    // Defer the diff to the end of the frame so the list is fully laid out
    // before we mutate it. Avoids "insertItem called during build" asserts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyDiff();
    });
  }

  void _applyDiff() {
    _staggeredInitial = false;
    final list = _listKey.currentState;
    if (list == null) return;

    final newItems = widget.items;
    final newKeys = newItems.map(widget.itemKey).toSet();
    final oldKeys = _items.map(widget.itemKey).toSet();

    // 1. Remove items no longer present. Reverse order keeps indices stable.
    for (var i = _items.length - 1; i >= 0; i--) {
      if (!newKeys.contains(widget.itemKey(_items[i]))) {
        final removed = _items[i];
        list.removeItem(
          i,
          (context, animation) => _buildItem(context, removed, animation),
          duration: widget.removeDuration,
        );
        _items.removeAt(i);
      }
    }

    // 2. Insert new items, preserving the new list's order.
    // `cursor` tracks how many slots of the target list we've placed so far,
    // so a new item is inserted exactly where it belongs among the survivors.
    var cursor = 0;
    for (var i = 0; i < newItems.length; i++) {
      final key = widget.itemKey(newItems[i]);
      if (oldKeys.contains(key)) {
        cursor++;
      } else {
        _items.insert(cursor, newItems[i]);
        list.insertItem(cursor, duration: widget.insertDuration);
        cursor++;
      }
    }
  }

  Widget _buildItem(BuildContext context, T item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: animation,
        curve: AppEasing.easeOut,
      ),
      axisAlignment: -1,
      child: FadeTransition(
        opacity: animation.drive(CurveTween(curve: AppEasing.easeOut)),
        child: widget.itemBuilder(context, item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      initialItemCount: _items.length,
      padding: widget.padding,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      itemBuilder: (context, index, animation) {
        final item = _items[index];
        // Sequential reveal of the initial items, before the first stream diff.
        if (_staggeredInitial && widget.initialStagger != Duration.zero) {
          return AnimatedEntrance(
            key: ValueKey(widget.itemKey(item)),
            delay: Duration(
              milliseconds: index * widget.initialStagger.inMilliseconds,
            ),
            duration: widget.entranceDuration,
            child: _buildItem(context, item, animation),
          );
        }
        return _buildItem(context, item, animation);
      },
    );
  }
}
