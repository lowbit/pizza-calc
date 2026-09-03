/// The bake checklist: a compact schedule while planning, and a focused
/// one-step-at-a-time view once you start.
///
/// The full timeline matters most *before* a bake, deciding when to mix, when
/// you need to be around. Once you're baking you mostly need to know what's
/// next. So every step collapses to a single line except the one you're on,
/// which expands into a card with its instructions and a full-width action.
/// Focus, without hiding the schedule or needing a mode toggle.
///
/// Completing is deliberately *only* possible through that button. Making the
/// whole card tappable would overload one gesture with two meanings, and a
/// stray tap stamps a real timestamp that shifts everything after it.

library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../models/bake_step.dart';
import '../services/bake_schedule.dart';
import '../styles/app_theme.dart';
import '../utils/haptics.dart';
import '../utils/time_format.dart';
import '../widgets/app_scaffolding.dart';

/// A real spring, sampled as a curve.
///
/// This is the one idea borrowed from Material 3 Expressive. The package that
/// implements M3E properly was not worth six transitive dependencies for a
/// single interaction, but the physics ship with Flutter, so the interaction
/// that matters, a step collapsing as the next one opens, gets a little
/// overshoot instead of a linear slide.
class SpringCurve extends Curve {
  SpringCurve({double mass = 1, double stiffness = 180, double damping = 22})
    : _simulation = SpringSimulation(
        SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
        0,
        1,
        0,
      );

  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) =>
      // Normalised so the curve genuinely lands on 1 at t=1.
      _simulation.x(t) + t * (1 - _simulation.x(1));
}

final _spring = SpringCurve();
const _springDuration = Duration(milliseconds: 480);

class StepsChecklist extends StatefulWidget {
  final BakeSchedule schedule;

  /// False while planning: every step stays compact and nothing can be ticked.
  final bool started;
  final StepSpec freezingNote;
  final void Function(ScheduledStep step) onComplete;
  final void Function(ScheduledStep step) onUndo;
  final void Function(ScheduledStep step) onSetAlarm;

  const StepsChecklist({
    super.key,
    required this.schedule,
    required this.started,
    required this.freezingNote,
    required this.onComplete,
    required this.onUndo,
    required this.onSetAlarm,
  });

  @override
  State<StepsChecklist> createState() => _StepsChecklistState();
}

