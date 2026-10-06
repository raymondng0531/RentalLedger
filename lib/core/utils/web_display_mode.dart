// Detects how the web app was opened. Uses `package:web`, so the real check
// is only compiled for the web build; elsewhere a stub returns `false`.
export 'web_display_mode_stub.dart'
    if (dart.library.js_interop) 'web_display_mode_web.dart';
