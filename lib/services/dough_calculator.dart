/// The dough maths, lifted out of the screen so it can be unit-tested and,
/// more importantly, frozen into a bake session. Once you've started mixing,
/// the flour weight must not drift because the clock moved.

library;

import 'dart:math' show sqrt;

import '../models/pizza_type.dart';
import 'bake_schedule.dart';

/// Everything the recipe is derived from.
class DoughInputs {
  final PizzaType pizzaType;
  final int doughballs;
  final double gramsPerBall;
  final double hydrationPercent;

  /// 0 = fresh, 1 = instant/active dry, 2 = poolish.
  final int yeastType;
  final double poolishAmount;

  /// 0 = same day (room temp), 1 = cold ferment (fridge).
  final int fermentationMode;
  final int coldFermentDays;
  final int targetBakeHour;
  final int targetBakeMinute;

  const DoughInputs({
    required this.pizzaType,
    required this.doughballs,
    required this.gramsPerBall,
    required this.hydrationPercent,
    required this.yeastType,
    required this.poolishAmount,
    required this.fermentationMode,
    required this.coldFermentDays,
    required this.targetBakeHour,
    required this.targetBakeMinute,
  });

  bool get isColdFerment => fermentationMode == 1;
  bool get usesPoolish => yeastType == 2;
  double get totalDoughWeight => doughballs * gramsPerBall;

  Map<String, dynamic> toJson() => {
    'pizzaType': pizzaType.name,
    'doughballs': doughballs,
    'gramsPerBall': gramsPerBall,
    'hydrationPercent': hydrationPercent,
    'yeastType': yeastType,
    'poolishAmount': poolishAmount,
    'fermentationMode': fermentationMode,
    'coldFermentDays': coldFermentDays,
    'targetBakeHour': targetBakeHour,
    'targetBakeMinute': targetBakeMinute,
  };

  factory DoughInputs.fromJson(Map<String, dynamic> json) => DoughInputs(
    pizzaType: PizzaType.fromName(json['pizzaType'] as String?),
    doughballs: json['doughballs'] as int,
    gramsPerBall: (json['gramsPerBall'] as num).toDouble(),
    hydrationPercent: (json['hydrationPercent'] as num).toDouble(),
    yeastType: json['yeastType'] as int,
    poolishAmount: (json['poolishAmount'] as num).toDouble(),
    fermentationMode: json['fermentationMode'] as int,
    coldFermentDays: json['coldFermentDays'] as int,
    targetBakeHour: json['targetBakeHour'] as int,
    targetBakeMinute: json['targetBakeMinute'] as int,
  );
}

/// Effective fermentation time used to size the yeast.
///
/// Same-day counts the whole span from starting to baking. Cold ferment counts
/// the requested days in the fridge, because the room-temperature tail is short
/// enough either side of it not to move the answer.
double effectiveFermentationHours(
  DoughInputs inputs, {
  required DateTime from,
  required DateTime targetBake,
}) {
  if (inputs.isColdFerment) return (inputs.coldFermentDays * 24).toDouble();
  final minutes = targetBake.difference(from).inMinutes;
  if (minutes < 120) return 2.0; // Never size yeast for less than two hours.
  return minutes / 60.0;
}

/// Yeast as a baker's percentage, scaled by fermentation time.
///
/// Yeast varies with the inverse square root of time: double the ferment, use
/// about 30% less yeast. Fresh yeast is roughly three times instant by weight.
///
/// The two clamps are guards on arbitrary input, not features. Neither binds
/// for any value the UI can produce, `effectiveFermentationHours` floors at
/// two hours and cold ferment is capped at five days, which keeps the result
/// comfortably inside the bounds. `dough_calculator_test.dart` pins that; if it
/// starts failing, the input ranges have moved and this needs revisiting.
double yeastPercent(DoughInputs inputs, {required double hours}) {
  if (inputs.usesPoolish) return 0.0;

  const baseForReference = {
    0: {0: 0.9, 1: 0.3}, // Same day, 8h reference
    1: {0: 0.6, 1: 0.2}, // Cold ferment, 24h reference
  };
  const referenceHours = {0: 8, 1: 24};
  const bounds = {
    0: [0.2, 2.5], // Fresh
    1: [0.05, 1.0], // Instant
  };

  final base = baseForReference[inputs.fermentationMode]?[inputs.yeastType] ?? 0.3;
  final reference = referenceHours[inputs.fermentationMode] ?? 8;
  final ratio = (reference / hours).clamp(0.1, 16.0);
  final raw = base * sqrt(ratio);

  final limits = bounds[inputs.yeastType] ?? const [0.05, 1.0];
  return raw.clamp(limits[0], limits[1]);
}

/// Warnings about the dough itself, as opposed to the schedule.
///
/// Only one, deliberately. The poolish lead time used to be static text that
/// never checked against your actual plan, so it is worth saying. Warnings
/// about the yeast bounds were tried and removed: they could not fire for any
/// input the UI can produce, and a warning that never appears is just noise in
/// the code.
List<BakeIssue> doughIssues(
  DoughInputs inputs, {
  required DateTime start,
  required DateTime targetBake,
}) {
  if (!inputs.usesPoolish) return const [];

  // Poolish is a 24h preferment; it has to exist before you mix.
  if (targetBake.difference(start) < const Duration(hours: 24)) {
    return const [
      BakeIssue(
        severity: BakeIssueSeverity.warning,
        message:
            'Poolish needs to be made 24 hours ahead. Mix it now and plan '
            'to build the dough tomorrow.',
      ),
    ];
  }

  return const [];
}

/// The ingredient list, in grams, keyed by ingredient.
///
/// Every value is derived from the flour weight via baker's percentages, which
/// is why the results always sum back to doughballs x gramsPerBall.
Map<String, double> computeIngredients(
  DoughInputs inputs, {
  required double fermentationHours,
}) {
  final config = inputs.pizzaType.config;
  final total = inputs.totalDoughWeight;

  if (inputs.usesPoolish) {
    // Poolish is 100% hydration, so it is half flour and half water. Both
    // halves come out of the totals you still need to weigh.
    final poolishFlour = inputs.poolishAmount / 2;
    final poolishWater = inputs.poolishAmount / 2;

    final multiplier =
        1 +
        (inputs.hydrationPercent / 100) +
        (config.saltPercent / 100) +
        (config.sugarPercent / 100) +
        (config.oilPercent / 100);
    final totalFlour = total / multiplier;
    final totalWater = totalFlour * (inputs.hydrationPercent / 100);

    return {
      'flour': totalFlour - poolishFlour,
      'water': totalWater - poolishWater,
      'salt': totalFlour * (config.saltPercent / 100),
      if (config.sugarPercent > 0)
        'sugar': totalFlour * (config.sugarPercent / 100),
      if (config.oilPercent > 0) 'oil': totalFlour * (config.oilPercent / 100),
      'poolish': inputs.poolishAmount,
    };
  }

  final yeast = yeastPercent(inputs, hours: fermentationHours);
  final multiplier =
      1 +
      (inputs.hydrationPercent / 100) +
      (config.saltPercent / 100) +
      (config.sugarPercent / 100) +
      (config.oilPercent / 100) +
      (yeast / 100);
  final flour = total / multiplier;

  return {
    'flour': flour,
    'water': flour * (inputs.hydrationPercent / 100),
    'salt': flour * (config.saltPercent / 100),
    if (config.sugarPercent > 0) 'sugar': flour * (config.sugarPercent / 100),
    if (config.oilPercent > 0) 'oil': flour * (config.oilPercent / 100),
    'yeast': flour * (yeast / 100),
  };
}
