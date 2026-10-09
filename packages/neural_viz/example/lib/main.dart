import 'package:flutter/material.dart';

import 'src/capture_page.dart';
import 'src/design.dart';
import 'src/gallery_page.dart';
import 'src/platform/web_bridge.dart';
import 'src/playground/playground_page.dart';
import 'src/widgets/shell.dart';

/// Routes come from the query string (the example is web first):
///
/// - no parameters: the playground
/// - `?gallery=1`: frozen thumbnails of every stage plus a live hero
/// - any `t=`: capture mode for screenshots (see [CaptureConfig])
void main() {
  final query = Uri.base.queryParameters;
  runApp(
    ExampleApp(
      capture: query.containsKey('t') ? CaptureConfig.fromQuery(query) : null,
      initialRoute: query['gallery'] == '1'
          ? ExampleRoute.gallery
          : ExampleRoute.playground,
    ),
  );
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({
    super.key,
    this.capture,
    this.initialRoute = ExampleRoute.playground,
  });

  /// Set in capture mode, which has no chrome and no navigation.
  final CaptureConfig? capture;
  final ExampleRoute initialRoute;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late ExampleRoute _route = widget.initialRoute;

  void _navigate(ExampleRoute route) {
    if (route == _route) return;
    replaceQuery(route.query);
    setState(() => _route = route);
  }

  @override
  Widget build(BuildContext context) {
    final capture = widget.capture;
    return MaterialApp(
      title: 'neural_viz',
      debugShowCheckedModeBanner: false,
      theme: buildExampleTheme(),
      home: capture != null
          ? CapturePage(config: capture)
          : switch (_route) {
              ExampleRoute.playground => PlaygroundPage(onNavigate: _navigate),
              ExampleRoute.gallery => GalleryPage(onNavigate: _navigate),
            },
    );
  }
}
