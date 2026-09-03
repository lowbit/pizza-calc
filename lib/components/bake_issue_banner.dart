/// Warnings about the plan.
///
/// These are meant to be rare. Anything that is merely normal must not produce
/// one. A banner that shows on every bake is a banner nobody reads.
///
/// M3 has no "warning" colour role, so severity maps onto error / tertiary /
/// secondary containers. That mapping lives in `IssueColors` in the theme, so
/// changing the seed changes these consistently.

library;

import 'package:flutter/material.dart';

import '../services/bake_schedule.dart';
import '../styles/app_theme.dart';
import '../utils/haptics.dart';
import '../utils/time_format.dart';
import '../widgets/app_scaffolding.dart';

class BakeIssueBanner extends StatelessWidget {
  final List<BakeIssue> issues;

  /// Applies an issue's suggested bake time. There is always a way out:
  /// pushing the bake back rather than a dead end.
  final void Function(DateTime suggested)? onApplySuggestion;

  /// Switches the plan to a cold ferment, the way out for an over-long bulk.
  final VoidCallback? onSwitchToColdFerment;

  const BakeIssueBanner({
    super.key,
    required this.issues,
    this.onApplySuggestion,
    this.onSwitchToColdFerment,
  });

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final issue in issues) ...[
          _IssueCard(
            issue: issue,
            onApplySuggestion: onApplySuggestion,
            onSwitchToColdFerment: onSwitchToColdFerment,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _IssueCard extends StatelessWidget {
  final BakeIssue issue;
  final void Function(DateTime suggested)? onApplySuggestion;
  final VoidCallback? onSwitchToColdFerment;

  const _IssueCard({
    required this.issue,
    this.onApplySuggestion,
    this.onSwitchToColdFerment,
  });

  ({Color container, Color onContainer, IconData icon}) _style(
    ColorScheme scheme,
  ) {
    switch (issue.severity) {
      case BakeIssueSeverity.error:
        return (
          container: scheme.errorContainer,
          onContainer: scheme.onErrorContainer,
          icon: Icons.error_outline,
        );
      case BakeIssueSeverity.warning:
        return (
          container: scheme.warningContainer,
          onContainer: scheme.onWarningContainer,
          icon: Icons.warning_amber_rounded,
        );
      case BakeIssueSeverity.info:
        return (
          container: scheme.infoContainer,
          onContainer: scheme.onInfoContainer,
          icon: Icons.info_outline,
        );
    }
  }

  /// The one-tap way out, under the message. The banner owns the haptic: the
  /// finger touched this, so the handler stays silent.
  Widget _fixLink(
    ThemeData theme,
    Color onContainer,
    String label,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: InkWell(
        onTap: () {
          Haptics.select();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: onContainer,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: onContainer,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _style(theme.colorScheme);
    final suggested = issue.suggestedBakeTime;

    return AppCard(
      color: style.container,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, size: 20, color: style.onContainer),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: style.onContainer,
                    height: 1.35,
                  ),
                ),
                if (issue.suggestColdFerment && onSwitchToColdFerment != null)
                  _fixLink(
                    theme,
                    style.onContainer,
                    'Switch to cold ferment',
                    onSwitchToColdFerment!,
                  )
                else if (suggested != null && onApplySuggestion != null)
                  _fixLink(
                    theme,
                    style.onContainer,
                    'Move bake to ${formatClock(suggested)}',
                    () => onApplySuggestion!(suggested),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
