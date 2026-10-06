import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Whether the app is running as an iPhone/iPad Home Screen web app.
///
/// iOS sets `navigator.standalone` to `true` only for a site opened from the
/// Home Screen. It is `undefined` in Safari tabs and in other browsers, so
/// this is `false` everywhere else, including Android and iOS native builds.
///
/// Google's sign-in popup loses its result in this mode: the user picks an
/// account and lands back on the login page. Sign-in uses a redirect here
/// instead (see `AuthRemoteDataSource.loginWithGoogle`).
bool isIosHomeScreenWebApp() {
  if (!kIsWeb) return false;
  try {
    final navigator = web.window.navigator as JSObject;
    final standalone = navigator.getProperty<JSAny?>('standalone'.toJS);
    return standalone.dartify() == true;
  } catch (_) {
    return false;
  }
}
