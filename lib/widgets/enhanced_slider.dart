/// A labelled Material `Slider` with a value readout and range markers.
///
/// The slider itself is now stock M3. The previous version hand-drew the
/// track. What is kept is the marker row underneath, because knowing where 65%
/// sits on the scale is genuinely useful when picking a hydration.

library;

import 'package:flutter/material.dart';

import '../styles/app_theme.dart';
import '../utils/haptics.dart';
import 'app_scaffolding.dart';

class EnhancedSlider extends StatelessWidget {
  final String title;
  final double value;
  final String displayValue;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  /// Tapping the readout opens the wheel, for when dragging is too fiddly.
  final VoidCallback onTap;
  final List<String> markers;

  const EnhancedSlider({
    super.key,
    required this.title,
    required this.value,
    required this.displayValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onTap,
    required this.markers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              InkWell(
                onTap: () {
                  Haptics.select();
                  onTap();
                },
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    displayValue,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: displayValue,
            // The most tactile control in the app had no feedback at all: you
            // could drag hydration across 25 divisions in silence. `divisions`
            // makes the slider snap, so comparing against the current value is
            // enough to fire once per notch rather than once per pixel.
            onChanged: (next) {
              if (next.round() != value.round()) Haptics.tick();
              onChanged(next);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final marker in markers)
                  Text(
                    marker,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
