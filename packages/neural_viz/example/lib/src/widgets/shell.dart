import 'package:flutter/material.dart';

import '../design.dart';

enum ExampleRoute {
  playground('Playground', ''),
  gallery('Gallery', 'gallery=1');

  const ExampleRoute(this.label, this.query);

  final String label;

  /// Query string that opens this route.
  final String query;
}

/// Top bar with the wordmark and route tabs, over the page body.
class ExampleShell extends StatelessWidget {
  const ExampleShell({
    super.key,
    required this.route,
    required this.onNavigate,
    required this.child,
    this.trailing,
  });

  final ExampleRoute route;
  final ValueChanged<ExampleRoute> onNavigate;
  final Widget child;

  /// Shown at the right of the bar on wide screens.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 760;
    return Scaffold(
      backgroundColor: Palette.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 52,
            padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16),
            decoration: const BoxDecoration(
              color: Palette.background,
              border: Border(bottom: BorderSide(color: Palette.border)),
            ),
            child: Row(
              children: [
                const _Wordmark(),
                SizedBox(width: wide ? 28 : 16),
                for (final r in ExampleRoute.values)
                  _Tab(
                    label: r.label,
                    active: r == route,
                    onTap: () => onNavigate(r),
                  ),
                const Spacer(),
                if (width >= 1040 && trailing != null) trailing!,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'neural_viz',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CustomPaint(size: Size(20, 16), painter: _GlyphPainter()),
            const SizedBox(width: 10),
            Text(
              'neural_viz',
              style: Styles.value.copyWith(
                fontSize: 13,
                letterSpacing: 0.2,
                color: Palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A three-neuron network: the package's mark.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(3, size.height * 0.22);
    final b = Offset(3, size.height * 0.78);
    final c = Offset(size.width - 3.5, size.height / 2);
    final line = Paint()
      ..color = Palette.violet.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    canvas
      ..drawLine(a, c, line)
      ..drawLine(b, c, line);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Palette.violet;
    final fill = Paint()..color = Palette.surfaceRaised;
    for (final p in [a, b]) {
      canvas
        ..drawCircle(p, 2.4, fill)
        ..drawCircle(p, 2.4, ring);
    }
    canvas
      ..drawCircle(c, 3.2, fill)
      ..drawCircle(c, 3.2, ring)
      ..drawCircle(c, 1.4, Paint()..color = Palette.cyan);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        onTap: active ? null : onTap,
        hoverColor: Colors.transparent,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? Palette.cyan : Colors.transparent,
              ),
            ),
          ),
          child: Text(
            label,
            style: Styles.body.copyWith(
              color: active ? Palette.textPrimary : Palette.textSecondary,
              fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
