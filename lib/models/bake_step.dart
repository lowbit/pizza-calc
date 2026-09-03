/// The building blocks of a bake plan.
///
/// A recipe is a list of [StepSpec]s in order. Each one either takes a known
/// amount of time ([FixedDuration]) or stretches to fill whatever time is left
/// before the bake ([FlexibleDuration]). Exactly one step per recipe is
/// flexible: the bulk ferment for a same-day dough, or the fridge stretch for a
/// cold ferment, which is what lets a single scheduler drive both modes.

library;

sealed class StepTiming {
  const StepTiming();
}

/// A step of known length, e.g. mixing takes 25 minutes.
class FixedDuration extends StepTiming {
  final int minutes;
  const FixedDuration(this.minutes);
}

/// The step that absorbs the slack between the fixed steps and the bake time.
/// [minMinutes] is the point below which the dough genuinely will not work,
/// and is what the feasibility warnings are measured against.
///
/// [maxMinutes] is the same bound from the other side: the point above which
/// the dough is over-fermented rather than merely relaxed. It is null when
/// there is no such point *that the UI can actually reach*, which is why the
/// fridge steps leave it unset: the bake date is the mix date plus the days
/// picker, so a cold ferment is already bounded by its own input. A bulk
/// ferment is not, because a same-day target rolls to tomorrow and can leave
/// the better part of a day for the flexible step to swallow.
class FlexibleDuration extends StepTiming {
  final int minMinutes;
  final int? maxMinutes;
  const FlexibleDuration({required this.minMinutes, this.maxMinutes});
}

/// One step of a recipe, independent of any particular bake.
class StepSpec {
  /// Stable across releases: used as the persistence key for completion times
  /// and to derive notification ids. Never renumber these.
  final String id;
  final String title;
  final List<String> instructions;
  final StepTiming timing;

  /// Reference material rather than a timed action, shown outside the
  /// checklist so it can't be "completed" and doesn't consume schedule time.
  final bool optional;

  final int? _floorMinutes;

  const StepSpec({
    required this.id,
    required this.title,
    required this.instructions,
    required this.timing,
    this.optional = false,
    int? floorMinutes,
  }) : _floorMinutes = floorMinutes;

  /// The shortest time that can really have passed and still leave you with a
  /// genuine version of this step, or null when there is no such point.
  ///
  /// This is the difference between the two kinds of step in a recipe, which
  /// the durations alone do not distinguish. For mixing, balling and baking the
  /// duration is an estimate of how long *you* take, so finishing in half of it
  /// is fine. For a proof or a ferment the duration is what the *dough*
  /// requires, and cutting it to a quarter leaves you with underproofed dough
  /// no matter how quick you were.
  ///
  /// Only steps with a floor push back when they are ticked early, which is
  /// what keeps that warning rare enough to mean something.
  ///
  /// Flexible steps fall back to their own [FlexibleDuration.minMinutes], which
  /// already means exactly this and should not be repeated here.
  int? get floorMinutes =>
      _floorMinutes ??
      (timing is FlexibleDuration
          ? (timing as FlexibleDuration).minMinutes
          : null);

  bool get isFlexible => timing is FlexibleDuration;

  int get fixedMinutes =>
      timing is FixedDuration ? (timing as FixedDuration).minutes : 0;

  int get minMinutes => timing is FlexibleDuration
      ? (timing as FlexibleDuration).minMinutes
      : fixedMinutes;

  /// The longest this step can run before the dough is worse for it, or null
  /// when no reachable plan can overrun it. See [FlexibleDuration.maxMinutes].
  int? get maxMinutes =>
      timing is FlexibleDuration ? (timing as FlexibleDuration).maxMinutes : null;
}

/// Where a step stands in a bake that is actually happening.
enum StepStatus {
  /// Finished, [ScheduledStep.actualEnd] holds when it really happened.
  done,

  /// The step to be working on now.
  current,

  /// Still ahead; times are projections.
  upcoming,
}

/// A [StepSpec] placed on the clock for one specific bake.
class ScheduledStep {
  final StepSpec spec;
  final DateTime start;
  final DateTime end;
  final StepStatus status;

  /// When the step was actually ticked off, for completed steps only.
  final DateTime? actualEnd;

  /// Signed difference between [actualEnd] and the time this step had been
  /// planned to end. Negative is early, positive is late.
  final Duration? drift;

  const ScheduledStep({
    required this.spec,
    required this.start,
    required this.end,
    required this.status,
    this.actualEnd,
    this.drift,
  });

  Duration get duration => end.difference(start);
  bool get isDone => status == StepStatus.done;

  /// How long this step has actually had by [now].
  Duration elapsedAt(DateTime now) => now.difference(start);

  /// True when ticking this step at [now] would cut it below the point where
  /// the dough genuinely suffers. See [StepSpec.floorMinutes].
  ///
  /// Deliberately not a reason to *block* the tick. The recipe's own wording
  /// for a proof is "until puffy, soft, and jiggly when you shake the tray",
  /// so the clock is the estimate and the baker is the judge: a warm kitchen
  /// can finish a two-hour proof in half that, and the dough may have been
  /// mixed before the app was opened.
  bool isRushedAt(DateTime now) {
    final floor = spec.floorMinutes;
    if (floor == null) return false;
    return elapsedAt(now).inMinutes < floor;
  }
}
