import 'package:flutter/material.dart';

class NarrowLayout extends StatelessWidget {
  const NarrowLayout({
    super.key,
    required this.topBar,
    required this.resources,
    required this.visualization,
    required this.speech,
    required this.trainButton,
    required this.store,
  });
  final Widget topBar;
  final Widget resources;
  final Widget visualization;
  final Widget speech;
  final Widget trainButton;
  final Widget store;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Short windows scroll as a whole; tall phones keep a pinned shop.
      // Below 720 px a pinned shop would get only a sliver of height
      // (under 100 px on a 360×640 phone).
      final shortWindow = constraints.maxHeight < 720;
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: topBar,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: resources,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: shortWindow ? 160 : constraints.maxHeight * 0.28,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: visualization,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: speech,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: trainButton,
          ),
          const SizedBox(height: 12),
          if (shortWindow)
            SizedBox(height: 300, child: store)
          else
            Expanded(child: store),
        ],
      );
      return shortWindow ? SingleChildScrollView(child: content) : content;
    },
  );
}
