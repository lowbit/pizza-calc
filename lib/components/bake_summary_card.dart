/// The locked recipe summary, shown in place of the editable form once a bake
/// is under way, and the finished state once it is over.
///
/// What is already mixed cannot be re-specified, so this is read-only, except
/// the bake time, which stays editable and re-plans only the steps still ahead.
///
/// Two states, one card. Finishing used to be a non-event: the card still read
/// "Bake in progress" after the last step was ticked, and the only way out was
/// a red *Start over* behind a dialog warning you would lose a bake you had
/// already eaten. Now the card reports what happened and offers the one thing
/// you actually want next.

library;

import 'package:flutter/material.dart';

import '../models/bake_session.dart';
import '../services/bake_schedule.dart';
import '../styles/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/app_scaffolding.dart';
import 'bake_time_card.dart';

class BakeSummaryCard extends StatelessWidget {
  final BakeSession session;
  final BakeSchedule schedule;
  final VoidCallback onStartOver;
  final VoidCallback onBakeTimeTap;

  const BakeSummaryCard({
    super.key,
    required this.session,
    required this.schedule,
    required this.onStartOver,
    required this.onBakeTimeTap,
  });

  /// When the last step was actually ticked, the moment the pizza went in.
  DateTime? get _finishedAt =>
      schedule.steps.isEmpty ? null : schedule.steps.last.actualEnd;

  String get _recipeLine =>
      '${session.inputs.doughballs} × ${session.inputs.gramsPerBall.round()}g · '
      '${session.inputs.hydrationPercent.round()}% · '
      '${session.inputs.isColdFerment ? "${session.inputs.coldFermentDays}-day cold ferment" : "same day"}';

  @override
  Widget build(BuildContext context) {
    return schedule.isComplete ? _buildComplete(context) : _buildRunning(context);
  }

  // ── Finished ──────────────────────────────────────────────────

  /// Quiet, but unmistakable. No confetti and no "buon appetito": the card
  /// changes colour, says it is done, and reports the two numbers worth
  /// knowing, when it actually went in, and how long the whole thing took.
  Widget _buildComplete(BuildContext context) {
    final theme = Theme.of(context);
    final finished = _finishedAt;
    final drift = finished?.difference(session.targetBake);

    return AppCard(
      // Basil means a positive state throughout the app; this is the largest
      // thing that ever wears it.
      borderColor: theme.colorScheme.secondary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.secondary,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Text('Bake complete', style: theme.textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _recipeLine,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (finished != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Baked ${formatClockWithDay(finished, DateTime.now())}'
              '${_driftSuffix(drift!)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Start to oven: '
              '${formatSpan(finished.difference(session.startedAt))}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            // No haptic here: `onStartOver` ends the bake, and `_endBake`
            // already provides one. Firing both is the double-buzz bug that
            // undo used to have.
            onPressed: onStartOver,
            child: const Text('Start a new bake'),
          ),
        ],
      ),
    );
  }

  /// "· 4m after target", or nothing at all when it landed on the minute.
  /// Sub-five-minute drift is noise, not a result worth reporting back.
  String _driftSuffix(Duration drift) {
    if (drift.inMinutes.abs() < 5) return ' · on time';
    return drift.isNegative
        ? ' · ${formatDuration(drift)} early'
        : ' · ${formatDuration(drift)} after target';
  }

  // ── In progress ───────────────────────────────────────────────

  Widget _buildRunning(BuildContext context) {
    final theme = Theme.of(context);
    final late = schedule.runningLate;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bake in progress', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _recipeLine,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Started ${formatClockWithDay(session.startedAt, DateTime.now())}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Still the anchor mid-bake, and still editable: moving it
                // re-plans only the steps still ahead.
                BakeTimeCard(
                  targetBake: session.targetBake,
                  onTap: onBakeTimeTap,
                  caption: late.inMinutes.abs() >= 5
                      ? (late.isNegative
                            ? 'On track, ready ${formatDuration(late)} early'
                            : 'Running ${formatDuration(late)} behind')
                      : null,
                  captionIsWarning: late.inMinutes >= 5,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Destructive, and deliberately at the far edge of the card. It used
          // to sit at the top right, the most thumb-reachable point on the
          // screen, next to a checklist you tap repeatedly.
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 4,
                vertical: AppSpacing.xs,
              ),
              child: TextButton(
                onPressed: onStartOver,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                child: const Text('Discard this bake'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
