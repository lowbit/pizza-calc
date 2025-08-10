import 'package:flutter/cupertino.dart';

/// Pizza making step data structure
class PizzaStep {
  final String title;
  final List<String> instructions;

  const PizzaStep({required this.title, required this.instructions});
}

/// Steps display component with iOS-style collapsible sections
class StepsDisplay extends StatefulWidget {
  final String pizzaType;
  final bool isOvernightRise;

  const StepsDisplay({
    super.key,
    required this.pizzaType,
    required this.isOvernightRise,
  });

  @override
  State<StepsDisplay> createState() => _StepsDisplayState();
}

class _StepsDisplayState extends State<StepsDisplay> {
  bool _isExpanded = false;

  /// Get steps based on pizza type and rise time
  List<PizzaStep> _getSteps() {
    switch (widget.pizzaType.toLowerCase()) {
      case 'neapolitan':
        return _getNeapolitanSteps();
      case 'new york':
        return _getNewYorkSteps();
      case 'sicilian/detroit':
        return _getSicilianDetroitSteps();
      case 'roman':
        return _getRomanSteps();
      default:
        return _getTodoSteps();
    }
  }

  /// Neapolitan pizza steps
  List<PizzaStep> _getNeapolitanSteps() {
    return [
      const PizzaStep(
        title: 'Mix the dough',
        instructions: [
          'Dissolve the yeast in the water.',
          'Add ~80% of the flour gradually, mixing with your hand or a mixer at low speed.',
          'Add the salt once the dough starts to come together (never directly on yeast).',
          'Add the remaining flour and knead until smooth — about 15–20 min by hand or 10 min in a mixer. Dough should be soft but not sticky.',
        ],
      ),
      PizzaStep(
        title: 'Bulk ferment',
        instructions: widget.isOvernightRise
            ? [
                'Shape into one smooth dough ball, cover, and rest at room temp (20–25 °C) for 30–60 minutes.',
                'Transfer to the fridge at 4 °C for 12–24 hours.',
              ]
            : [
                'Shape into one smooth dough ball, cover, and rest at room temp (20–25 °C) for 2 hours.',
              ],
      ),
      PizzaStep(
        title: 'Balling',
        instructions: widget.isOvernightRise
            ? [
                'Remove from the fridge, divide into dough balls.',
                'Shape into tight, smooth balls (staglio a mano).',
                'Place in a proofing box or on a tray, lightly floured, and cover.',
              ]
            : [
                'Divide into doughballs.',
                'Shape into tight, smooth balls (staglio a mano).',
                'Place in a proofing box or on a tray, lightly floured, and cover.',
              ],
      ),
      PizzaStep(
        title: 'Final proof',
        instructions: widget.isOvernightRise
            ? [
                'Let rest at room temp for 2–3 hours until ready.',
                'You\'ll know they\'re ready when they are puffy, soft, and jiggle slightly if you shake the tray.',
              ]
            : [
                'Let rest at room temp until ready.',
                'You\'ll know they\'re ready when they are puffy, soft, and jiggle slightly if you shake the tray.',
              ],
      ),
      const PizzaStep(
        title: 'Shaping',
        instructions: [
          'Flour your work surface with Tipo 00 or semola rimacinata.',
          'Press the dough from the center outward, leaving a 2 cm rim (cornicione).',
          'Never use a rolling pin, only stretch by hand.',
        ],
      ),
    ];
  }

