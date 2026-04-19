import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Pizza making step data structure
class PizzaStep {
  final String title;
  final String? timeLabel;
  final List<String> instructions;

  const PizzaStep({
    required this.title,
    this.timeLabel,
    required this.instructions,
  });
}

/// Steps display component with iOS-style collapsible sections
class StepsDisplay extends StatefulWidget {
  final String pizzaType;
  final bool isColdFerment;
  final int coldFermentDays;
  final DateTime? targetBakeTime; // For same day mode
  final DateTime? planStartTime; // Snapshot of when the plan was created

  const StepsDisplay({
    super.key,
    required this.pizzaType,
    required this.isColdFerment,
    this.coldFermentDays = 2,
    this.targetBakeTime,
    this.planStartTime,
  });

  @override
  State<StepsDisplay> createState() => _StepsDisplayState();
}

class _StepsDisplayState extends State<StepsDisplay> {
  bool _isExpanded = false;

  // Format a DateTime to readable time (e.g., "19:00")
  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Get steps based on pizza type and fermentation mode
  List<PizzaStep> _getSteps() {
    List<PizzaStep> steps;
    switch (widget.pizzaType.toLowerCase()) {
      case 'neapolitan':
        steps = widget.isColdFerment
            ? _getColdFermentSteps(_neapolitanColdFerment)
            : _getSameDaySteps(_neapolitanSameDay);
      case 'new york':
        steps = widget.isColdFerment
            ? _getColdFermentSteps(_newYorkColdFerment)
            : _getSameDaySteps(_newYorkSameDay);
      case 'sicilian/detroit':
        steps = widget.isColdFerment
            ? _getColdFermentSteps(_sicilianColdFerment)
            : _getSameDaySteps(_sicilianSameDay);
      case 'roman':
        steps = widget.isColdFerment
            ? _getColdFermentSteps(_romanColdFerment)
            : _getSameDaySteps(_romanSameDay);
      default:
        return _getTodoSteps();
    }
    steps.add(_getFreezingStep());
    return steps;
  }

  PizzaStep _getFreezingStep() {
    final isPanStyle = widget.pizzaType.toLowerCase() == 'sicilian/detroit' ||
        widget.pizzaType.toLowerCase() == 'roman';

    final freezeWhen = widget.isColdFerment
        ? 'After cold ferment is complete'
        : isPanStyle
            ? 'After bulk ferment, before pan proofing'
            : 'After balling, before final proof';

    return PizzaStep(
      title: 'Freezing (optional)',
      instructions: [
        '$freezeWhen — lightly coat ${isPanStyle ? "the dough" : "each ball"} with olive oil.',
        'Wrap tightly in plastic wrap, then place in a freezer bag. Remove excess air.',
        'Freeze for up to 3 months (best quality within 4–6 weeks).',
        'To thaw: move to fridge for 24 hours, then rest at room temp for 2–3 hours before ${isPanStyle ? "stretching into the pan" : "shaping"}.',
      ],
    );
  }

  // ── Same Day step builders (with computed times from bake time) ──

  // Each config returns: (mixDurationMin, ballProofMin, extraSteps)
  // Timeline: mix → bulk ferment → ball → final proof → shape/bake

