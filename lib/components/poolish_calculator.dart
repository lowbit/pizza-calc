/// The poolish amount sheet.
///
/// Poolish is a 100% hydration preferment, so whatever amount you choose is
/// half flour and half water, both of which come out of the totals you weigh
/// for the main dough. This sheet just shows that split so the number means
/// something before you commit to it.

library;

import 'package:flutter/material.dart';

import '../styles/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/app_scaffolding.dart';
import '../widgets/picker_input.dart';
import '../widgets/value_picker.dart';

class PoolishCalculator {
  /// Returns the chosen amount, or null if dismissed without changing it.
  static Future<double?> show({
    required BuildContext context,
    double initialAmount = 300.0,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PoolishSheet(initialAmount: initialAmount),
    );
  }
}

class _PoolishSheet extends StatefulWidget {
  final double initialAmount;

  const _PoolishSheet({required this.initialAmount});

  @override
  State<_PoolishSheet> createState() => _PoolishSheetState();
}

class _PoolishSheetState extends State<_PoolishSheet> {
  static const _defaultAmount = 300.0;
  static const _hydration = 100.0;
  static const _yeastPercent = 0.1;

  late double _amount = widget.initialAmount;

  /// No haptic here on purpose. Every caller already provides its own, the
  /// stepper buttons tick, the wheel ticks per notch and its Done click
  /// selects, so buzzing again on the state change made a single tap on +
  /// fire twice.
  void _setAmount(double value) {
    setState(() => _amount = value.clamp(100, 1000));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 100% hydration: equal parts flour and water by weight.
    final flour = _amount / (1 + _hydration / 100);
    final water = flour * (_hydration / 100);
    final yeast = flour * (_yeastPercent / 100);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Poolish', style: theme.textTheme.headlineSmall),
                if (_amount != _defaultAmount)
                  TextButton.icon(
                    onPressed: () {
                      Haptics.select();
                      _setAmount(_defaultAmount);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              color: theme.colorScheme.infoContainer,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onInfoContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Prepare 24 hours in advance',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onInfoContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PickerInput(
              title: 'Poolish amount',
              value: '${_amount.round()}g',
              onTap: () => ValuePicker.show<double>(
                context: context,
                title: 'Poolish amount',
                items: List.generate(19, (i) => (i + 2) * 50.0),
                initialValue: _amount,
                onChanged: _setAmount,
                displayBuilder: (value) => '${value.round()}g',
              ),
              onDecrease: _amount > 100 ? () => _setAmount(_amount - 50) : null,
              onIncrease: _amount < 1000 ? () => _setAmount(_amount + 50) : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Composition', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _CompositionRow(label: 'Flour', amount: flour),
                  _CompositionRow(label: 'Water', amount: water),
                  _CompositionRow(label: 'Yeast', amount: yeast),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () {
                Haptics.commit();
                Navigator.of(context).pop(_amount);
              },
              child: const Text('Use this poolish'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompositionRow extends StatelessWidget {
  final String label;
  final double amount;

  const _CompositionRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(1)}g',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
