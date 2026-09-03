/// Turns a recipe plus a target bake time into a schedule on the clock, and
/// re-plans it as steps are actually ticked off.
///
/// The rule is the same in both fermentation modes: the fixed steps have known
/// lengths, and the single flexible step (bulk ferment, or the fridge stretch)
/// absorbs whatever time is left before the bake. Once a step is completed its
/// real timestamp becomes the anchor for everything after it, so finishing
/// early or late shifts the rest of the plan instead of silently resetting it.

library;

import '../models/bake_step.dart';

enum BakeIssueSeverity { info, warning, error }

/// Something worth telling the baker about. Deliberately sparse, anything
/// that is merely normal must not produce one of these.
class BakeIssue {
  final BakeIssueSeverity severity;
  final String message;

  /// A bake time that would resolve the issue, when one exists. There is
  /// always a way out: pushing the bake back rather than a dead end.
  final DateTime? suggestedBakeTime;

  /// Whether the way out is to switch to a cold ferment instead of to move the
  /// bake time. True only for an over-long bulk ferment, where neither
  /// direction on the clock helps: pushing the bake later makes it worse, and
  /// pulling it earlier lands at an hour nobody eats at. The fridge is the
  /// actual answer, and the app already schedules that mode well.
  final bool suggestColdFerment;

  const BakeIssue({
    required this.severity,
    required this.message,
    this.suggestedBakeTime,
    this.suggestColdFerment = false,
  });
}

class BakeSchedule {
  final List<ScheduledStep> steps;
  final List<BakeIssue> issues;

  /// What the baker asked for.
  final DateTime targetBake;

  /// When the bake will actually land given real progress so far. Equal to
  /// [targetBake] whenever the flexible step can still absorb the difference.
  final DateTime projectedBake;

  const BakeSchedule({
    required this.steps,
    required this.issues,
    required this.targetBake,
    required this.projectedBake,
  });

  bool get hasError =>
      issues.any((i) => i.severity == BakeIssueSeverity.error);

  bool get isComplete => steps.isNotEmpty && steps.every((s) => s.isDone);

  /// The step to be working on now, or null if the bake is finished.
  ScheduledStep? get currentStep {
    for (final step in steps) {
      if (step.status == StepStatus.current) return step;
    }
    return null;
  }

  Duration get runningLate => projectedBake.difference(targetBake);
}

/// Shortest total time a recipe can be completed in: every fixed step at its
/// length plus the flexible step at its minimum. Used to tell, before starting,
/// whether a bake time is reachable at all.
int minimumMinutes(List<StepSpec> specs) => specs
    .where((s) => !s.optional)
    .fold<int>(0, (sum, s) => sum + s.minMinutes);

/// Build the schedule.
///
/// [anchorStart] is when step one begins, the real start time for a bake in
/// progress, or the hypothetical "if you started now" for one being planned.
/// [completed] maps step id to the moment it was actually ticked off.
BakeSchedule buildSchedule({
  required List<StepSpec> specs,
  required DateTime anchorStart,
  required DateTime targetBake,
  required DateTime now,
  Map<String, DateTime> completed = const {},
  bool started = false,
}) {
  final timed = specs.where((s) => !s.optional).toList();
  final issues = <BakeIssue>[];

  // Work in whole minutes throughout. Real timestamps carry seconds, and
  // Duration.inMinutes truncates, so mixing the two leaves the plan landing a
  // minute short of the bake time.
  anchorStart = _toMinute(anchorStart);
  now = _toMinute(now);
  completed = {
    for (final entry in completed.entries) entry.key: _toMinute(entry.value),
  };

  // Walk the completed prefix first: each real timestamp anchors what follows.
  var cursor = anchorStart;
  final scheduled = <ScheduledStep>[];
  var firstPendingIndex = timed.length;

  for (var i = 0; i < timed.length; i++) {
    final spec = timed[i];
    final doneAt = completed[spec.id];
    if (doneAt == null) {
      firstPendingIndex = i;
      break;
    }
    // Guard against out-of-order timestamps so a stray tap can't invert a range.
    final end = doneAt.isBefore(cursor) ? cursor : doneAt;
    scheduled.add(
      ScheduledStep(
        spec: spec,
        start: cursor,
        end: end,
        status: StepStatus.done,
        actualEnd: doneAt,
        // The flexible step is meant to vary, so drift is only meaningful for
        // steps that had a definite expected length.
        drift: spec.isFlexible
            ? null
            : end.difference(cursor.add(Duration(minutes: spec.fixedMinutes))),
      ),
    );
    cursor = end;
  }

  final pending = timed.sublist(firstPendingIndex);

  // A bake in progress re-plans from the last real timestamp; one still being
  // planned re-plans from now, so the projection never goes stale on screen.
  if (pending.isNotEmpty && !started) {
    cursor = anchorStart.isAfter(now) ? anchorStart : now;
  } else if (pending.isNotEmpty && pending.length == timed.length) {
    cursor = anchorStart;
  }

  final fixedTotal = pending
      .where((s) => !s.isFlexible)
      .fold<int>(0, (sum, s) => sum + s.fixedMinutes);
  final flexSpec = pending.where((s) => s.isFlexible).firstOrNull;

  // How long the flexible step gets: whatever is left after the fixed work.
  // Clamped at zero so an impossible plan renders as "late", never as a
  // backwards time range.
  var flexMinutes = 0;
  if (flexSpec != null) {
    final available = targetBake.difference(cursor).inMinutes;
    flexMinutes = available - fixedTotal;
    if (flexMinutes < 0) flexMinutes = 0;
  }

  for (final spec in pending) {
    final minutes = spec.isFlexible ? flexMinutes : spec.fixedMinutes;
    final end = cursor.add(Duration(minutes: minutes));
    scheduled.add(
      ScheduledStep(
        spec: spec,
        start: cursor,
        end: end,
        status: (started && spec == pending.first)
            ? StepStatus.current
            : StepStatus.upcoming,
      ),
    );
    cursor = end;
  }

  final projectedBake = scheduled.isEmpty ? targetBake : cursor;
  issues.addAll(
    _scheduleIssues(
      flexSpec: flexSpec,
      flexMinutes: flexMinutes,
      targetBake: targetBake,
      projectedBake: projectedBake,
      pendingEmpty: pending.isEmpty,
    ),
  );

  return BakeSchedule(
    steps: scheduled,
    issues: issues,
    targetBake: targetBake,
    projectedBake: projectedBake,
  );
}