  List<PizzaStep> _getSameDaySteps(_SameDayConfig config) {
    final bakeTime = widget.targetBakeTime;
    if (bakeTime == null) return config.buildWithoutTimes();

    final startTime = widget.planStartTime ?? DateTime.now();
    final mixTime = startTime;
    final shapeTime = bakeTime.subtract(Duration(minutes: config.shapingMinBefore));
    final proofStart = shapeTime.subtract(Duration(minutes: config.finalProofMin));
    final ballTime = proofStart;
    final bulkEnd = ballTime;
    final bulkStart = mixTime.add(Duration(minutes: config.mixDuration));

    final bulkMinutes = bulkEnd.difference(bulkStart).inMinutes;

    return config.buildWithTimes(
      mixTime: _formatTime(mixTime),
      bulkStart: _formatTime(bulkStart),
      bulkEnd: _formatTime(bulkEnd),
      bulkDuration: _formatMinutes(bulkMinutes > 0 ? bulkMinutes : 0),
      ballTime: _formatTime(ballTime),
      proofEnd: _formatTime(shapeTime),
      proofDuration: _formatMinutes(config.finalProofMin),
      shapeTime: _formatTime(shapeTime),
      bakeTime: _formatTime(bakeTime),
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  // ── Cold Ferment step builders (with day labels) ──

  List<PizzaStep> _getColdFermentSteps(_ColdFermentConfig config) {
    final days = widget.coldFermentDays;
    return config.build(days);
  }

  // ══════════════════════════════════════════════════════════════
  //  NEAPOLITAN
  // ══════════════════════════════════════════════════════════════

  _SameDayConfig get _neapolitanSameDay => _SameDayConfig(
        mixDuration: 25,
        finalProofMin: 120,
        shapingMinBefore: 15,
        buildWithoutTimes: () => [
          const PizzaStep(
            title: 'Mix the dough',
            instructions: [
              'Dissolve the yeast in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add the salt and remaining flour. Mix until just combined — no heavy kneading needed.',
            ],
          ),
          const PizzaStep(
            title: 'Bulk ferment with stretch & folds',
            instructions: [
              'Shape into a rough ball, place in a lightly oiled bowl, and cover.',
              'After 5 min: do your first stretch & fold — pull each side up and over (N, S, E, W). Flip seam-side down.',
              'After 10 more min: second stretch & fold. The dough should already feel tighter.',
              'After ~1 hour: third and final stretch & fold. Dough should be smooth and hold its shape.',
              'Leave covered at room temp (20–25 °C) for the remaining bulk ferment time.',
            ],
          ),
          const PizzaStep(
            title: 'Ball the dough',
            instructions: [
              'Divide into dough balls and shape into tight, smooth balls.',
              'Place in a proofing box or tray, lightly floured, and cover.',
            ],
          ),
          const PizzaStep(
            title: 'Final proof',
            instructions: [
              'Let rest at room temp for ~2 hours until puffy and jiggly.',
            ],
          ),
          const PizzaStep(
            title: 'Shape & bake',
            instructions: [
              'Flour surface with Tipo 00 or semola rimacinata.',
              'Press from center outward, leaving a 2 cm rim. Never use a rolling pin.',
            ],
          ),
        ],
        buildWithTimes: ({
          required String mixTime,
          required String bulkStart,
          required String bulkEnd,
          required String bulkDuration,
          required String ballTime,
          required String proofEnd,
          required String proofDuration,
          required String shapeTime,
          required String bakeTime,
        }) => [
          PizzaStep(
            title: 'Mix the dough',
            timeLabel: 'Start now · $mixTime',
            instructions: const [
              'Dissolve the yeast in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add the salt and remaining flour. Mix until just combined — no heavy kneading needed.',
            ],
          ),
          PizzaStep(
            title: 'Bulk ferment with stretch & folds',
            timeLabel: '$bulkStart – $bulkEnd · $bulkDuration',
            instructions: const [
              'Shape into a rough ball, place in a lightly oiled bowl, and cover.',
              'After 5 min: do your first stretch & fold — pull each side up and over (N, S, E, W). Flip seam-side down.',
              'After 10 more min: second stretch & fold. The dough should already feel tighter.',
              'After ~1 hour: third and final stretch & fold. Dough should be smooth and hold its shape.',
              'Leave covered at room temp (20–25 °C) for the remaining bulk ferment time.',
            ],
          ),
          PizzaStep(
            title: 'Ball the dough',
            timeLabel: ballTime,
            instructions: const [
              'Divide into dough balls and shape into tight, smooth balls.',
              'Place in a proofing box or tray, lightly floured, and cover.',
            ],
          ),
          PizzaStep(
            title: 'Final proof',
            timeLabel: '$ballTime – $proofEnd · $proofDuration',
            instructions: const [
              'Let rest at room temp until puffy, soft, and jiggly when you shake the tray.',
            ],
          ),
          PizzaStep(
            title: 'Shape & bake',
            timeLabel: '$shapeTime – $bakeTime',
            instructions: const [
              'Flour surface with Tipo 00 or semola rimacinata.',
              'Press from center outward, leaving a 2 cm rim. Never use a rolling pin.',
            ],
          ),
        ],
      );

  _ColdFermentConfig get _neapolitanColdFerment => _ColdFermentConfig(
        build: (int days) => [
          const PizzaStep(
            title: 'Mix the dough',
            timeLabel: 'Day 1',
            instructions: [
              'Dissolve the yeast in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add the salt and remaining flour. Mix until just combined — no heavy kneading needed.',
            ],
          ),
          const PizzaStep(
            title: 'Stretch & folds, then fridge',
            timeLabel: 'Day 1 · after mixing',
            instructions: [
              'Shape into a rough ball, place in a lightly oiled bowl, and cover.',
              'After 5 min: first stretch & fold (N, S, E, W). Flip seam-side down.',
              'After 10 more min: second stretch & fold.',
              'After ~1 hour: third and final stretch & fold. Dough should be smooth.',
              'Transfer to an airtight container and refrigerate at 4 °C.',
            ],
          ),
          PizzaStep(
            title: 'Remove & ball',
            timeLabel: 'Day ${days + 1} · ~3h before baking',
            instructions: const [
              'Remove dough from fridge.',
              'Divide into balls and shape into tight, smooth rounds.',
              'Place on a floured tray, cover, and let warm up at room temp.',
            ],
          ),
          PizzaStep(
            title: 'Final proof',
            timeLabel: 'Day ${days + 1} · ~2h before baking',
            instructions: const [
              'Let rest at room temp until puffy, soft, and jiggly when you shake the tray.',
            ],
          ),
          PizzaStep(
            title: 'Shape & bake',
            timeLabel: 'Day ${days + 1}',
            instructions: const [
              'Flour surface with Tipo 00 or semola rimacinata.',
              'Press from center outward, leaving a 2 cm rim. Never use a rolling pin.',
            ],
          ),
        ],
      );

  // ══════════════════════════════════════════════════════════════
  //  NEW YORK
  // ══════════════════════════════════════════════════════════════

  _SameDayConfig get _newYorkSameDay => _SameDayConfig(
        mixDuration: 25,
        finalProofMin: 90,
        shapingMinBefore: 15,
        buildWithoutTimes: () => [
          const PizzaStep(
            title: 'Mix the dough',
            instructions: [
              'Dissolve yeast and sugar in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add salt, oil, and remaining flour. Knead until smooth and elastic — about 10–12 min by hand.',
            ],
          ),
          const PizzaStep(
            title: 'Bulk ferment',
            instructions: [
              'Shape into one smooth ball, cover, rest at room temp (22–25 °C) until doubled.',
            ],
          ),
          const PizzaStep(
            title: 'Ball the dough',
            instructions: [
              'Divide into balls (250–350 g each) and shape into tight, smooth rounds.',
              'Place on a lightly oiled tray, cover.',
            ],
          ),
          const PizzaStep(
            title: 'Final proof',
            instructions: [
              'Let rest at room temp for ~1.5 hours until puffy and relaxed.',
            ],
          ),
          const PizzaStep(
            title: 'Shape & bake',
            instructions: [
              'Lightly flour surface. Press from center outward, leaving a 1.5–2 cm rim.',
              'Stretch by hand — do not use a rolling pin.',
            ],
          ),
        ],
        buildWithTimes: ({
          required String mixTime,
          required String bulkStart,
          required String bulkEnd,
          required String bulkDuration,
          required String ballTime,
          required String proofEnd,
          required String proofDuration,
          required String shapeTime,
          required String bakeTime,
        }) => [
          PizzaStep(
            title: 'Mix the dough',
            timeLabel: 'Start now · $mixTime',
            instructions: const [
              'Dissolve yeast and sugar in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add salt, oil, and remaining flour. Knead until smooth and elastic — about 10–12 min by hand.',
            ],
          ),
          PizzaStep(
            title: 'Bulk ferment',
            timeLabel: '$bulkStart – $bulkEnd · $bulkDuration',
            instructions: const [
              'Shape into one smooth ball, cover, rest at room temp (22–25 °C) until doubled.',
            ],
          ),
          PizzaStep(
            title: 'Ball the dough',
            timeLabel: ballTime,
            instructions: const [
              'Divide into balls (250–350 g each) and shape into tight, smooth rounds.',
              'Place on a lightly oiled tray, cover.',
            ],
          ),
          PizzaStep(
            title: 'Final proof',
            timeLabel: '$ballTime – $proofEnd · $proofDuration',
            instructions: const [
              'Let rest at room temp until puffy and relaxed.',
            ],
          ),
          PizzaStep(
            title: 'Shape & bake',
            timeLabel: '$shapeTime – $bakeTime',
            instructions: const [
              'Lightly flour surface. Press from center outward, leaving a 1.5–2 cm rim.',
              'Stretch by hand — do not use a rolling pin.',
            ],
          ),
        ],
      );

  _ColdFermentConfig get _newYorkColdFerment => _ColdFermentConfig(
        build: (int days) => [
          const PizzaStep(
            title: 'Mix the dough',
            timeLabel: 'Day 1',
            instructions: [
              'Dissolve yeast and sugar in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add salt, oil, and remaining flour. Knead until smooth and elastic — about 10–12 min by hand.',
            ],
          ),
          const PizzaStep(
            title: 'Ball & fridge',
            timeLabel: 'Day 1 · after mixing',
            instructions: [
              'Divide into balls (250–350 g each) and shape.',
              'Lightly oil each ball, place in individual containers or covered proofing box.',
              'Refrigerate at 4 °C.',
            ],
          ),
          PizzaStep(
            title: 'Remove from fridge',
            timeLabel: 'Day ${days + 1} · ~2h before baking',
            instructions: const [
              'Remove balls from fridge.',
              'Let rest at room temp for 1.5–2 hours until relaxed and at room temperature.',
            ],
          ),
          PizzaStep(
            title: 'Shape & bake',
            timeLabel: 'Day ${days + 1}',
            instructions: const [
              'Lightly flour surface. Press from center outward, leaving a 1.5–2 cm rim.',
              'Stretch by hand — do not use a rolling pin.',
            ],
          ),
        ],
      );

  // ══════════════════════════════════════════════════════════════
  //  SICILIAN / DETROIT
  // ══════════════════════════════════════════════════════════════

  _SameDayConfig get _sicilianSameDay => _SameDayConfig(
        mixDuration: 25,
        finalProofMin: 150, // 2.5h for pan proof + final proof
        shapingMinBefore: 5,
        buildWithoutTimes: () => [
          const PizzaStep(
            title: 'Mix the dough',
            instructions: [
              'Dissolve yeast in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add salt, oil, and remaining flour. Mix until just combined. Dough will be soft and tacky.',
            ],
          ),
          const PizzaStep(
            title: 'Bulk ferment with stretch & folds',
            instructions: [
              'Place dough in a lightly oiled bowl, cover.',
              'After 5 min: first stretch & fold (N, S, E, W). Flip seam-side down.',
              'After 10 more min: second stretch & fold.',
              'After ~1 hour: third and final stretch & fold. Dough should feel much stronger.',
              'Leave covered at room temp (22–25 °C) until nearly doubled.',
            ],
          ),
          const PizzaStep(
            title: 'Pan & proof',
            instructions: [
              'Generously oil your baking pan.',
              'Place dough in pan, press toward edges. Cover and rest 30 min.',
              'Stretch again to reach corners, cover, and let rise for ~2h until puffy.',
            ],
          ),
          const PizzaStep(
            title: 'Top & bake',
            instructions: [
              'Top with cheese first, then sauce.',
              'Bake at 250–290 °C until crust is golden and cheese caramelizes at edges.',
            ],
          ),
        ],
        buildWithTimes: ({
          required String mixTime,
          required String bulkStart,
          required String bulkEnd,
          required String bulkDuration,
          required String ballTime,
          required String proofEnd,
          required String proofDuration,
          required String shapeTime,
          required String bakeTime,
        }) => [
          PizzaStep(
            title: 'Mix the dough',
            timeLabel: 'Start now · $mixTime',
            instructions: const [
              'Dissolve yeast in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add salt, oil, and remaining flour. Mix until just combined. Dough will be soft and tacky.',
            ],
          ),
          PizzaStep(
            title: 'Bulk ferment with stretch & folds',
            timeLabel: '$bulkStart – $bulkEnd · $bulkDuration',
            instructions: const [
              'Place dough in a lightly oiled bowl, cover.',
              'After 5 min: first stretch & fold (N, S, E, W). Flip seam-side down.',
              'After 10 more min: second stretch & fold.',
              'After ~1 hour: third and final stretch & fold. Dough should feel much stronger.',
              'Leave covered at room temp (22–25 °C) until nearly doubled.',
            ],
          ),
          PizzaStep(
            title: 'Pan & proof',
            timeLabel: '$ballTime – $proofEnd · $proofDuration',
            instructions: const [
              'Generously oil your baking pan.',
              'Place dough in pan, press toward edges. Cover and rest 30 min.',
              'Stretch again to reach corners, cover, and let rise until puffy.',
            ],
          ),
          PizzaStep(
            title: 'Top & bake',
            timeLabel: bakeTime,
            instructions: const [
              'Top with cheese first, then sauce.',
              'Bake at 250–290 °C until crust is golden and cheese caramelizes at edges.',
            ],
          ),
        ],
      );

  _ColdFermentConfig get _sicilianColdFerment => _ColdFermentConfig(
        build: (int days) => [
          const PizzaStep(
            title: 'Mix the dough',
            timeLabel: 'Day 1',
            instructions: [
              'Dissolve yeast in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add salt, oil, and remaining flour. Mix until just combined. Dough will be soft and tacky.',
            ],
          ),
          const PizzaStep(
            title: 'Stretch & folds, then fridge',
            timeLabel: 'Day 1 · after mixing',
            instructions: [
              'Place dough in a lightly oiled bowl, cover.',
              'After 5 min: first stretch & fold (N, S, E, W). Flip seam-side down.',
              'After 10 more min: second stretch & fold.',
              'After ~1 hour: third and final stretch & fold. Dough should feel much stronger.',
              'Place in a lightly oiled container, cover, and refrigerate at 4 °C.',
            ],
          ),
          PizzaStep(
            title: 'Remove & pan',
            timeLabel: 'Day ${days + 1} · ~4h before baking',
            instructions: const [
              'Remove dough from fridge, let warm at room temp for 1 hour.',
              'Generously oil baking pan. Place dough in pan, press toward edges.',
              'Cover, rest 30–60 min, then stretch again to reach corners.',
            ],
          ),
          PizzaStep(
            title: 'Final proof',
            timeLabel: 'Day ${days + 1} · ~2h before baking',
            instructions: const [
              'Cover and let rise at room temp for 2–3 hours, until puffy and airy.',
            ],
          ),
          PizzaStep(
            title: 'Top & bake',
            timeLabel: 'Day ${days + 1}',
            instructions: const [
              'Top with cheese first, then sauce.',
              'Bake at 250–290 °C until crust is golden and cheese caramelizes at edges.',
            ],
          ),
        ],
      );

  // ══════════════════════════════════════════════════════════════
  //  ROMAN
  // ══════════════════════════════════════════════════════════════

  _SameDayConfig get _romanSameDay => _SameDayConfig(
        mixDuration: 30,
        finalProofMin: 150,
        shapingMinBefore: 5,
        buildWithoutTimes: () => [
          const PizzaStep(
            title: 'Mix the dough',
            instructions: [
              'Dissolve yeast in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add salt, olive oil, and remaining flour. Knead 15–20 min by hand. Dough will be very hydrated and sticky.',
            ],
          ),
          const PizzaStep(
            title: 'Bulk ferment',
            instructions: [
              'Cover, rest at room temp for 2–3 hours.',
              'Do stretch & folds every 30 min during the first 1.5 hours.',
            ],
          ),
          const PizzaStep(
            title: 'Pan & proof',
            instructions: [
              'Generously oil the baking tray.',
              'Tip dough into tray and stretch toward edges. Cover, rest 30–60 min.',
              'Finish stretching if needed. Cover and let rise 1–2h until airy.',
            ],
          ),
          const PizzaStep(
            title: 'Top & bake',
            instructions: [
              'Top as desired.',
              'Bake at 250–300 °C until golden and crisp on the bottom.',
            ],
          ),
        ],
        buildWithTimes: ({
          required String mixTime,
          required String bulkStart,
          required String bulkEnd,
          required String bulkDuration,
          required String ballTime,
          required String proofEnd,
          required String proofDuration,
          required String shapeTime,
          required String bakeTime,
        }) => [
          PizzaStep(
            title: 'Mix the dough',
            timeLabel: 'Start now · $mixTime',
            instructions: const [
              'Dissolve yeast in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add salt, olive oil, and remaining flour. Knead 15–20 min by hand. Dough will be very hydrated and sticky.',
            ],
          ),
          PizzaStep(
            title: 'Bulk ferment',
            timeLabel: '$bulkStart – $bulkEnd · $bulkDuration',
            instructions: const [
              'Cover, rest at room temp. Do stretch & folds every 30 min during the first 1.5 hours.',
            ],
          ),
          PizzaStep(
            title: 'Pan & proof',
            timeLabel: '$ballTime – $proofEnd · $proofDuration',
            instructions: const [
              'Generously oil the baking tray.',
              'Tip dough into tray and stretch toward edges. Cover, rest 30–60 min.',
              'Finish stretching if needed. Cover and let rise until airy and puffy.',
            ],
          ),
          PizzaStep(
            title: 'Top & bake',
            timeLabel: bakeTime,
            instructions: const [
              'Top as desired.',
              'Bake at 250–300 °C until golden and crisp on the bottom.',
            ],
          ),
        ],
      );

  _ColdFermentConfig get _romanColdFerment => _ColdFermentConfig(
        build: (int days) => [
          const PizzaStep(
            title: 'Mix the dough',
            timeLabel: 'Day 1',
            instructions: [
              'Dissolve yeast in the water.',
              'Add about half the flour, mix until a rough paste forms.',
              'Rest 5 minutes — lets gluten develop before salt slows it down.',
              'Add salt, olive oil, and remaining flour. Knead 15–20 min by hand. Dough will be very hydrated and sticky.',
            ],
          ),
          const PizzaStep(
            title: 'Bulk ferment & fridge',
            timeLabel: 'Day 1 · after mixing',
            instructions: [
              'Cover, rest at room temp for 20–30 min.',
              'Transfer to an oiled container and refrigerate at 4 °C.',
            ],
          ),
          PizzaStep(
            title: 'Remove & pan',
            timeLabel: 'Day ${days + 1} · ~4h before baking',
            instructions: const [
              'Remove dough from fridge, let warm at room temp for 1 hour.',
              'Generously oil the baking tray.',
              'Tip dough into tray and stretch toward edges. Cover, rest 30–60 min.',
              'Finish stretching if needed.',
            ],
          ),
          PizzaStep(
            title: 'Final proof',
            timeLabel: 'Day ${days + 1} · ~2h before baking',
            instructions: const [
              'Cover and let rest at room temp for 2–3 hours, until airy and puffy.',
            ],
          ),
          PizzaStep(
            title: 'Top & bake',
            timeLabel: 'Day ${days + 1}',
            instructions: const [
              'Top as desired.',
              'Bake at 250–300 °C until golden and crisp on the bottom.',
            ],
          ),
        ],
      );

  /// Placeholder steps for other pizza types
  List<PizzaStep> _getTodoSteps() {
    return [
      PizzaStep(
        title: 'Steps for ${widget.pizzaType}',
        instructions: [
          'TODO: Add specific steps for ${widget.pizzaType} pizza',
          'Coming soon...',
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _getSteps();

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5),
        ),
        child: Column(
          children: [
            // Header with expand/collapse button
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Steps',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      CupertinoIcons.chevron_down,
                      color: CupertinoColors.systemBlue,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            // Expandable content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  children: steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    return _buildStepSection(step, index + 1);
                  }).toList(),
                ),
              ),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepSection(PizzaStep step, int stepNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step title with number
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    stepNumber.toString(),
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (step.timeLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.timeLabel!,
                        style: const TextStyle(
                          color: CupertinoColors.systemBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Step instructions
          ...step.instructions.map(
            (instruction) => Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: CupertinoColors.systemBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      instruction,
                      style: const TextStyle(
                        color: Color(0xFFE5E5E7),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper config classes ──

class _SameDayConfig {
  final int mixDuration;
  final int finalProofMin;
  final int shapingMinBefore;
  final List<PizzaStep> Function() buildWithoutTimes;
  final List<PizzaStep> Function({
    required String mixTime,
    required String bulkStart,
    required String bulkEnd,
    required String bulkDuration,
    required String ballTime,
    required String proofEnd,
    required String proofDuration,
    required String shapeTime,
    required String bakeTime,
  }) buildWithTimes;

  const _SameDayConfig({
    required this.mixDuration,
    required this.finalProofMin,
    required this.shapingMinBefore,
    required this.buildWithoutTimes,
    required this.buildWithTimes,
  });
}

class _ColdFermentConfig {
  final List<PizzaStep> Function(int days) build;

  const _ColdFermentConfig({required this.build});
}
