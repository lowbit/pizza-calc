// Ingredient maths. The invariant that matters is that everything sums back to
// the dough weight you asked for, every other figure is derived from flour.

import 'dart:math' show sqrt;

import 'package:flutter_test/flutter_test.dart';

import 'package:pizza_calc/models/pizza_type.dart';
import 'package:pizza_calc/services/bake_schedule.dart';
import 'package:pizza_calc/services/dough_calculator.dart';

void main() {
  DoughInputs inputsFor(
    PizzaType type, {
    int? doughballs,
    double? gramsPerBall,
    int yeastType = 1,
    int fermentationMode = 0,
    double poolishAmount = 300.0,
    int coldFermentDays = 2,
  }) {
    final config = type.config;
    return DoughInputs(
      pizzaType: type,
      doughballs: doughballs ?? config.defaultDoughballs,
      gramsPerBall: gramsPerBall ?? config.defaultGramsPerBall,
      hydrationPercent: config.defaultHydration,
      yeastType: yeastType,
      poolishAmount: poolishAmount,
      fermentationMode: fermentationMode,
      coldFermentDays: coldFermentDays,
      targetBakeHour: 19,
      targetBakeMinute: 0,
    );
  }

  double sum(Map<String, double> m) => m.values.fold(0.0, (a, b) => a + b);

  group('ingredients', () {
    test('the classic Neapolitan figures come out as expected', () {
      final result = computeIngredients(
        inputsFor(PizzaType.neapolitan),
        fermentationHours: 18.75,
      );

      // These moved when the Neapolitan default went 60% → 62%. The total is
      // fixed at doughballs × gramsPerBall, so raising hydration takes weight
      // *out* of the flour and puts it into the water, which is why flour
      // falls here rather than the total rising.
      expect(result['flour'], closeTo(607.2, 0.1));
      expect(result['water'], closeTo(376.5, 0.1));
      expect(result['salt'], closeTo(15.2, 0.1));
      expect(result['yeast'], closeTo(1.2, 0.1));
      expect(sum(result), closeTo(1000.0, 0.01));
    });

    test('every style totals the dough weight requested', () {
      for (final type in PizzaType.values) {
        for (final mode in [0, 1]) {
          final inputs = inputsFor(type, fermentationMode: mode);
          final result = computeIngredients(inputs, fermentationHours: 24);
          expect(
            sum(result),
            closeTo(inputs.totalDoughWeight, 0.01),
            reason: '${type.name} mode $mode',
          );
        }
      }
    });

    test('sugar and oil rows appear only for the styles that use them', () {
      final neapolitan = computeIngredients(
        inputsFor(PizzaType.neapolitan),
        fermentationHours: 12,
      );
      expect(neapolitan.containsKey('sugar'), isFalse);
      expect(neapolitan.containsKey('oil'), isFalse);

      final newYork = computeIngredients(
        inputsFor(PizzaType.newYork),
        fermentationHours: 12,
      );
      expect(newYork['sugar'], greaterThan(0));
      expect(newYork['oil'], greaterThan(0));
    });

    test('poolish replaces the yeast row and supplies half its weight in '
        'flour and half in water', () {
      final direct = computeIngredients(
        inputsFor(PizzaType.neapolitan),
        fermentationHours: 24,
      );
      final withPoolish = computeIngredients(
        inputsFor(PizzaType.neapolitan, yeastType: 2, poolishAmount: 300),
        fermentationHours: 24,
      );

      expect(withPoolish.containsKey('yeast'), isFalse);
      expect(withPoolish['poolish'], 300.0);
      expect(sum(withPoolish), closeTo(1000.0, 0.01));

      // 150 g of the flour is already in the poolish, so less is weighed out.
      expect(
        withPoolish['flour'],
        lessThan(direct['flour']! - 100),
      );
    });

    test('scaling the doughballs scales the whole recipe', () {
      final four = computeIngredients(
        inputsFor(PizzaType.neapolitan, doughballs: 4),
        fermentationHours: 12,
      );
      final eight = computeIngredients(
        inputsFor(PizzaType.neapolitan, doughballs: 8),
        fermentationHours: 12,
      );

      expect(eight['flour'], closeTo(four['flour']! * 2, 0.01));
      expect(sum(eight), closeTo(2000.0, 0.01));
    });
  });

  group('yeast', () {
    test('a longer ferment needs less yeast', () {
      final inputs = inputsFor(PizzaType.neapolitan);
      final short = yeastPercent(inputs, hours: 4);
      final long = yeastPercent(inputs, hours: 16);
      expect(long, lessThan(short));
    });

    test('fresh yeast is roughly three times instant by weight', () {
      final fresh = yeastPercent(
        inputsFor(PizzaType.neapolitan, yeastType: 0),
        hours: 8,
      );
      final instant = yeastPercent(
        inputsFor(PizzaType.neapolitan, yeastType: 1),
        hours: 8,
      );
      expect(fresh / instant, closeTo(3.0, 0.01));
    });

    test('the bounds never bind anywhere in the range the UI allows', () {
      // The clamps in yeastPercent are guards on arbitrary input, not
      // features: the ratio is itself limited to 0.1–16, fermentation time has
      // a two-hour floor, and cold ferment is capped at five days. Across
      // everything a baker can actually select, the result is the raw formula
      // untouched. Warnings about hitting a bound were removed because of
      // this, if this test ever fails, the input ranges have moved and that
      // decision is worth revisiting.
      double raw(int mode, int yeastType, double hours) {
        final base = mode == 0
            ? (yeastType == 0 ? 0.9 : 0.3)
            : (yeastType == 0 ? 0.6 : 0.2);
        final reference = mode == 0 ? 8 : 24;
        return base * sqrt((reference / hours).clamp(0.1, 16.0));
      }

      for (final type in PizzaType.values) {
        for (final yeastType in [0, 1]) {
          // Same day spans two hours up to just over a day.
          for (final hours in [2.0, 8.0, 18.75, 26.0]) {
            expect(
              yeastPercent(inputsFor(type, yeastType: yeastType), hours: hours),
              closeTo(raw(0, yeastType, hours), 1e-9),
              reason: '${type.name} yeast $yeastType at ${hours}h same day',
            );
          }
          // Cold ferment is one to five days.
          for (final days in [1, 2, 3, 4, 5]) {
            final hours = days * 24.0;
            expect(
              yeastPercent(
                inputsFor(type, yeastType: yeastType, fermentationMode: 1),
                hours: hours,
              ),
              closeTo(raw(1, yeastType, hours), 1e-9),
              reason: '${type.name} yeast $yeastType at $days days',
            );
          }
        }
      }
    });

    test('poolish contributes no separate yeast', () {
      expect(
        yeastPercent(
          inputsFor(PizzaType.neapolitan, yeastType: 2),
          hours: 24,
        ),
        0.0,
      );
    });
  });

  group('fermentation hours', () {
    test('cold ferment counts the requested days', () {
      final hours = effectiveFermentationHours(
        inputsFor(PizzaType.newYork, fermentationMode: 1, coldFermentDays: 3),
        from: DateTime(2026, 3, 10, 20),
        targetBake: DateTime(2026, 3, 13, 19),
      );
      expect(hours, 72.0);
    });

    test('same day counts the span to the bake', () {
      final hours = effectiveFermentationHours(
        inputsFor(PizzaType.neapolitan),
        from: DateTime(2026, 3, 10, 8),
        targetBake: DateTime(2026, 3, 10, 20),
      );
      expect(hours, 12.0);
    });

    test('never sizes yeast for less than two hours', () {
      final hours = effectiveFermentationHours(
        inputsFor(PizzaType.neapolitan),
        from: DateTime(2026, 3, 10, 19),
        targetBake: DateTime(2026, 3, 10, 19, 30),
      );
      expect(hours, 2.0);
    });
  });

  group('dough warnings', () {
    final start = DateTime(2026, 3, 10, 8);

    test('an ordinary plan produces none', () {
      final issues = doughIssues(
        inputsFor(PizzaType.neapolitan),
        start: start,
        targetBake: start.add(const Duration(hours: 8)),
      );
      expect(issues, isEmpty);
    });

    test('poolish started too late is called out', () {
      final issues = doughIssues(
        inputsFor(PizzaType.neapolitan, yeastType: 2),
        start: start,
        targetBake: start.add(const Duration(hours: 6)),
      );
      expect(issues.single.severity, BakeIssueSeverity.warning);
      expect(issues.single.message, contains('24 hours ahead'));
    });

    test('poolish with a full day of lead time is fine', () {
      final issues = doughIssues(
        inputsFor(PizzaType.neapolitan, yeastType: 2),
        start: start,
        targetBake: start.add(const Duration(hours: 30)),
      );
      expect(issues, isEmpty);
    });

    test('no ferment length produces a warning on its own', () {
      // The yeast-bound warnings were removed as unreachable. Nothing about
      // the fermentation time alone should raise an issue any more.
      for (final mode in [0, 1]) {
        for (final hours in [2, 8, 26, 120]) {
          expect(
            doughIssues(
              inputsFor(PizzaType.neapolitan, fermentationMode: mode),
              start: start,
              targetBake: start.add(Duration(hours: hours)),
            ),
            isEmpty,
            reason: 'mode $mode at ${hours}h',
          );
        }
      }
    });
  });
}
