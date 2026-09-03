/// The editable recipe form, shown only while planning.
///
/// Extracted from `main.dart`, which had grown to well over a thousand lines
/// doing state, persistence and all view building at once. This is pure view:
/// every value comes in, every change goes out.

library;

import 'package:flutter/material.dart';

import '../services/bake_schedule.dart';
import '../styles/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/app_scaffolding.dart';
import '../widgets/enhanced_slider.dart';
import '../widgets/picker_input.dart';
import '../widgets/segmented_control_section.dart';
import 'bake_time_card.dart';

class DoughSettingsSection extends StatelessWidget {
  final int doughballs;
  final double gramsPerBall;
  final double hydrationPercent;
  final int fermentationMode;
  final int coldFermentDays;
  final int yeastType;
  final double poolishAmount;
  final DateTime plannedTargetBake;

  /// Only for the "mix at …" line under the bake time. The schedule itself is
  /// rendered by the checklist.
  final BakeSchedule schedule;

  final ValueChanged<int> onDoughballs;
  final VoidCallback onDoughballsTap;
  final ValueChanged<double> onWeight;
  final VoidCallback onWeightTap;
  final ValueChanged<double> onHydration;
  final VoidCallback onHydrationTap;
  final ValueChanged<int?> onFermentationMode;
  final ValueChanged<int> onColdFermentDays;
  final VoidCallback onColdFermentDaysTap;
  final VoidCallback onBakeTimeTap;
  final ValueChanged<int?> onYeastType;
  final VoidCallback onPoolishTap;

  const DoughSettingsSection({
    super.key,
    required this.doughballs,
    required this.gramsPerBall,
    required this.hydrationPercent,
    required this.fermentationMode,
    required this.coldFermentDays,
    required this.yeastType,
    required this.poolishAmount,
    required this.plannedTargetBake,
    required this.schedule,
    required this.onDoughballs,
    required this.onDoughballsTap,
    required this.onWeight,
    required this.onWeightTap,
    required this.onHydration,
    required this.onHydrationTap,
    required this.onFermentationMode,
    required this.onColdFermentDays,
    required this.onColdFermentDaysTap,
    required this.onBakeTimeTap,
    required this.onYeastType,
    required this.onPoolishTap,
  });

  /// "Mix at 12:35 · in 6h 25m", the answer to the question you opened the
  /// app with, which the bake time alone does not give you.
  ///
  /// When the answer is "right now" it says only that: "Mix at 19:17 · now"
  /// makes you read a clock time to learn something the word already told you.
  String? get _mixCaption {
    if (schedule.steps.isEmpty) return null;
    // An impossible plan must not read as a perfectly good one. The banner and
    // the disabled start button both live below the fold, past the whole dough
    // form, so without this the top of the screen cheerfully says "Mix now"
    // about a bake that cannot happen. The detail and the way out stay in the
    // banner; the card's job is to stop contradicting it.
    if (schedule.hasError) return 'Not enough time before this bake';
    final mixAt = schedule.steps.first.start;
    final relative = formatRelative(mixAt, DateTime.now());
    if (relative == 'now') return 'Mix now';
    return 'Mix at ${formatClock(mixAt)} · $relative';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Above the dough settings, not among them: bake time is not a property
        // of the dough, it is the anchor every other number is derived from.
        BakeTimeCard(
          targetBake: plannedTargetBake,
          onTap: onBakeTimeTap,
          caption: _mixCaption,
          captionIsWarning: schedule.hasError,
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Dough'),
        const SizedBox(height: AppSpacing.md),
        PickerInput(
          title: 'Doughballs',
          value: '$doughballs',
          onTap: onDoughballsTap,
          onDecrease: doughballs > 1 ? () => onDoughballs(doughballs - 1) : null,
          onIncrease: doughballs < 50 ? () => onDoughballs(doughballs + 1) : null,
        ),
        const SizedBox(height: AppSpacing.md),
        PickerInput(
          title: 'Grams per ball',
          value: '${gramsPerBall.round()}g',
          onTap: onWeightTap,
          onDecrease: gramsPerBall > 150 ? () => onWeight(gramsPerBall - 10) : null,
          onIncrease: gramsPerBall < 1000 ? () => onWeight(gramsPerBall + 10) : null,
        ),
        const SizedBox(height: AppSpacing.md),
        EnhancedSlider(
          title: 'Hydration',
          value: hydrationPercent,
          displayValue: '${hydrationPercent.round()}%',
          min: 55.0,
          max: 80.0,
          divisions: 25,
          onChanged: onHydration,
          onTap: onHydrationTap,
          markers: const ['55%', '65%', '75%', '80%'],
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedControlSection<int>(
          title: 'Fermentation',
          groupValue: fermentationMode,
          onValueChanged: onFermentationMode,
          options: const {0: 'Same day', 1: 'Cold ferment'},
        ),
        const SizedBox(height: AppSpacing.md),
        if (fermentationMode == 1) ...[
          PickerInput(
            title: 'Days in fridge',
            value: '$coldFermentDays ${coldFermentDays == 1 ? 'day' : 'days'}',
            onTap: onColdFermentDaysTap,
            onDecrease: coldFermentDays > 1
                ? () => onColdFermentDays(coldFermentDays - 1)
                : null,
            onIncrease: coldFermentDays < 5
                ? () => onColdFermentDays(coldFermentDays + 1)
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        SegmentedControlSection<int>(
          // Not just "Yeast": that would collide with the Yeast ingredient row
          // both visually and for anything searching by label.
          title: 'Yeast type',
          groupValue: yeastType,
          onValueChanged: onYeastType,
          options: const {0: 'Fresh', 1: 'Instant', 2: 'Poolish'},
        ),
        if (yeastType == 2) ...[
          const SizedBox(height: AppSpacing.sm),
          ValueRow(
            label: 'Poolish amount',
            value: '${poolishAmount.round()}g',
            onTap: onPoolishTap,
          ),
        ],
      ],
    );
  }
}