  /// New York pizza steps
  List<PizzaStep> _getNewYorkSteps() {
    if (widget.isOvernightRise) {
      // Overnight Cold-Rise New York Style
      return [
        const PizzaStep(
          title: 'Mix the dough',
          instructions: [
            'Dissolve the yeast and sugar in the water.',
            'Add ~80% of the flour gradually, mixing with your hand or a mixer at low speed.',
            'Add the salt and oil once the dough starts to come together (never directly on yeast).',
            'Add the remaining flour and knead until smooth — about 10–12 min by hand or 8–10 min in a mixer. Dough should be smooth, elastic, and slightly tacky.',
          ],
        ),
        const PizzaStep(
          title: 'Balling',
          instructions: [
            'Divide into dough balls (typically 250–350 g each).',
            'Shape into tight, smooth balls.',
            'Lightly oil each ball, place in individual containers or a covered proofing box.',
          ],
        ),
        const PizzaStep(
          title: 'Cold ferment',
          instructions: [
            'Refrigerate at 4 °C for 12–72 hours.',
          ],
        ),
        const PizzaStep(
          title: 'Final proof',
          instructions: [
            'Remove from fridge and let rest at room temp for 1–2 hours before shaping.',
          ],
        ),
        const PizzaStep(
          title: 'Shaping',
          instructions: [
            'Lightly flour your work surface.',
            'Press the dough from the center outward, leaving a 1.5–2 cm rim.',
            'Stretch gently by hand or use the backs of your hands to enlarge the round — do not roll with a pin.',
          ],
        ),
      ];
    } else {
      // Same-Day New York Style
      return [
        const PizzaStep(
          title: 'Mix the dough',
          instructions: [
            'Dissolve the yeast and sugar in the water.',
            'Add ~80% of the flour gradually, mixing with your hand or a mixer at low speed.',
            'Add the salt and oil once the dough starts to come together (never directly on yeast).',
            'Add the remaining flour and knead until smooth — about 10–12 min by hand or 8–10 min in a mixer. Dough should be smooth, elastic, and slightly tacky.',
          ],
        ),
        const PizzaStep(
          title: 'Bulk ferment',
          instructions: [
            'Shape into one smooth dough ball, cover, and rest at room temp (22–25 °C) for 1–2 hours, or until doubled in size.',
          ],
        ),
        const PizzaStep(
          title: 'Balling',
          instructions: [
            'Divide into dough balls (typically 250–350 g each).',
            'Shape into tight, smooth balls.',
            'Place in a proofing box or on a tray, lightly oiled or floured, and cover.',
          ],
        ),
        const PizzaStep(
          title: 'Final proof',
          instructions: [
            'Let rest at room temp for 1–2 hours until puffy and relaxed.',
          ],
        ),
        const PizzaStep(
          title: 'Shaping',
          instructions: [
            'Lightly flour your work surface.',
            'Press the dough from the center outward, leaving a 1.5–2 cm rim.',
            'Stretch gently by hand or use the backs of your hands to enlarge the round — do not roll with a pin.',
          ],
        ),
      ];
    }
  }

  /// Sicilian/Detroit pizza steps
  List<PizzaStep> _getSicilianDetroitSteps() {
    if (widget.isOvernightRise) {
      // Overnight Cold-Rise Sicilian/Detroit Style
      return [
        const PizzaStep(
          title: 'Mix the dough',
          instructions: [
            'Dissolve the yeast in the water.',
            'Add ~80% of the flour gradually, mixing with your hand or a mixer at low speed.',
            'Add the salt and oil once the dough starts to come together (never directly on yeast).',
            'Add the remaining flour and knead until smooth — about 12–15 min by hand or 8–10 min in a mixer. Dough should be soft, elastic, and slightly tacky.',
          ],
        ),
        const PizzaStep(
          title: 'Bulk ferment',
          instructions: [
            'Shape into one smooth dough ball, cover, and rest at room temp for 20–30 minutes.',
          ],
        ),
        const PizzaStep(
          title: 'Cold ferment',
          instructions: [
            'Place in a lightly oiled container, cover, and refrigerate at 4 °C for 12–48 hours.',
          ],
        ),
        const PizzaStep(
          title: 'Pan proofing',
          instructions: [
            'Remove from fridge and let warm at room temp for 1 hour.',
            'Generously oil your baking pan.',
            'Gently place the dough in the pan, pressing it out toward the edges.',
            'Cover and rest for 30–60 minutes, then stretch again to fully reach the corners.',
          ],
        ),
        const PizzaStep(
          title: 'Final proof',
          instructions: [
            'Cover and let rise at room temp for 2–3 hours, until puffy and airy.',
          ],
        ),
        const PizzaStep(
          title: 'Topping & baking',
          instructions: [
            'Top with cheese first, then sauce, and bake in a preheated 250–290 °C oven until the crust is golden and the cheese caramelizes at the edges.',
          ],
        ),
      ];
    } else {
      // Same-Day Sicilian/Detroit Style
      return [
        const PizzaStep(
          title: 'Mix the dough',
          instructions: [
            'Dissolve the yeast in the water.',
            'Add ~80% of the flour gradually, mixing with your hand or a mixer at low speed.',
            'Add the salt and oil once the dough starts to come together (never directly on yeast).',
            'Add the remaining flour and knead until smooth — about 12–15 min by hand or 8–10 min in a mixer. Dough should be soft, elastic, and slightly tacky.',
          ],
        ),
        const PizzaStep(
          title: 'Bulk ferment',
          instructions: [
            'Shape into one smooth dough ball, cover, and rest at room temp (22–25 °C) for 1–2 hours, or until nearly doubled.',
          ],
        ),
        const PizzaStep(
          title: 'Pan proofing',
          instructions: [
            'Generously oil your baking pan.',
            'Gently place the dough in the pan, pressing it out toward the edges without deflating too much.',
            'Cover and rest for 30 minutes, then stretch again to fully reach the corners if needed.',
          ],
        ),
        const PizzaStep(
          title: 'Final proof',
          instructions: [
            'Cover and let rise at room temp for 1–2 hours, until puffy and airy.',
          ],
        ),
        const PizzaStep(
          title: 'Topping & baking',
          instructions: [
            'Top with cheese first, then sauce, and bake in a preheated 250–290 °C oven until the crust is golden and the cheese caramelizes at the edges.',
          ],
        ),
      ];
    }
  }

