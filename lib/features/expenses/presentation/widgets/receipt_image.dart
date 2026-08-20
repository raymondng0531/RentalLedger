import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Displays a Firebase Storage receipt image cross-platform.
///
/// Native keeps the existing `Image.network` behaviour unchanged.
///
/// Web is the tricky case: Flutter's `Image.network` and the Storage SDK's
/// `getData` both fetch the download URL through the browser's cross-origin
/// fetch (XHR / package:http), which the browser blocks unless the bucket has
/// CORS configured for GET — and the block may hang the fetch so the widget
/// spins forever. The one mechanism a browser loads cross-origin without CORS
/// is a real HTML `<img>` element (a "no-cors" request). So on web we render a
/// real `<img>` through an [HtmlElementView] and drive its `load`/`error`
/// events ourselves. That gives us full control over the loading state (it can
/// never spin forever — a hard timeout forces a visible error) and surfaces the
/// real failure instead of hiding it.
class ReceiptImage extends StatelessWidget {
  const ReceiptImage({
    super.key,
    required this.receiptUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
    this.errorBuilder,
    this.onTap,
  });

  /// The Firebase Storage download URL.
  final String receiptUrl;

  final double? height;
  final double? width;
  final BoxFit fit;

  /// Replaces the default centered progress indicator while loading.
  final WidgetBuilder? loadingBuilder;

  /// Replaces the default image-not-supported fallback when loading fails.
  /// On web the real failure is additionally shown as a small debug label, so
  /// the root cause is never hidden.
  final WidgetBuilder? errorBuilder;

