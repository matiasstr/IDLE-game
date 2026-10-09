import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_text_styles.dart';

class AiSpeechBubble extends StatefulWidget {
  const AiSpeechBubble({super.key, required this.text});
  final String text;
  @override
  State<AiSpeechBubble> createState() => _AiSpeechBubbleState();
}

class _AiSpeechBubbleState extends State<AiSpeechBubble>
    with SingleTickerProviderStateMixin {
  late final _cursor = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Timer? _typing;
  var _visible = 0;
  var _started = false;
  var _reduceMotion = false;

  void _startTyping() {
    _typing?.cancel();
    _visible = _reduceMotion ? widget.text.runes.length : 0;
    if (_reduceMotion) return;
    final count = widget.text.runes.length;
    _typing = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (_visible >= count) {
        timer.cancel();
        return;
      }
      setState(() => _visible++);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!_started || reduce != _reduceMotion) {
      _started = true;
      _reduceMotion = reduce;
      if (reduce) {
        _cursor.stop();
        _cursor.value = 1;
      } else {
        _cursor.repeat(reverse: true);
      }
      _startTyping();
    }
  }

  @override
  void didUpdateWidget(covariant AiSpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _startTyping();
  }

  @override
  void dispose() {
    _typing?.cancel();
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.text,
    child: ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context).modelVoice,
              style: AppTextStyles.eyebrow,
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '> ',
                  style: AppTextStyles.number(
                    size: 12,
                    color: AppColors.neonViolet,
                  ),
                ),
                Expanded(
                  child: Text(
                    String.fromCharCodes(widget.text.runes.take(_visible)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.number(
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: _cursor,
                  child: Text(
                    '▍',
                    style: AppTextStyles.number(
                      size: 12,
                      color: AppColors.neonViolet,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
