/// Recipe definitions: the ordered steps for each style and fermentation mode.
///
/// Durations here are what the scheduler plans against. Exactly one step per
/// recipe is flexible and absorbs the slack: the bulk ferment for same-day
/// doughs, the fridge stretch for cold ferments. The fixed steps around it are
/// what determine whether a bake is feasible at all.
///
/// Step ids are persisted and used to derive notification ids, so they must
/// stay stable across releases even if titles change.

library;

import '../models/bake_step.dart';
import '../models/pizza_type.dart';

/// Shortest fridge time that still produces a recognisable cold ferment.
const int _minColdFermentMinutes = 12 * 60;

/// Shortest bulk ferment worth calling one.
const int _minBulkMinutes = 60;

/// Longest a bulk ferment can run at room temperature before the dough is
/// over-fermented rather than merely well developed. Past this it slackens,
/// goes boozy, and tears instead of stretching, and no amount of yeast
/// reduction rescues it.
///
/// This one really can be reached: a same-day target rolls to the next
/// occurrence of the bake hour, so asking at 23:00 for a 19:00 bake hands the
/// bulk ferment the better part of a day. The fridge steps need no such bound,
/// their length is capped by the days picker.
///
/// Deliberately well past the point a chef would *choose*, because the warning
/// has to stay rare to mean anything. Mixing at breakfast for an eight o'clock
/// dinner is a 9h bulk and completely normal, so a tighter bound would fire on
/// the most ordinary plan there is. The yeast curve has already thinned the
/// dose by this point; 12h is where that stops being enough.
const int _maxBulkMinutes = 12 * 60;

/// Floors for the steps where the *dough* needs the time, not the baker.
/// Below these, the step has not really happened, whatever the clock says.
/// Deliberately generous: they exist to catch a mis-tap or a badly rushed
/// bake, not to second-guess a warm kitchen. See [StepSpec.floorMinutes].
const int _minProofMinutes = 45;
const int _minLongFoldsMinutes = 20;
const int _minWarmUpMinutes = 30;

/// The ordered, timed steps for a style in a given mode.
List<StepSpec> stepsFor(PizzaType type, {required bool isColdFerment}) {
  switch (type) {
    case PizzaType.neapolitan:
      return isColdFerment ? _neapolitanCold : _neapolitanSameDay;
    case PizzaType.newYork:
      return isColdFerment ? _newYorkCold : _newYorkSameDay;
    case PizzaType.sicilian:
      return isColdFerment ? _sicilianCold : _sicilianSameDay;
    case PizzaType.roman:
      return isColdFerment ? _romanCold : _romanSameDay;
  }
}

/// Freezing advice. Reference material, not a timed step, so it is kept out of
/// the checklist. The wording depends on where in the process you'd freeze.
StepSpec freezingNote(PizzaType type, {required bool isColdFerment}) {
  final isPan = type.isPanStyle;
  final freezeWhen = isColdFerment
      ? 'After cold ferment is complete'
      : isPan
      ? 'After bulk ferment, before pan proofing'
      : 'After balling, before final proof';

  return StepSpec(
    id: 'freezing',
    title: 'Freezing (optional)',
    timing: const FixedDuration(0),
    optional: true,
    instructions: [
      '$freezeWhen. Lightly coat ${isPan ? "the dough" : "each ball"} with olive oil.',
      'Wrap tightly in plastic wrap, then place in a freezer bag. Remove excess air.',
      'Freeze for up to 3 months (best quality within 4–6 weeks).',
      'To thaw: move to fridge for 24 hours, then rest at room temp for 2–3 hours before ${isPan ? "stretching into the pan" : "shaping"}.',
    ],
  );
}

// ══════════════════════════════════════════════════════════════
//  NEAPOLITAN
// ══════════════════════════════════════════════════════════════

