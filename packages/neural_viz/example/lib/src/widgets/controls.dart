import 'package:flutter/material.dart';

import '../design.dart';

/// Chrome animations follow the platform's reduced-motion setting.
Duration chromeDuration(BuildContext context, int milliseconds) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// A surface card with a 1 px border.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.surface,
        border: Border.all(color: Palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Uppercase mono label that opens a group of controls.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(text.toUpperCase(), style: Styles.label),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1, color: Palette.border)),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

/// A slider with its label and formatted value on one line.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.detail,
    this.semanticFormatter,
  });

  final String label;
  final String valueText;

  /// Shown after the value in muted mono, e.g. "E 0.52".
  final String? detail;
  final double value;

  /// Null disables the slider (the value is derived elsewhere).
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final SemanticFormatterCallback? semanticFormatter;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(label, style: Styles.body),
            const Spacer(),
            if (detail != null) ...[
              Text(detail!, style: Styles.label.copyWith(letterSpacing: 0)),
              const SizedBox(width: 8),
            ],
            Text(
              valueText,
              style: Styles.value.copyWith(
                color: enabled ? Palette.textPrimary : Palette.textSecondary,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SliderTheme(
              data: SliderTheme.of(
                context,
              ).copyWith(padding: const EdgeInsets.symmetric(horizontal: 6)),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
                semanticFormatterCallback:
                    semanticFormatter ?? (_) => valueText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Connected segments; the selected one is raised.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Palette.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: IntrinsicHeight(
          child: Row(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0)
                  const VerticalDivider(width: 1, color: Palette.border),
                Expanded(
                  child: _Choice(
                    label: options[i].$2,
                    selected: options[i].$1 == selected,
                    onTap: () => onSelected(options[i].$1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Separate chips that wrap, for longer option lists.
class ChipChoices<T> extends StatelessWidget {
  const ChipChoices({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (value, label) in options)
          _Choice(
            label: label,
            selected: value == selected,
            outlined: true,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final bool selected;
  final bool outlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: Styles.value.copyWith(
        fontSize: 11.5,
        color: selected ? Palette.textPrimary : Palette.textSecondary,
      ),
    );
    final radius = BorderRadius.circular(outlined ? 6 : 0);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          hoverColor: Palette.textPrimary.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: chromeDuration(context, 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? Palette.surfaceRaised : null,
              borderRadius: radius,
              border: outlined
                  ? Border.all(
                      color: selected
                          ? Palette.cyan.withValues(alpha: 0.55)
                          : Palette.border,
                    )
                  : Border(
                      bottom: BorderSide(
                        width: 1,
                        color: selected ? Palette.cyan : Colors.transparent,
                      ),
                    ),
            ),
            child: text,
          ),
        ),
      ),
    );
  }
}

/// A full-width row with a label, an optional hint and a small switch.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Styles.body.copyWith(
                            color: value
                                ? Palette.textPrimary
                                : Palette.textSecondary,
                          ),
                        ),
                        if (hint != null) Text(hint!, style: Styles.hint),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  MiniSwitch(value: value),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 30 × 16 switch. Display only; the row handles input.
class MiniSwitch extends StatelessWidget {
  const MiniSwitch({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final duration = chromeDuration(context, 140);
    return AnimatedContainer(
      duration: duration,
      width: 30,
      height: 16,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? Palette.cyan.withValues(alpha: 0.16) : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? Palette.cyan.withValues(alpha: 0.7) : Palette.border,
        ),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? Palette.cyan : Palette.textMuted,
          ),
        ),
      ),
    );
  }
}

enum ButtonTone { primary, neutral, quiet }

/// Outlined chrome button with an optional keyboard hint.
class ChromeButton extends StatelessWidget {
  const ChromeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = ButtonTone.neutral,
    this.icon,
    this.keyHint,
    this.tooltip,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonTone tone;
  final IconData? icon;
  final String? keyHint;
  final String? tooltip;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      ButtonTone.primary => Palette.cyan,
      ButtonTone.neutral => Palette.textPrimary,
      ButtonTone.quiet => Palette.textSecondary,
    };
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 34)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? Palette.textMuted : accent,
      ),
      backgroundColor: WidgetStatePropertyAll(
        tone == ButtonTone.primary
            ? Palette.cyan.withValues(alpha: 0.06)
            : Colors.transparent,
      ),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? accent.withValues(alpha: 0.14)
            : (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)
                  ? accent.withValues(alpha: 0.07)
                  : null),
      ),
      shape: WidgetStateProperty.resolveWith(
        (states) => RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: states.contains(WidgetState.disabled)
                ? Palette.border
                : (tone == ButtonTone.primary
                      ? Palette.cyan.withValues(alpha: 0.5)
                      : (tone == ButtonTone.quiet
                            ? Colors.transparent
                            : Palette.borderStrong)),
          ),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontFamily: kSans, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
    Widget button = TextButton(
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (keyHint != null) ...[const SizedBox(width: 8), KeyCap(keyHint!)],
        ],
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return button;
  }
}

/// A keyboard key, drawn as a small outlined cap.
class KeyCap extends StatelessWidget {
  const KeyCap(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Palette.borderStrong),
        color: Palette.surfaceRaised,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Styles.label.copyWith(
          letterSpacing: 0,
          color: Palette.textSecondary,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// A shortcut line: key caps then a description.
class ShortcutHint extends StatelessWidget {
  const ShortcutHint({super.key, required this.keys, required this.label});

  final List<String> keys;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final key in keys) ...[KeyCap(key), const SizedBox(width: 3)],
        const SizedBox(width: 5),
        Text(label, style: Styles.hint),
      ],
    );
  }
}

/// A small label-over-value readout.
class Readout extends StatelessWidget {
  const Readout({
    super.key,
    required this.label,
    required this.value,
    this.color = Palette.textPrimary,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: Styles.label),
        const SizedBox(height: 3),
        Text(value, style: Styles.value.copyWith(fontSize: 13, color: color)),
      ],
    );
  }
}
