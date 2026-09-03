/// The bake time, given the weight it actually carries.
///
/// Every other number on the screen is derived from this one: the yeast curve
/// reads the hours until it, and the whole schedule is laid backwards from it.
/// Yet it used to be the smallest control on the page, a one-line row with a
/// chevron, sitting below hydration. This is the anchor, so it sits above the
/// dough settings and reads at arm's length.
///
/// The caption underneath is the payoff. "19:00" on its own is a preference;
/// "19:00 · mix by 12:35, 6h 25m from now" is the answer to the question you
/// actually opened the app with.

library;

import 'package:flutter/material.dart';

import '../styles/app_theme.dart';
import '../styles/app_typography.dart';
import '../utils/haptics.dart';
import '../utils/time_format.dart';
import '../widgets/app_scaffolding.dart';

class BakeTimeCard extends StatelessWidget {
  /// When the pizza goes in.
  final DateTime targetBake;

  /// Heading above the time, "Baking at" while planning, "Baked at" once the
  /// bake is finished.
  final String label;

  /// The derived line beneath. Null hides it entirely rather than leaving a
  /// gap where a sentence used to be.
  final String? caption;

  /// Severity styling for [caption], used when the caption is reporting drift
  /// rather than a plan.
  final bool captionIsWarning;

  final VoidCallback onTap;

  const BakeTimeCard({
    super.key,
    required this.targetBake,
    required this.onTap,
    this.label = 'Baking at',
    this.caption,
    this.captionIsWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Haptics.select();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatClock(targetBake),
                  style: theme.textTheme.numericDisplay.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Text(
                    formatDayLabel(targetBake, now),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                caption!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: captionIsWarning
                      ? theme.colorScheme.warning
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