const List<StepSpec> _neapolitanSameDay = [
  StepSpec(
    id: 'mix',
    title: 'Mix the dough',
    timing: FixedDuration(25),
    instructions: [
      'Dissolve the yeast in the water.',
      'Add about half the flour, mix until a rough paste forms.',
      'Rest 5 minutes. Lets gluten develop before salt slows it down.',
      'Add the salt and remaining flour. Mix until just combined, no heavy kneading needed.',
    ],
  ),
  StepSpec(
    id: 'bulk',
    title: 'Bulk ferment with stretch & folds',
    timing: FlexibleDuration(
      minMinutes: _minBulkMinutes,
      maxMinutes: _maxBulkMinutes,
    ),
    instructions: [
      'Shape into a rough ball, place in a lightly oiled bowl, and cover.',
      'After 5 min: do your first stretch & fold: pull each side up and over (N, S, E, W). Flip seam-side down.',
      'After 10 more min: second stretch & fold. The dough should already feel tighter.',
      'After ~1 hour: third and final stretch & fold. Dough should be smooth and hold its shape.',
      'Leave covered at room temp (20–25 °C) for the remaining bulk ferment time.',
    ],
  ),
  StepSpec(
    id: 'ball',
    title: 'Ball the dough',
    timing: FixedDuration(10),
    instructions: [
      'Divide into dough balls and shape into tight, smooth balls.',
      'Place in a proofing box or tray, lightly floured, and cover.',
    ],
  ),
  StepSpec(
    id: 'proof',
    title: 'Final proof',
    timing: FixedDuration(120),
    floorMinutes: _minProofMinutes,
    instructions: [
      'Let rest at room temp until puffy, soft, and jiggly when you shake the tray.',
    ],
  ),
  StepSpec(
    id: 'bake',
    title: 'Shape & bake',
    timing: FixedDuration(15),
    instructions: [
      'Flour surface with Tipo 00 or semola rimacinata.',
      'Press from center outward, leaving a 2 cm rim. Never use a rolling pin.',
      'Top sparingly: crushed tomato, torn fior di latte, basil, a little oil. A wet centre will not cook through.',
      'Pizza oven: 430–480 °C. Each pizza bakes in 60–90 seconds, turning every 20 seconds or so.',
      'Home oven: stone or steel on an upper rack, preheated 45 min at max heat. 6–8 minutes each.',
    ],
  ),
];

const List<StepSpec> _neapolitanCold = [
  StepSpec(
    id: 'mix',
    title: 'Mix the dough',
    timing: FixedDuration(25),
    instructions: [
      'Dissolve the yeast in the water.',
      'Add about half the flour, mix until a rough paste forms.',
      'Rest 5 minutes. Lets gluten develop before salt slows it down.',
      'Add the salt and remaining flour. Mix until just combined, no heavy kneading needed.',
    ],
  ),
  StepSpec(
    id: 'folds',
    title: 'Stretch & folds, then fridge',
    timing: FixedDuration(75),
    floorMinutes: _minLongFoldsMinutes,
    instructions: [
      'Shape into a rough ball, place in a lightly oiled bowl, and cover.',
      'After 5 min: first stretch & fold (N, S, E, W). Flip seam-side down.',
      'After 10 more min: second stretch & fold.',
      'After ~1 hour: third and final stretch & fold. Dough should be smooth.',
      'Transfer to an airtight container and refrigerate at 4 °C.',
    ],
  ),
  StepSpec(
    id: 'fridge',
    title: 'Cold ferment',
    timing: FlexibleDuration(minMinutes: _minColdFermentMinutes),
    instructions: [
      'Leave undisturbed at 4 °C. This is where the flavour develops.',
      'The dough will rise slowly and should look domed and bubbly by the end.',
    ],
  ),
  StepSpec(
    id: 'ball',
    title: 'Remove & ball',
    timing: FixedDuration(60),
    floorMinutes: _minWarmUpMinutes,
    instructions: [
      'Remove dough from fridge.',
      'Divide into balls and shape into tight, smooth rounds.',
      'Place on a floured tray, cover, and let warm up at room temp.',
    ],
  ),
  StepSpec(
    id: 'proof',
    title: 'Final proof',
    timing: FixedDuration(105),
    floorMinutes: _minProofMinutes,
    instructions: [
      'Let rest at room temp until puffy, soft, and jiggly when you shake the tray.',
    ],
  ),
  StepSpec(
    id: 'bake',
    title: 'Shape & bake',
    timing: FixedDuration(15),
    instructions: [
      'Flour surface with Tipo 00 or semola rimacinata.',
      'Press from center outward, leaving a 2 cm rim. Never use a rolling pin.',
      'Top sparingly: crushed tomato, torn fior di latte, basil, a little oil. A wet centre will not cook through.',
      'Pizza oven: 430–480 °C. Each pizza bakes in 60–90 seconds, turning every 20 seconds or so.',
      'Home oven: stone or steel on an upper rack, preheated 45 min at max heat. 6–8 minutes each.',
    ],
  ),
];