List<BakeIssue> _scheduleIssues({
  required StepSpec? flexSpec,
  required int flexMinutes,
  required DateTime targetBake,
  required DateTime projectedBake,
  required bool pendingEmpty,
}) {
  if (pendingEmpty) return const [];

  final issues = <BakeIssue>[];
  final late = projectedBake.difference(targetBake);

  if (late.inMinutes > 0) {
    // Two different situations that must not look the same. With a flexible
    // step still ahead, being late means the bake is genuinely impossible:
    // the ferment has already been squeezed to nothing. With only fixed steps
    // left the dough is fine, you simply eat later, so that is a warning.
    if (flexSpec != null) {
      issues.add(
        BakeIssue(
          severity: BakeIssueSeverity.error,
          message:
              "There is not enough time. Even with no ${flexSpec.title.toLowerCase()} "
              "you'd be ${_humanize(late)} late.",
          suggestedBakeTime: _withMargin(
            projectedBake.add(Duration(minutes: flexSpec.minMinutes)),
          ),
        ),
      );
    } else {
      issues.add(
        BakeIssue(
          severity: BakeIssueSeverity.warning,
          message:
              'Running ${_humanize(late)} behind. The remaining steps finish '
              'after your bake time.',
          suggestedBakeTime: _withMargin(projectedBake),
        ),
      );
    }
    return issues;
  }

  // There is time, but the dough would be short-changed.
  if (flexSpec != null && flexMinutes < flexSpec.minMinutes) {
    issues.add(
      BakeIssue(
        severity: BakeIssueSeverity.warning,
        message:
            '${flexSpec.title} would only get ${_humanizeMinutes(flexMinutes)}, '
            'under the ${_humanizeMinutes(flexSpec.minMinutes)} this dough really needs.',
        suggestedBakeTime: _withMargin(
          targetBake.add(Duration(minutes: flexSpec.minMinutes - flexMinutes)),
        ),
      ),
    );
  }

  // The same bound from the other side. Only the bulk ferment carries a
  // maximum, so this cannot fire on a cold ferment, whose length is capped by
  // the days picker. A warning rather than an error: a cold kitchen really does
  // stretch a bulk ferment, and the dough may already be mixed.
  final flexMax = flexSpec?.maxMinutes;
  if (flexSpec != null && flexMax != null && flexMinutes > flexMax) {
    issues.add(
      BakeIssue(
        severity: BakeIssueSeverity.warning,
        message:
            '${flexSpec.title} would run ${_humanizeMinutes(flexMinutes)}, well past the '
            '${_humanizeMinutes(flexMax)} this dough takes at room temperature. '
            'It will over-ferment and go slack.',
        suggestColdFerment: true,
      ),
    );
  }

  // No flexible step left to absorb slack and we're comfortably ahead.
  if (flexSpec == null && late.inMinutes < -20) {
    issues.add(
      BakeIssue(
        severity: BakeIssueSeverity.info,
        message:
            "You're ${_humanize(-late)} ahead. The dough will be ready early.",
      ),
    );
  }

  return issues;
}

/// Drop seconds so schedule arithmetic is exact to the minute.
DateTime _toMinute(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);

/// Round a suggested bake time up to the next five-minute mark.
///
/// This is what makes "Move bake to ..." actually resolve the thing it is
/// offered for. The suggestions are computed to clear their threshold by
/// exactly nothing, and while a plan has not started it re-anchors to *now* on
/// every rebuild, so the single minute the suggestion buys is the same minute
/// the clock takes back between the banner rendering and a finger reaching it.
/// The result was a link that moved the bake a minute later on every tap and
/// re-displayed the identical warning, for ever.
///
/// Rounding strictly upward buys a few minutes of slack instead, and lands on
/// the kind of time a person would actually choose to eat at: 02:50, not 02:47.
DateTime _withMargin(DateTime dt) {
  final floored = _toMinute(dt);
  return floored.add(Duration(minutes: 5 - (floored.minute % 5)));
}

String _humanize(Duration d) => _humanizeMinutes(d.inMinutes.abs());

String _humanizeMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}
