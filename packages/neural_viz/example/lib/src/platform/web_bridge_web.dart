import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Sets `window.__vizReady = true` (the screenshot scripts wait for it).
void markCaptureReady() {
  globalContext.setProperty('__vizReady'.toJS, true.toJS);
}

/// Replaces the page's query string without reloading, so a refresh keeps
/// the current route.
void replaceQuery(String query) {
  final history = globalContext.getProperty<JSObject?>('history'.toJS);
  history?.callMethod<JSAny?>(
    'replaceState'.toJS,
    null,
    ''.toJS,
    (query.isEmpty ? '.' : '?$query').toJS,
  );
}