class _StepsChecklistState extends State<StepsChecklist> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  /// Compact rows the baker has opened by hand, to read ahead or to undo.
  final Set<String> _opened = {};

  @override
  void initState() {
    super.initState();
    // Drives both the countdown and the progress bar on the current step.
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggleOpen(String id) => setState(() {
    _opened.contains(id) ? _opened.remove(id) : _opened.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = widget.schedule.steps;
    final doneCount = steps.where((s) => s.isDone).length;
    // Honour the accessibility setting rather than springing regardless.
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Steps',
          trailing: widget.started
              ? Text(
                  widget.schedule.isComplete
                      ? 'All done'
                      : '$doneCount of ${steps.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    // Verdigris, not copper: "All done" is the same positive state
                    // the finished card and the done rows report.
                    color: widget.schedule.isComplete
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        // Finished steps fold into a single row. Progress is sequential, so
        // they are always a contiguous prefix, which is what makes one summary
        // row honest rather than a lossy grouping.
        if (widget.started && doneCount > 0) ...[
          _DoneGroup(
            // Re-keying on the count rebuilds the State, so the group collapses
            // itself whenever a step is ticked or undone. Marking something
            // done tidies the last one away without a second gesture.
            key: ValueKey(doneCount),
            steps: steps.take(doneCount).toList(),
            now: _now,
            animate: animate,
            onUndo: widget.onUndo,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (var i = widget.started ? doneCount : 0; i < steps.length; i++) ...[
          AnimatedSize(
            duration: animate ? _springDuration : Duration.zero,
            curve: _spring,
            alignment: Alignment.topCenter,
            child: steps[i].status == StepStatus.current
                ? _CurrentStep(
                    step: steps[i],
                    isLast: i == steps.length - 1,
                    now: _now,
                    onComplete: () => widget.onComplete(steps[i]),
                    onSetAlarm: () => widget.onSetAlarm(steps[i]),
                  )
                : _CompactStep(
                    step: steps[i],
                    number: i + 1,
                    now: _now,
                    opened: _opened.contains(steps[i].spec.id),
                    onToggle: () => _toggleOpen(steps[i].spec.id),
                    onUndo: () => widget.onUndo(steps[i]),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.xs),
        _FreezingNote(note: widget.freezingNote),
      ],
    );
  }
}

/// Everything already ticked off, folded into one line.
///
/// By step five a bake had five dim rows above the card you actually needed,
/// pushing it off the top of a phone screen. Those rows are still worth
/// keeping, since the recorded times and the drift are half the point of ticking,
/// but they are history, and history belongs behind a tap.
///
/// Expanding restores the real rows unchanged, so undo, the timestamps and the
/// drift all still live exactly where they did.
class _DoneGroup extends StatefulWidget {
  /// The completed prefix, in recipe order.
  final List<ScheduledStep> steps;
  final DateTime now;
  final bool animate;
  final void Function(ScheduledStep step) onUndo;

  const _DoneGroup({
    super.key,
    required this.steps,
    required this.now,
    required this.animate,
    required this.onUndo,
  });

  @override
  State<_DoneGroup> createState() => _DoneGroupState();
}

class _DoneGroupState extends State<_DoneGroup> {
  bool _open = false;

  /// Rows opened inside the group, to read back or to undo. Tracked here
  /// rather than by the checklist, because these rows only exist while the
  /// group is expanded.
  final Set<String> _openedRows = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurfaceVariant;
    final count = widget.steps.length;
    final first = widget.steps.first;
    final last = widget.steps.last;
    final span =
        '${formatClock(first.start)} – ${formatClock(last.actualEnd ?? last.end)}';

    return AnimatedSize(
      duration: widget.animate ? _springDuration : Duration.zero,
      curve: _spring,
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          AppCard(
            color: theme.colorScheme.surfaceContainerLow,
            padding: EdgeInsets.zero,
            onTap: () {
              Haptics.select();
              setState(() => _open = !_open);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: AppSpacing.sm + 4,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$count ${count == 1 ? 'step' : 'steps'} done',
                      style: theme.textTheme.bodyMedium?.copyWith(color: dim),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    span,
                    style: theme.textTheme.labelMedium?.copyWith(color: dim),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: dim,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _CompactStep(
                  step: widget.steps[i],
                  number: i + 1,
                  now: widget.now,
                  opened: _openedRows.contains(widget.steps[i].spec.id),
                  onToggle: () => setState(() {
                    final id = widget.steps[i].spec.id;
                    _openedRows.contains(id)
                        ? _openedRows.remove(id)
                        : _openedRows.add(id);
                  }),
                  onUndo: () => widget.onUndo(widget.steps[i]),
                ),
              ),
        ],
      ),
    );
  }
}

/// A finished or upcoming step: one dim line. Height alone says what is behind
/// you and what is ahead, so the current step dominates without shouting.
class _CompactStep extends StatelessWidget {
  final ScheduledStep step;
  final int number;
  final DateTime now;
  final bool opened;
  final VoidCallback onToggle;
  final VoidCallback onUndo;

  const _CompactStep({
    required this.step,
    required this.number,
    required this.now,
    required this.opened,
    required this.onToggle,
    required this.onUndo,
  });

  String get _trailing {
    if (step.isDone) {
      final drift = step.drift;
      final done = formatClock(step.actualEnd ?? step.end);
      if (drift == null || drift.inMinutes.abs() < 5) return done;
      return '$done · ${formatDuration(drift)} ${drift.isNegative ? "early" : "late"}';
    }
    return '${formatClockWithDay(step.start, now)} – ${formatClockWithDay(step.end, now)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurfaceVariant;

    return AppCard(
      color: theme.colorScheme.surfaceContainerLow,
      padding: EdgeInsets.zero,
      onTap: () {
        Haptics.select();
        onToggle();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: AppSpacing.sm + 4,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: step.isDone
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: theme.colorScheme.secondary,
                        )
                      : Text(
                          '$number',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                ),
                Expanded(
                  child: Text(
                    step.spec.title,
                    // Two lines, because one is not enough for the longest
                    // title next to the longest time range ("Bulk ferment with
                    // stretch & folds" against "23:19 – 16:35 tomorrow"), and
                    // that is the row whose length you most want to check while
                    // planning. Only that row ever wraps.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: dim,
                      decoration: step.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: dim,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _trailing,
                  style: theme.textTheme.labelMedium?.copyWith(color: dim),
                ),
              ],
            ),
          ),
          if (opened)
            Padding(
              padding: const EdgeInsets.fromLTRB(38, 0, 14, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InstructionList(
                    instructions: step.spec.instructions,
                    muted: true,
                  ),
                  // Undo lives behind a tap-to-open rather than on the row
                  // itself, so a finished step cannot be un-ticked by brushing
                  // past the list.
                  if (step.isDone)
                    TextButton.icon(
                      onPressed: () {
                        Haptics.select();
                        onUndo();
                      },
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Undo'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The step you're on: the only expanded thing on screen, and the only one
/// that can be completed.
class _CurrentStep extends StatelessWidget {
  final ScheduledStep step;
  final bool isLast;
  final DateTime now;
  final VoidCallback onComplete;
  final VoidCallback onSetAlarm;

  const _CurrentStep({
    required this.step,
    required this.isLast,
    required this.now,
    required this.onComplete,
    required this.onSetAlarm,
  });

  /// Only worth an alarm if it is long enough that you would walk away.
  bool get _canAlarm => step.duration.inMinutes >= 30;

  /// How far through this step we are, by time. The app has always tracked
  /// this and never shown it; on a ten-hour bulk ferment it is the single most
  /// useful thing on screen.
  double get _progress {
    final total = step.duration.inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(step.start).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHigh,
      borderColor: theme.colorScheme.primary,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.spec.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            step.duration.inMinutes <= 0
                ? formatClockWithDay(step.end, now)
                : '${formatClockWithDay(step.start, now)} – ${formatClockWithDay(step.end, now)} · ${formatSpan(step.duration)}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (step.duration.inMinutes > 0) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: _progress),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              // Nothing follows the last step, so "next up" would be naming a
              // step that does not exist. On "Shape & bake" the time left is
              // time until the pizza goes in, which is the whole point of it.
              step.end.isAfter(now)
                  ? isLast
                        ? 'In the oven ${formatRelative(step.end, now)}'
                        : 'Next up ${formatRelative(step.end, now)}'
                  : 'Due now',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          InstructionList(instructions: step.spec.instructions),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: () {
              // The last step of a bake gets the heaviest feedback in the app,
              // and it is the only thing that uses it. That is what makes it
              // read as an ending rather than one more tap.
              isLast ? Haptics.finish() : Haptics.commit();
              onComplete();
            },
            child: Text(isLast ? 'Finish' : 'Mark done'),
          ),
          if (_canAlarm)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: TextButton.icon(
                onPressed: () {
                  Haptics.select();
                  onSetAlarm();
                },
                icon: const Icon(Icons.alarm_add, size: 18),
                label: Text('Set phone alarm for ${formatClock(step.end)}'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Freezing is reference material, not a timed action, so it sits outside the
/// checklist where it cannot be ticked or consume schedule time.
class _FreezingNote extends StatelessWidget {
  final StepSpec note;

  const _FreezingNote({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerLow,
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(
          note.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        onExpansionChanged: (_) => Haptics.select(),
        // The chevron defaults to `primary`, which put the brightest thing on
        // the screen next to the dimmest label, on reference material that
        // isn't even part of the bake.
        iconColor: theme.colorScheme.onSurfaceVariant,
        collapsedIconColor: theme.colorScheme.onSurfaceVariant,
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        children: [
          InstructionList(instructions: note.instructions, muted: true),
        ],
      ),
    );
  }
}