  /// Called when the receipt is tapped. On native this wraps the image in a
  /// [GestureDetector]; on web the platform view's DOM `click` listener fires
  /// it, because the engine's platform-view slot swallows pointer events
  /// before Flutter's gesture system ever sees them.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // Native: unchanged behaviour, plus an optional tap target.
      Widget image = Image.network(
        receiptUrl,
        height: height,
        width: width,
        fit: fit,
        loadingBuilder: _loadingBuilder(context),
        errorBuilder: (_, __, ___) => _error(context, null),
      );
      if (onTap != null) {
        image = GestureDetector(
          // Opaque so letterboxed areas (BoxFit.contain) are tappable too.
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: image,
        );
      }
      return image;
    }
    return _ReceiptImageWeb(
      receiptUrl: receiptUrl,
      height: height,
      width: width,
      fit: fit,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      onTap: onTap,
    );
  }

  ImageLoadingBuilder _loadingBuilder(BuildContext context) {
    if (loadingBuilder != null) {
      return (_, child, _) => loadingBuilder!(context);
    }
    return (_, child, progress) {
      if (progress == null) return child;
      return const Center(child: CircularProgressIndicator());
    };
  }

  /// Renders the caller's placeholder (or a default icon), and appends the
  /// real failure text when [detail] is available.
  Widget _error(BuildContext context, String? detail) {
    final placeholder = errorBuilder?.call(context) ??
        const Center(child: Icon(Icons.image_not_supported_outlined));
    if (detail == null) return placeholder;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        placeholder,
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            'Debug: $detail',
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.redAccent,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

enum _ImgState { loading, loaded, failed }

/// Web-only: renders the stored receipt through a real HTML `<img>` element.
class _ReceiptImageWeb extends StatefulWidget {
  const _ReceiptImageWeb({
    required this.receiptUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
    this.errorBuilder,
    this.onTap,
  });

  final String receiptUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? errorBuilder;
  final VoidCallback? onTap;

  @override
  State<_ReceiptImageWeb> createState() => _ReceiptImageWebState();
}

class _ReceiptImageWebState extends State<_ReceiptImageWeb> {
  static int _nextViewId = 0;

  late String _viewType;
  _ImgState _state = _ImgState.loading;
  String? _errorDetail;
  Timer? _timeout;
  web.HTMLImageElement? _imgElement;

  @override
  void initState() {
    super.initState();
    _viewType = 'receipt-image-${_nextViewId++}';
    // 1. Surface the exact URL being displayed (always visible: `print` goes
    //    to the browser console even in release builds).
    print('[ReceiptImage] web viewType=$_viewType src=${widget.receiptUrl}');
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      _createImgElement,
    );
    _restartTimeout();
  }

  @override
  void didUpdateWidget(covariant _ReceiptImageWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receiptUrl != widget.receiptUrl) {
      // Receipt replaced after Save: point the existing <img> at the new URL
      // (or, if it has not been created yet, the factory reads the current
      // `widget.receiptUrl` when it runs) and restart the load lifecycle.
      print('[ReceiptImage] src changed: ${oldWidget.receiptUrl} -> '
          '${widget.receiptUrl}');
      _state = _ImgState.loading;
      _errorDetail = null;
      _imgElement?.src = widget.receiptUrl;
      _restartTimeout();
    }
  }

  void _restartTimeout() {
    _timeout?.cancel();
    // Never allow an infinite spinner: force a visible error after 15s.
    _timeout = Timer(const Duration(seconds: 15), () {
      if (!mounted || _state != _ImgState.loading) return;
      print('[ReceiptImage] TIMEOUT (15s) waiting for src=${widget.receiptUrl}');
      setState(() {
        _state = _ImgState.failed;
        _errorDetail = 'Timed out waiting for the image to load (15s). '
            'A 403 means the Firebase Storage rules deny read; a 404 means '
            'the object is missing.';
      });
    });
  }

  web.HTMLElement _createImgElement(int viewId) {
    // The <img> is wrapped in a <div> because a platform view is rendered by
    // the engine as a DOM slot whose wrapper sits ABOVE the Flutter canvas:
    // taps over the image are consumed by the slot and never reach a Flutter
    // GestureDetector (even one stacked over the widget). Interaction has to
    // happen in the DOM — the <div> is the topmost hittable element, and any
    // click on the <img> bubbles up to it, so we forward the click to onTap.
    final container = web.HTMLDivElement();
    container
      // Fill the Flutter box.
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      // Make the platform-view area itself the hit target for the click.
      ..style.pointerEvents = 'auto'
      ..style.cursor = widget.onTap != null ? 'pointer' : 'default';
    final img = web.HTMLImageElement();
    _imgElement = img;
    img
      ..src = widget.receiptUrl
      // Fill the container and honour the requested fit.
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = _objectFitFor(widget.fit)
      ..style.display = 'block'
      // Hittable so the click target is the image (the event then bubbles to
      // the container above, where the click listener lives).
      ..style.pointerEvents = 'auto';
    container.appendChild(img);
    img.addEventListener(
      'load',
      ((JSAny? _) {
        print('[ReceiptImage] <img> LOADED viewType=$_viewType');
        if (!mounted) return;
        setState(() => _state = _ImgState.loaded);
      }).toJS,
    );
    img.addEventListener(
      'error',
      ((JSAny? _) {
        print('[ReceiptImage] <img> ERROR viewType=$_viewType '
            'src=${widget.receiptUrl} — an <img> tag is never CORS-blocked, '
            'so this is an HTTP failure from the server (check Storage rules).');
        if (!mounted) return;
        setState(() {
          _state = _ImgState.failed;
          _errorDetail = 'The browser could not load the image (this is not a '
              'CORS issue — <img> ignores CORS). A 403 means the Firebase '
              'Storage rules deny read; a 404 means the object is missing.';
        });
      }).toJS,
    );
    if (widget.onTap != null) {
      container.addEventListener(
        'click',
        ((JSAny? _) {
          print('[ReceiptImage] <img> CLICK viewType=$_viewType');
          widget.onTap?.call();
        }).toJS,
      );
    }
    print('[ReceiptImage] <img> created viewType=$_viewType viewId=$viewId');
    return container;
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget view;
    if (_state == _ImgState.failed) {
      view = widget.errorBuilder != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.errorBuilder!(context),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    'Debug: $_errorDetail',
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.redAccent,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                'Debug: $_errorDetail',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            );
    } else {
      // The <img> platform view is always present so the browser starts the
      // request immediately; a spinner overlays it until `load` fires.
      view = Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView(viewType: _viewType),
          if (_state == _ImgState.loading)
            Positioned.fill(
              child: widget.loadingBuilder?.call(context) ??
                  const Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }
    if (widget.height != null || widget.width != null) {
      view = SizedBox(
        width: widget.width,
        height: widget.height,
        child: view,
      );
    }
    return view;
  }

  static String _objectFitFor(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover:
        return 'cover';
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.scaleDown:
        return 'scale-down';
      case BoxFit.none:
        return 'none';
      default:
        return 'contain';
    }
  }
}
