// The scheduler is where the correctness of the whole feature lives, so these
// are the most detailed tests in the project. They use explicit clock values
// rather than DateTime.now(), nothing here should depend on when it is run.

import 'package:flutter_test/flutter_test.dart';

import 'package:pizza_calc/data/recipes.dart';
import 'package:pizza_calc/models/bake_step.dart';
import 'package:pizza_calc/models/pizza_type.dart';
import 'package:pizza_calc/services/bake_schedule.dart';

void main() {
  // Neapolitan same day: mix 25, bulk flexible (min 60), ball 10, proof 120,
  // shape & bake 15. Fixed work totals 170 minutes.
  final neapolitan = stepsFor(PizzaType.neapolitan, isColdFerment: false);

  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 3, 14, hour, minute);

  ScheduledStep stepById(BakeSchedule schedule, String id) =>
      schedule.steps.firstWhere((s) => s.spec.id == id);

  group('planning', () {
    test('the flexible step absorbs the slack so the bake lands on time', () {
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(20),
        now: at(8),
      );

      expect(schedule.steps, hasLength(5));
      expect(schedule.projectedBake, at(20));
      expect(schedule.issues, isEmpty);

      // 12h total, 170 min of it fixed, so the bulk ferment gets 9h 10m.
      expect(stepById(schedule, 'bulk').duration, const Duration(minutes: 550));
      expect(stepById(schedule, 'mix').start, at(8));
      expect(stepById(schedule, 'ball').start, at(17, 35));
      expect(stepById(schedule, 'proof').start, at(17, 45));
      expect(stepById(schedule, 'bake').end, at(20));
    });

    test('steps run back to back with no gaps or overlaps', () {
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(20),
        now: at(8),
      );

      for (var i = 1; i < schedule.steps.length; i++) {
        expect(schedule.steps[i].start, schedule.steps[i - 1].end);
      }
    });

    test('a start time carrying seconds still lands exactly on the bake', () {
      // DateTime.now() has seconds; Duration.inMinutes truncates. Without
      // normalising, the chain finishes a minute short of the target.
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: DateTime(2026, 3, 14, 8, 0, 37),
        targetBake: at(20),
        now: DateTime(2026, 3, 14, 8, 0, 37),
      );

      expect(schedule.projectedBake, at(20));
      expect(schedule.steps.last.end, at(20));
    });

    test('nothing is marked current until the bake is actually started', () {
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(20),
        now: at(8),
      );

      expect(schedule.currentStep, isNull);
      expect(
        schedule.steps.every((s) => s.status == StepStatus.upcoming),
        isTrue,
      );
    });

    test('an unreachable bake time is an error, not a silent bad plan', () {
      // Only two hours away, but the fixed steps alone need 170 minutes.
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(18),
        targetBake: at(20),
        now: at(18),
      );

      expect(schedule.hasError, isTrue);
      final issue = schedule.issues.single;
      expect(issue.severity, BakeIssueSeverity.error);
      // Squeezing the bulk ferment to nothing still overruns by 50 minutes,
      // and a workable time has to add the minimum ferment back on top.
      expect(schedule.projectedBake, at(20, 50));
      // 21:50 exactly, then rounded up to the next five-minute mark. The
      // suggestion has to clear the threshold by more than nothing: while a
      // plan has not started it re-anchors to now on every rebuild, so a
      // suggestion that only just cleared would be eaten by the clock before
      // the baker's finger arrived, and the same warning would come straight
      // back. See _withMargin.
      expect(issue.suggestedBakeTime, at(21, 55));
    });

    test('a too-short ferment warns without blocking the bake', () {
      // 200 minutes available: 170 fixed leaves 30 for a 60-minute minimum.
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(11, 20),
        now: at(8),
      );

      expect(schedule.hasError, isFalse);
      final issue = schedule.issues.single;
      expect(issue.severity, BakeIssueSeverity.warning);
      expect(issue.message, contains('Bulk ferment'));
      // Half an hour more brings the ferment up to its minimum (11:50), then
      // rounded up for margin.
      expect(issue.suggestedBakeTime, at(11, 55));
    });

    test('a schedule is never laid out backwards, even when impossible', () {
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(19),
        targetBake: at(20),
        now: at(19),
      );

      for (final step in schedule.steps) {
        expect(
          step.end.isBefore(step.start),
          isFalse,
          reason: '${step.spec.id} runs backwards',
        );
      }
    });

    test('an over-long bulk ferment warns and points at the fridge', () {
      // Asking at 23:00 for a 19:00 bake: same-day rolls the target to the
      // next 19:00, which leaves the flexible step the better part of a day.
      // Before this warned, the app planned a 17h counter ferment in silence.
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(23),
        targetBake: DateTime(2026, 3, 15, 19),
        now: at(23),
      );

      expect(schedule.hasError, isFalse);
      final issue = schedule.issues.single;
      expect(issue.severity, BakeIssueSeverity.warning);
      expect(issue.message, contains('over-ferment'));
      // Neither direction on the clock helps here, so the way out is the mode,
      // not a new bake time.
      expect(issue.suggestColdFerment, isTrue);
      expect(issue.suggestedBakeTime, isNull);
    });

    test('an ordinary long bulk ferment stays quiet', () {
      // Mix at breakfast, eat at eight: a 9h 10m bulk, and the most ordinary
      // plan the app has. A warning here would be a warning nobody reads.
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(20),
        now: at(8),
      );

      expect(stepById(schedule, 'bulk').duration.inMinutes, 550);
      expect(schedule.issues, isEmpty);
    });

    test('applying a suggested bake time clears the warning it came from', () {
      // The regression this guards is a link that could never finish its job.
      // Both suggestions used to clear their threshold by exactly zero, and a
      // plan that has not started re-anchors to now on every rebuild, so the
      // minute the suggestion bought was the minute the clock took back while
      // the baker reached for it. Tapping "Move bake to 11:50" produced the
      // identical warning suggesting 11:51, for ever.
      final tight = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(11, 20),
        now: at(8),
      );
      final suggested = tight.issues.single.suggestedBakeTime!;

      // A minute passes between the banner rendering and the finger landing.
      final after = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8, 1),
        targetBake: suggested,
        now: at(8, 1),
      );

      expect(after.issues, isEmpty);
      expect(
        stepById(after, 'bulk').duration.inMinutes,
        greaterThanOrEqualTo(60),
      );
    });
  });

  group('in progress', () {
    test('finishing early gives the time back to the ferment', () {
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(20),
        now: at(8, 20),
        completed: {'mix': at(8, 15)}, // 10 minutes ahead
        started: true,
      );

      final mix = stepById(schedule, 'mix');
      expect(mix.status, StepStatus.done);
      expect(mix.drift, const Duration(minutes: -10));

      // The bulk ferment picks up the spare 10 minutes; the bake holds.
      expect(stepById(schedule, 'bulk').duration, const Duration(minutes: 560));
      expect(schedule.projectedBake, at(20));
      expect(schedule.issues, isEmpty);
    });

    test('running late eats into the ferment, not the bake time', () {
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(20),
        now: at(9),
        completed: {'mix': at(9)}, // 35 minutes over
        started: true,
      );

      expect(stepById(schedule, 'mix').drift, const Duration(minutes: 35));
      // 11h left at 09:00, minus the 145 minutes of fixed work still to come.
      expect(stepById(schedule, 'bulk').duration, const Duration(minutes: 515));
      expect(schedule.projectedBake, at(20));
    });

    test('the first unfinished step is the current one', () {
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(20),
        now: at(10),
        completed: {'mix': at(8, 25)},
        started: true,
      );

      expect(schedule.currentStep?.spec.id, 'bulk');
      expect(stepById(schedule, 'ball').status, StepStatus.upcoming);
    });

    test('once the ferment is done, lateness is a warning not an error', () {
      // Bulk finished 25 minutes late. Only fixed steps remain, so nothing can
      // absorb it, but the dough is fine, you just eat later.
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(20),
        now: at(18),
        completed: {'mix': at(8, 25), 'bulk': at(18)},
        started: true,
      );

      expect(schedule.hasError, isFalse);
      expect(schedule.projectedBake, at(20, 25));
      expect(schedule.runningLate, const Duration(minutes: 25));

      final issue = schedule.issues.single;
      expect(issue.severity, BakeIssueSeverity.warning);
      expect(issue.suggestedBakeTime, at(20, 30));
    });

    test('being well ahead with no ferment left is worth a quiet note', () {
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(20),
        now: at(16),
        completed: {'mix': at(8, 25), 'bulk': at(16)},
        started: true,
      );

      expect(schedule.hasError, isFalse);
      expect(schedule.issues.single.severity, BakeIssueSeverity.info);
    });

    test('a finished bake reports complete and has no current step', () {
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(20),
        now: at(20, 5),
        completed: {
          'mix': at(8, 25),
          'bulk': at(17, 35),
          'ball': at(17, 45),
          'proof': at(19, 45),
          'bake': at(20),
        },
        started: true,
      );

      expect(schedule.isComplete, isTrue);
      expect(schedule.currentStep, isNull);
      expect(schedule.issues, isEmpty);
    });

    test('an out-of-order timestamp cannot invert a step', () {
      // A mis-tap that reports a step finishing before the one before it.
      final schedule = buildSchedule(
        specs: neapolitan,
        anchorStart: at(8),
        targetBake: at(20),
        now: at(10),
        completed: {'mix': at(9), 'bulk': at(8, 30)},
        started: true,
      );

      final bulk = stepById(schedule, 'bulk');
      expect(bulk.end.isBefore(bulk.start), isFalse);
      expect(bulk.end, at(9));
    });
  });

  group('cold ferment', () {
    final coldSteps = stepsFor(PizzaType.neapolitan, isColdFerment: true);

    test('the fridge stretch is what absorbs the slack', () {
      // Mix Tuesday 20:00, bake Thursday 19:00, a two-day ferment.
      final start = DateTime(2026, 3, 10, 20);
      final bake = DateTime(2026, 3, 12, 19);
      final schedule = buildSchedule(
        specs: coldSteps,
        anchorStart: start,
        targetBake: bake,
        now: start,
      );

      expect(schedule.projectedBake, bake);
      expect(schedule.issues, isEmpty);

      // Fixed work is 25 + 75 + 60 + 105 + 15 = 280 minutes, so the fridge
      // takes the remaining 47 hours of the 2820-minute window.
      expect(
        stepById(schedule, 'fridge').duration,
        const Duration(minutes: 2820 - 280),
      );
    });

    test('the three-hour tail before baking is preserved', () {
      final bake = DateTime(2026, 3, 12, 19);
      final schedule = buildSchedule(
        specs: coldSteps,
        anchorStart: DateTime(2026, 3, 10, 20),
        targetBake: bake,
        now: DateTime(2026, 3, 10, 20),
      );

      // Remove & ball starts three hours before the bake, matching the
      // "~3h before baking" guidance the old day-labelled steps gave.
      expect(
        stepById(schedule, 'ball').start,
        bake.subtract(const Duration(hours: 3)),
      );
    });

    test('too little time for a real cold ferment warns', () {
      final start = DateTime(2026, 3, 10, 20);
      final schedule = buildSchedule(
        specs: coldSteps,
        anchorStart: start,
        // Only ~8h of fridge once the fixed work is taken out.
        targetBake: start.add(const Duration(hours: 13)),
        now: start,
      );

      expect(schedule.hasError, isFalse);
      expect(schedule.issues.single.severity, BakeIssueSeverity.warning);
      expect(schedule.issues.single.message, contains('Cold ferment'));
    });
  });

  group('recipe shapes', () {
    test('every recipe has exactly one flexible step', () {
      for (final type in PizzaType.values) {
        for (final cold in [true, false]) {
          final specs = stepsFor(type, isColdFerment: cold);
          expect(
            specs.where((s) => s.isFlexible).length,
            1,
            reason: '${type.name} cold=$cold',
          );
        }
      }
    });

    test('step ids are unique within a recipe', () {
      for (final type in PizzaType.values) {
        for (final cold in [true, false]) {
          final specs = stepsFor(type, isColdFerment: cold);
          final ids = specs.map((s) => s.id).toSet();
          expect(ids, hasLength(specs.length), reason: '${type.name} cold=$cold');
        }
      }
    });

    test('every recipe ends on a bake step and starts by mixing', () {
      for (final type in PizzaType.values) {
        for (final cold in [true, false]) {
          final specs = stepsFor(type, isColdFerment: cold);
          expect(specs.first.id, 'mix', reason: '${type.name} cold=$cold');
          expect(specs.last.id, 'bake', reason: '${type.name} cold=$cold');
        }
      }
    });

    test('pan styles skip balling, round styles do not', () {
      for (final type in PizzaType.values) {
        final specs = stepsFor(type, isColdFerment: false);
        final hasBalling = specs.any((s) => s.id == 'ball');
        expect(hasBalling, !type.isPanStyle, reason: type.name);
      }
    });

    test('a flexible step bounded from above is bounded sanely', () {
      // A max at or under the min would make the two warnings contradict each
      // other, and one too close to the min would fire on a normal plan.
      for (final type in PizzaType.values) {
        for (final cold in [true, false]) {
          final flex = stepsFor(
            type,
            isColdFerment: cold,
          ).firstWhere((s) => s.isFlexible);
          final max = flex.maxMinutes;
          if (max == null) continue;
          expect(
            max,
            greaterThan(flex.minMinutes * 2),
            reason: '${type.name} cold=$cold',
          );
        }
      }
    });

    test('only the bulk ferment is bounded from above', () {
      // The fridge steps need no maximum: the bake date is the mix date plus
      // the days picker, so a cold ferment is already capped by its own input,
      // and a warning that cannot fire is just noise in the code.
      for (final type in PizzaType.values) {
        final cold = stepsFor(
          type,
          isColdFerment: true,
        ).firstWhere((s) => s.isFlexible);
        expect(cold.maxMinutes, isNull, reason: type.name);

        final sameDay = stepsFor(
          type,
          isColdFerment: false,
        ).firstWhere((s) => s.isFlexible);
        expect(sameDay.maxMinutes, isNotNull, reason: type.name);
      }
    });

    test('minimum time is well under a day for same-day recipes', () {
      for (final type in PizzaType.values) {
        final minutes = minimumMinutes(stepsFor(type, isColdFerment: false));
        expect(minutes, greaterThan(120), reason: type.name);
        expect(minutes, lessThan(24 * 60), reason: type.name);
      }
    });

    test('the freezing note is optional and carries no schedule time', () {
      final note = freezingNote(PizzaType.neapolitan, isColdFerment: false);
      expect(note.optional, isTrue);

      // Optional steps must never appear in a schedule.
      final schedule = buildSchedule(
        specs: [...neapolitan, note],
        anchorStart: at(8),
        targetBake: at(20),
        now: at(8),
      );
      expect(schedule.steps.map((s) => s.spec.id), isNot(contains('freezing')));
      expect(schedule.steps, hasLength(5));
    });
  });

  group('finishing a step too early', () {
    // Mix at 08:00, bake at 20:00. Bulk gets the slack.
    BakeSchedule running({Map<String, DateTime> completed = const {}}) =>
        buildSchedule(
          specs: neapolitan,
          anchorStart: at(8),
          targetBake: at(20),
          now: at(8),
          completed: completed,
          started: true,
        );

    test('a proof ticked minutes in is rushed', () {
      final schedule = running(
        completed: {'mix': at(8, 25), 'bulk': at(17, 35), 'ball': at(17, 45)},
      );
      final proof = stepById(schedule, 'proof');

      expect(proof.spec.floorMinutes, 45);
      expect(proof.isRushedAt(at(18)), isTrue);
    });

    test('a proof ticked past its floor is not', () {
      final schedule = running(
        completed: {'mix': at(8, 25), 'bulk': at(17, 35), 'ball': at(17, 45)},
      );
      final proof = stepById(schedule, 'proof');

      // Short of the planned two hours, but past the point where the dough
      // genuinely suffers. A warm kitchen really does do this.
      expect(proof.isRushedAt(at(18, 40)), isFalse);
    });

    test('work steps never count as rushed, however fast they are', () {
      final schedule = running();

      // Mixing in three minutes of a planned twenty-five is the baker being
      // quick, not the dough being short-changed. These must never warn, or
      // the warning stops meaning anything.
      for (final id in ['mix', 'ball', 'bake']) {
        final step = stepById(schedule, id);
        expect(step.spec.floorMinutes, isNull, reason: id);
        expect(step.isRushedAt(step.start), isFalse, reason: id);
      }
    });

    test('the flexible step uses the floor it already carries', () {
      final bulk = stepById(running(completed: {'mix': at(8, 25)}), 'bulk');

      expect(bulk.spec.floorMinutes, 60);
      expect(bulk.isRushedAt(at(9)), isTrue);
      expect(bulk.isRushedAt(at(9, 30)), isFalse);
    });

    test('every style has floors on its ferments and none on its work', () {
      for (final type in PizzaType.values) {
        for (final cold in [false, true]) {
          for (final spec in stepsFor(type, isColdFerment: cold)) {
            final reason = '${type.name} cold=$cold ${spec.id}';
            if (spec.isFlexible || spec.id == 'proof' || spec.id == 'pan') {
              expect(spec.floorMinutes, isNotNull, reason: reason);
              // A floor that meets or exceeds the planned length would fire on
              // an on-time finish, which is the one thing it must never do.
              if (!spec.isFlexible) {
                expect(
                  spec.floorMinutes,
                  lessThan(spec.fixedMinutes),
                  reason: reason,
                );
              }
            }
            if (spec.id == 'mix' || spec.id == 'bake') {
              expect(spec.floorMinutes, isNull, reason: reason);
            }
          }
        }
      }
    });
  });
}