  /// Roman Teglia (Tray Pizza) steps
  List<PizzaStep> _getRomanSteps() {
    if (widget.isOvernightRise) {
      // Overnight Cold-Rise Roman Style
      return [
        const PizzaStep(
          title: 'Mix the dough',
          instructions: [
            'Dissolve the yeast in the water.',
            'Add ~80% of the flour gradually, mixing with your hand or a mixer at low speed.',
            'Add the salt and olive oil once the dough starts to come together.',
            'Add the remaining flour and knead until smooth — about 15–20 min by hand or 10–12 min in a mixer. Dough will be very hydrated (75–80%) and sticky.',
          ],
        ),
        const PizzaStep(
          title: 'Bulk ferment',
          instructions: [
            'Cover and rest at room temp for 20–30 minutes, then refrigerate at 4 °C for 12–48 hours.',
          ],
        ),
        const PizzaStep(
          title: 'Pan proofing',
          instructions: [
            'Remove from fridge and let warm at room temp for 1 hour.',
            'Generously oil the baking tray.',
            'Gently tip the dough into the tray and stretch toward the edges.',
            'Cover and rest for 30–60 minutes, then finish stretching.',
          ],
        ),
        const PizzaStep(
          title: 'Final proof',
          instructions: [
            'Cover and let rest at room temp for 2–3 hours, until airy and puffy.',
          ],
        ),
        const PizzaStep(
          title: 'Topping & baking',
          instructions: [
            'Top as desired and bake at 250–300 °C until golden and crisp on the bottom.',
          ],
        ),
      ];
    } else {
      // Same-Day Roman Style
      return [
        const PizzaStep(
          title: 'Mix the dough',
          instructions: [
            'Dissolve the yeast in the water.',
            'Add ~80% of the flour gradually, mixing with your hand or a mixer at low speed.',
            'Add the salt and olive oil once the dough starts to come together.',
            'Add the remaining flour and knead until smooth — about 15–20 min by hand or 10–12 min in a mixer. Dough will be very hydrated (75–80%) and sticky.',
          ],
        ),
        const PizzaStep(
          title: 'Bulk ferment',
          instructions: [
            'Cover and rest at room temp for 2–3 hours, doing stretch & folds every 30 minutes during the first 1.5 hours.',
          ],
        ),
        const PizzaStep(
          title: 'Pan proofing',
          instructions: [
            'Generously oil the baking tray.',
            'Gently tip the dough into the tray and stretch toward the edges without deflating too much.',
            'Cover and rest for 30–60 minutes, then finish stretching if needed.',
          ],
        ),
        const PizzaStep(
          title: 'Final proof',
          instructions: [
            'Cover and let rest at room temp for 1–2 hours, until airy and puffy.',
          ],
        ),
        const PizzaStep(
          title: 'Topping & baking',
          instructions: [
            'Top as desired and bake at 250–300 °C until golden and crisp on the bottom.',
          ],
        ),
      ];
    }
  }

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
                child: Text(
                  step.title,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