// ══════════════════════════════════════════════════════════════
//  NEW YORK
// ══════════════════════════════════════════════════════════════

const List<StepSpec> _newYorkSameDay = [
  StepSpec(
    id: 'mix',
    title: 'Mix the dough',
    timing: FixedDuration(25),
    instructions: [
      'Dissolve yeast and sugar in the water.',
      'Add about half the flour, mix until a rough paste forms.',
      'Rest 5 minutes. Lets gluten develop before salt slows it down.',
      'Add salt, oil, and remaining flour. Knead until smooth and elastic, about 10–12 min by hand.',
    ],
  ),
  StepSpec(
    id: 'bulk',
    title: 'Bulk ferment',
    timing: FlexibleDuration(
      minMinutes: _minBulkMinutes,
      maxMinutes: _maxBulkMinutes,
    ),
    instructions: [
      'Shape into one smooth ball, cover, rest at room temp (22–25 °C) until doubled.',
    ],
  ),
  StepSpec(
    id: 'ball',
    title: 'Ball the dough',
    timing: FixedDuration(10),
    instructions: [
      'Divide into balls (250–350 g each) and shape into tight, smooth rounds.',
      'Place on a lightly oiled tray, cover.',
    ],
  ),
  StepSpec(
    id: 'proof',
    title: 'Final proof',
    timing: FixedDuration(90),
    floorMinutes: _minProofMinutes,
    instructions: ['Let rest at room temp until puffy and relaxed.'],
  ),
  StepSpec(
    id: 'bake',
    title: 'Shape & bake',
    timing: FixedDuration(15),
    instructions: [
      'Lightly flour surface. Press from center outward, leaving a 1.5–2 cm rim.',
      'Stretch by hand, not a rolling pin.',
      'Sauce first, then low-moisture mozzarella to the edge of the sauce.',
      'Bake at 260–290 °C on a stone or steel, 10–14 minutes each, until the underside is set and the cheese is blistered.',
    ],
  ),
];

const List<StepSpec> _newYorkCold = [
  StepSpec(
    id: 'mix',
    title: 'Mix the dough',
    timing: FixedDuration(25),
    instructions: [
      'Dissolve yeast and sugar in the water.',
      'Add about half the flour, mix until a rough paste forms.',
      'Rest 5 minutes. Lets gluten develop before salt slows it down.',
      'Add salt, oil, and remaining flour. Knead until smooth and elastic, about 10–12 min by hand.',
    ],
  ),
  StepSpec(
    id: 'folds',
    title: 'Ball & fridge',
    timing: FixedDuration(20),
    instructions: [
      'Divide into balls (250–350 g each) and shape.',
      'Lightly oil each ball, place in individual containers or covered proofing box.',
      'Refrigerate at 4 °C.',
    ],
  ),
  StepSpec(
    id: 'fridge',
    title: 'Cold ferment',
    timing: FlexibleDuration(minMinutes: _minColdFermentMinutes),
    instructions: [
      'Leave undisturbed at 4 °C. This is where the flavour develops.',
      'The balls will relax and puff slightly over the days in the fridge.',
    ],
  ),
  StepSpec(
    id: 'proof',
    title: 'Remove from fridge',
    timing: FixedDuration(105),
    floorMinutes: _minProofMinutes,
    instructions: [
      'Remove balls from fridge.',
      'Let rest at room temp for 1.5–2 hours until relaxed and at room temperature.',
    ],
  ),
  StepSpec(
    id: 'bake',
    title: 'Shape & bake',
    timing: FixedDuration(15),
    instructions: [
      'Lightly flour surface. Press from center outward, leaving a 1.5–2 cm rim.',
      'Stretch by hand, not a rolling pin.',
      'Sauce first, then low-moisture mozzarella to the edge of the sauce.',
      'Bake at 260–290 °C on a stone or steel, 10–14 minutes each, until the underside is set and the cheese is blistered.',
    ],
  ),
];

