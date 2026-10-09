/// The few browser calls the example makes. No-ops off the web, so the
/// example also runs (and is analyzed) as a desktop or mobile app.
library;

export 'web_bridge_stub.dart'
    if (dart.library.js_interop) 'web_bridge_web.dart';
