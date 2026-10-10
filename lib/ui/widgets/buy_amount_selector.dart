import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';

enum BuyAmount { one, ten, max }

class BuyAmountSelector extends StatelessWidget {
  const BuyAmountSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final BuyAmount value;
  final ValueChanged<BuyAmount> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.buyAmount,
      child: SegmentedButton<BuyAmount>(
        segments: [
          ButtonSegment(
            value: BuyAmount.one,
            label: const Text('×1'),
            tooltip: l10n.buyQuantity('1'),
          ),
          ButtonSegment(
            value: BuyAmount.ten,
            label: const Text('×10'),
            tooltip: l10n.buyQuantity('10'),
          ),
          ButtonSegment(
            value: BuyAmount.max,
            label: Text(l10n.buyMaxShort),
            tooltip: l10n.buyMax,
          ),
        ],
        selected: {value},
        showSelectedIcon: false,
        style: const ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
        ),
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}