// ══════════════════════════════════════════════════════════════
//  SICILIAN / DETROIT
// ══════════════════════════════════════════════════════════════

const List<StepSpec> _sicilianSameDay = [
  StepSpec(
    id: 'mix',
    title: 'Mix the dough',
    timing: FixedDuration(25),
    instructions: [
      'Dissolve yeast in the water.',
      'Add about half the flour, mix until a rough paste forms.',
      'Rest 5 minutes. Lets gluten develop before salt slows it down.',
      'Add salt, oil, and remaining flour. Mix until just combined. Dough will be soft and tacky.',
    ],
  ),
  StepSpec(
    id: 'bulk',
    title: 'Bulk ferment with stretch & folds',
    timing: FlexibleDuration(
      minMinutes: _minBulkMinutes,
      maxMinutes: _maxBulkMinutes,
    ),
    instructions: [
      'Place dough in a lightly oiled bowl, cover.',
      'After 5 min: first stretch & fold (N, S, E, W). Flip seam-side down.',
      'After 10 more min: second stretch & fold.',
      'After ~1 hour: third and final stretch & fold. Dough should feel much stronger.',
      'Leave covered at room temp (22–25 °C) until nearly doubled.',
    ],
  ),
  StepSpec(
    id: 'proof',
    title: 'Pan & proof',
    timing: FixedDuration(150),
    floorMinutes: _minProofMinutes,
    instructions: [
      'Generously oil your baking pan.',
      'Place dough in pan, press toward edges. Cover and rest 30 min.',
      'Stretch again to reach corners, cover, and let rise until puffy.',
    ],
  ),
  StepSpec(
    id: 'bake',
    title: 'Top & bake',
    timing: FixedDuration(5),
    instructions: [
      'Top with cheese first, then sauce.',
      'Bake at 250–290 °C until crust is golden and cheese caramelizes at edges.',
    ],
  ),
];

const List<StepSpec> _sicilianCold = [
  StepSpec(
    id: 'mix',
    title: 'Mix the dough',
    timing: FixedDuration(25),
    instructions: [
      'Dissolve yeast in the water.',
      'Add about half the flour, mix until a rough paste forms.',
      'Rest 5 minutes. Lets gluten develop before salt slows it down.',
      'Add salt, oil, and remaining flour. Mix until just combined. Dough will be soft and tacky.',
    ],
  ),
  StepSpec(
    id: 'folds',
    title: 'Stretch & folds, then fridge',
    timing: FixedDuration(75),
    floorMinutes: _minLongFoldsMinutes,
    instructions: [
      'Place dough in a lightly oiled bowl, cover.',
      'After 5 min: first stretch & fold (N, S, E, W). Flip seam-side down.',
      'After 10 more min: second stretch & fold.',
      'After ~1 hour: third and final stretch & fold. Dough should feel much stronger.',
      'Place in a lightly oiled container, cover, and refrigerate at 4 °C.',
    ],
  ),
  StepSpec(
    id: 'fridge',
    title: 'Cold ferment',
    timing: FlexibleDuration(minMinutes: _minColdFermentMinutes),
    instructions: [
      'Leave undisturbed at 4 °C. This is where the flavour develops.',
      'The dough will rise slowly and should look domed and bubbly by the end.',
    ],
  ),
  StepSpec(
    id: 'pan',
    title: 'Remove & pan',
    timing: FixedDuration(120),
    floorMinutes: _minProofMinutes,
    instructions: [
      'Remove dough from fridge, let warm at room temp for 1 hour.',
      'Generously oil baking pan. Place dough in pan, press toward edges.',
      'Cover, rest 30–60 min, then stretch again to reach corners.',
    ],
  ),
  StepSpec(
    id: 'proof',
    title: 'Final proof',
    timing: FixedDuration(115),
    floorMinutes: _minProofMinutes,
    instructions: [
      'Cover and let rise at room temp for 2–3 hours, until puffy and airy.',
    ],
  ),
  StepSpec(
    id: 'bake',
    title: 'Top & bake',
    timing: FixedDuration(5),
    instructions: [
      'Top with cheese first, then sauce.',
      'Bake at 250–290 °C until crust is golden and cheese caramelizes at edges.',
    ],
  ),
];

