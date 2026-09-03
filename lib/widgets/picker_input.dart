/// A labelled value with −/+ buttons, and a tap target that opens a wheel.
///
/// The stepper buttons are plain `IconButton.filledTonal`s now: Material gives
/// ripple, hover, focus and disabled states for free, which the previous
/// hand-rolled `StepperButton` reimplemented with a timer and a bool.

library;

import 'package:flutter/material.dart';

import '../styles/app_theme.dart';
import '../utils/haptics.dart';
import 'app_scaffolding.dart';

class PickerInput extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const PickerInput({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
    this.onDecrease,
    this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // `IconButton.filledTonal` defaults to `secondaryContainer`, which in this
    // scheme is verdigris, the colour that means "done". Two big teal circles per
    // card, on a form where nothing is done yet, is exactly the dilution the
    // palette rules exist to prevent. Steppers are plumbing: keep them neutral
    // and let the value they change carry the colour.
    final stepperStyle = IconButton.styleFrom(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      foregroundColor: theme.colorScheme.onSurface,
      disabledForegroundColor: theme.colorScheme.outline,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              IconButton.filledTonal(
                style: stepperStyle,
                onPressed: onDecrease == null
                    ? null
                    : () {
                        Haptics.tick();
                        onDecrease!();
                      },
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Haptics.select();
                    onTap();
                  },
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: Container(
                    height: 48,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                style: stepperStyle,
                onPressed: onIncrease == null
                    ? null
                    : () {
                        Haptics.tick();
                        onIncrease!();
                      },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