// ══════════════════════════════════════════════════════════════
//  ROMAN
// ══════════════════════════════════════════════════════════════

const List<StepSpec> _romanSameDay = [
  StepSpec(
    id: 'mix',
    title: 'Mix the dough',
    timing: FixedDuration(30),
    instructions: [
      'Dissolve yeast in the water.',
      'Add about half the flour, mix until a rough paste forms.',
      'Rest 5 minutes. Lets gluten develop before salt slows it down.',
      'Add salt, olive oil, and remaining flour. Knead 15–20 min by hand. Dough will be very hydrated and sticky.',
    ],
  ),
  StepSpec(
    id: 'bulk',
    title: 'Bulk ferment',
    timing: FlexibleDuration(
      minMinutes: _minBulkMinutes,
      maxMinutes: _maxBulkMinutes,
    ),
    instructions: [
      'Cover, rest at room temp. Do stretch & folds every 30 min during the first 1.5 hours.',
    ],
  ),
  StepSpec(
    id: 'proof',
    title: 'Pan & proof',
    timing: FixedDuration(150),
    floorMinutes: _minProofMinutes,
    instructions: [
      'Generously oil the baking tray.',
      'Tip dough into tray and stretch toward edges. Cover, rest 30–60 min.',
      'Finish stretching if needed. Cover and let rise until airy and puffy.',
    ],
  ),
  StepSpec(
    id: 'bake',
    title: 'Top & bake',
    timing: FixedDuration(5),
    instructions: [
      'Top as desired.',
      'Bake at 250–300 °C until golden and crisp on the bottom.',
    ],
  ),
];

const List<StepSpec> _romanCold = [
  StepSpec(
    id: 'mix',
    title: 'Mix the dough',
    timing: FixedDuration(30),
    instructions: [
      'Dissolve yeast in the water.',
      'Add about half the flour, mix until a rough paste forms.',
      'Rest 5 minutes. Lets gluten develop before salt slows it down.',
      'Add salt, olive oil, and remaining flour. Knead 15–20 min by hand. Dough will be very hydrated and sticky.',
    ],
  ),
  StepSpec(
    id: 'folds',
    title: 'Bulk ferment & fridge',
    timing: FixedDuration(30),
    instructions: [
      'Cover, rest at room temp for 20–30 min.',
      'Transfer to an oiled container and refrigerate at 4 °C.',
    ],
  ),
  StepSpec(
    id: 'fridge',
    title: 'Cold ferment',
    timing: FlexibleDuration(minMinutes: _minColdFermentMinutes),
    instructions: [
      'Leave undisturbed at 4 °C. This is where the flavour develops.',
      'The dough will rise slowly and should look domed and bubbly by the end.',
    ],
  ),
  StepSpec(
    id: 'pan',
    title: 'Remove & pan',
    timing: FixedDuration(120),
    floorMinutes: _minProofMinutes,
    instructions: [
      'Remove dough from fridge, let warm at room temp for 1 hour.',
      'Generously oil the baking tray.',
      'Tip dough into tray and stretch toward edges. Cover, rest 30–60 min.',
      'Finish stretching if needed.',
    ],
  ),
  StepSpec(
    id: 'proof',
    title: 'Final proof',
    timing: FixedDuration(115),
    floorMinutes: _minProofMinutes,
    instructions: [
      'Cover and let rest at room temp for 2–3 hours, until airy and puffy.',
    ],
  ),
  StepSpec(
    id: 'bake',
    title: 'Top & bake',
    timing: FixedDuration(5),
    instructions: [
      'Top as desired.',
      'Bake at 250–300 °C until golden and crisp on the bottom.',
    ],
  ),
];
