# Chicago deep dish: implementation plan

> **Status: planned 2026-09-03, not implemented.** Written to be executed cold in a
> later session. Everything below was checked against the code as it stands at
> `5640299`; line numbers are from that commit.

Adds a fifth `PizzaType`. Chicago is the one remaining style that produces a
genuinely different object rather than a variation on a round, and it is the
most likely thing someone opens this app expecting and fails to find.

**It is a pan style**, so it inherits the no-balling path that Sicilian and
Roman already use. Most of the plumbing is free. The parts that are not are
listed under "Code changes" and are the whole of the work.

## What is deferred, and why

**Cornmeal is out of scope.** Classic deep dish carries 10-15 % cornmeal or
semolina for the yellow crumb and the sandy bite. `computeIngredients`
(`lib/services/dough_calculator.dart`) assumes a single `flour` key, and every
row on the ingredients card is derived from it. A second flour is a real change
to the calculator, the card, and the `sum(result) == totalDoughWeight` invariant
that `dough_calculator_test.dart` leans on for every style.

That is a separate decision about whether this app models multi-flour doughs at
all, and it would also open up semolina in the Sicilian. **Do not smuggle it in
here.** A deep dish without cornmeal is still recognisably a deep dish; it is
slightly paler and slightly less crumbly. Ship that, then decide about cornmeal
on its own merits.

## The dough

Baker's percentages of flour, as everywhere else in this app.

| | Chicago | Why |
|---|---|---|
| Hydration | **52 %** | Deep dish is a stiff, short dough, not a slack one. It is pressed into a pan, not stretched |
| Fat | **22 %** | The defining number. This is what makes it pastry-like rather than bready |
| Salt | 2.0 % | Slightly under the 2.5 % the others use; there is a lot of fat and cheese carrying flavour |
| Sugar | 1.0 % | Helps the long, comparatively cool bake colour the crust |
| Flour | Bread flour | Needs the strength to hold that much fat |
| Dough per pan | **600 g, 1 "ball"** | A 9-inch deep dish pan. Follows the Sicilian/Roman `doughballs: 1` pattern |
| Default mode | Same day | Deep dish gains far less from a long cold ferment than a lean dough does. The flavour is fat and sausage, not fermentation |

**22 % fat needs no calculator change.** `oilPercent` is already a baker's
percentage feeding the multiplier in `computeIngredients`, so the ingredient
list still lands exactly on `doughballs x gramsPerBall`. The existing test
`every style totals the dough weight requested`
(`dough_calculator_test.dart:57`) loops all types and both modes and will prove
this the moment the style exists. That invariant holds at 22 % exactly as it
does at 3 %.

**52 % hydration is below the current slider floor**, which is the one input
range this style genuinely breaks. See Code change 3.

## The recipes

Both modes, matching the existing pan-style shapes. Exactly one flexible step
each, which `bake_schedule_test.dart` asserts across every style.

### Same day

| id | title | timing | floor |
|---|---|---|---|
| `mix` | Mix the dough | `FixedDuration(20)` | none |
| `bulk` | Bulk ferment | **FLEXIBLE** `min: _minBulkMinutes, max: _maxBulkMinutes` | (own min) |
| `laminate` | Laminate & chill | `FixedDuration(60)` | `_minLaminationMinutes` |
| `proof` | Pan & proof | `FixedDuration(75)` | `_minProofMinutes` |
| `bake` | Top & bake | `FixedDuration(45)` | none |

### Cold ferment

| id | title | timing | floor |
|---|---|---|---|
| `mix` | Mix the dough | `FixedDuration(20)` | none |
| `folds` | Laminate & fridge | `FixedDuration(60)` | `_minLaminationMinutes` |
| `fridge` | Cold ferment | **FLEXIBLE** `min: _minColdFermentMinutes` | (own min) |
| `pan` | Remove & pan | `FixedDuration(90)` | `_minWarmUpMinutes` |
| `proof` | Final proof | `FixedDuration(75)` | `_minProofMinutes` |
| `bake` | Top & bake | `FixedDuration(45)` | none |

Reuse the existing ids (`mix`, `bulk`, `folds`, `fridge`, `pan`, `proof`,
`bake`). They are persistence keys and notification-id seeds; `laminate` is the
only new one. Ids must be unique within a recipe, which
`bake_schedule_test.dart:407` checks.

**Note the 45-minute bake**, against 5 minutes for the other pan styles. Deep
dish bakes long and comparatively cool. It is a `FixedDuration` and the
scheduler needs nothing new for it, but it does mean `minimumMinutes` for this
style is noticeably higher than the others, so "not enough time" fires earlier
in the day. That is correct, not a bug.

### Step copy

Follow the house voice: imperative, specific, no filler. The bake step must
carry oven temperature and topping order, the way every other recipe now does.

- `mix`: melted butter goes in with the flour, not creamed. Mix until it just
  comes together and looks shaggy and short. Do not develop it like a lean
  dough; you are after tenderness, not a windowpane.
- `laminate`: roll to a rectangle, spread softened butter edge to edge, roll it
  up like a jelly roll, coil the log into a spiral, chill. **This is the step
  that makes it flaky rather than merely thick.** The chill is dough time, not
  baker time, which is why it carries a floor.
- `proof` / `pan`: press up the sides of a well-greased steel pan, a good 4-5 cm
  up the wall. Deep dish lives or dies on the wall.
- `bake`: **cheese on the bottom** (sliced low-moisture mozzarella straight onto
  the crust), then sausage and toppings, then crushed tomato on top, then
  parmesan. Bake 200-220 °C for 35-45 minutes until the wall is deep gold.
  Rest 10 minutes before cutting or it slumps.

## Code changes

Five files. Nothing here is speculative; each was checked.

### 1. `lib/models/pizza_type.dart`

Add `chicago` to the enum and its `PizzaTypeConfig` case with the table above.

**Also move `isPanStyle` onto the config.** It is currently a hardcoded
`this == PizzaType.sicilian || this == PizzaType.roman` at the bottom of the
file. A fifth pan style is exactly the point where that should become a
`final bool isPanStyle` field on `PizzaTypeConfig`, defaulting to `false`, with
the getter delegating to `config.isPanStyle`. Leaving it as an OR chain means
the next style silently gets a balling step it should not have.

### 2. `lib/data/recipes.dart`

- Add `_minLaminationMinutes = 20` beside the other floor constants (~line 37),
  with a comment saying what kind of floor it is: the butter has to firm up, so
  it is dough time, not baker time.
- Add `_chicagoSameDay` and `_chicagoCold` in a banner-commented section, matching
  the existing layout.
- Add the `case PizzaType.chicago:` to `stepsFor` (~line 49). **The switch is
  exhaustive, so the compiler will refuse to build until this exists.** That is
  the safety net; let it guide you.
- `freezingNote` (~line 63) branches on `isPanStyle` and needs no change once
  change 1 is done. Sanity-check the wording it produces for Chicago: "After bulk
  ferment, before pan proofing" is right.

### 3. `lib/components/dough_settings_section.dart:127-129`

```dart
min: 55.0,      ->   min: 50.0,
max: 80.0,           max: 80.0,
divisions: 25,  ->   divisions: 30,
```

**Change `divisions` with `min`.** The slider is currently 25 divisions over a
25-point range, i.e. exactly 1 % per notch, and `EnhancedSlider` fires
`Haptics.tick()` per division. Widening the range without widening the divisions
silently makes every notch 1.2 %, which breaks the round numbers the readout
shows and the feel of the control.

This lowers the floor for *every* style, not just Chicago. That is acceptable:
55 % was never a dough-physics limit, just the bottom of what the existing four
needed. Nothing in the yeast curve reads hydration, so
`dough_calculator_test.dart` is unaffected.

### 4. `lib/components/ingredient_display.dart:80`

The fat row is hardcoded `'Olive Oil'`. Chicago's fat is **butter**, and a
recipe telling you to put 130 g of olive oil in a deep dish is simply wrong.

Add a `fatName` to `PizzaTypeConfig` (`'Olive Oil'` default, `'Butter'` for
Chicago), thread it through the same way `flourType` already is, and use it for
the row label. `flourType` is the existing pattern to copy: it is passed into
`IngredientDisplay` and interpolated as `'Flour ($flourType)'` at line 76.

### 5. `lib/main.dart:833`

Nothing to do. The style picker already iterates `PizzaType.values`, so Chicago
appears in the dropdown on its own. Listed here only so it is not hunted for.

## Tests

**Most coverage is free.** These already loop `PizzaType.values` and will cover
Chicago the moment the enum grows, with no edit:

| Test | File | What it will prove |
|---|---|---|
| every recipe has exactly one flexible step | `bake_schedule_test.dart:394` | The recipe shape is legal |
| step ids are unique within a recipe | `:407` | `laminate` does not collide |
| every recipe ends on a bake step and starts by mixing | `:417` | Bookends |
| pan styles skip balling, round styles do not | `:427` | **That change 1 was done properly** |
| a flexible step bounded above is bounded sanely | `:435` | The bulk max is sane |
| only the bulk ferment is bounded from above | `:455` | Same-day has a max, cold does not |
| minimum time is well under a day | `:474` | The 45-minute bake did not break feasibility |
| floors are well under planned durations | `:552` | `_minLaminationMinutes` vs the 60-minute step |
| every style totals the dough weight requested | `dough_calculator_test.dart:57` | **22 % fat still sums to `doughballs x gramsPerBall`** |
| the yeast bounds never bind | `:160` | Unchanged by the new style |

Add only what is genuinely new:

1. **A Chicago-specific total.** `1 x 600 g` with 22 % fat is the most
   arithmetically unusual dough in the app; assert it sums, and assert a `butter`
   row exists and an `Olive Oil` row does not.
2. **The lamination floor fires.** Tick `laminate` a minute in and expect the
   confirm, in the same shape as the existing early-finish tests.
3. **Integration: Chicago loads its own defaults.** Mirror `each pizza type
   loads its own defaults` (`integration_test/app_test.dart:182`): select
   Chicago, expect `600g`, `52%`, `Flour (Bread Flour)`, a `Butter` row, and
   `totalGrams == 1 * 600.0`.

## Verification

```bash
flutter analyze                                 # must stay clean
flutter test                                    # 93 now, plus whatever you add
flutter test integration_test -d emulator-5554  # 16 now, plus one
```

Then a hand pass on the emulator, because two things here are visual and the
suites cannot judge them:

1. Switch to Chicago and read the ingredients card. **Compute the numbers by
   hand first.** At 600 g total and 52/22/2/1, flour is about 340 g. If the card
   disagrees, the multiplier is wrong, not the card.
2. Drag the hydration slider to its new floor and confirm it reads `50%`, moves
   in whole percents, and ticks once per notch.
3. Start a Chicago bake and confirm the checklist shows no balling step, the
   lamination step expands with its instructions, and the last step lands exactly
   on the bake time.

## Rejected

- **Cornmeal in this change.** See the top. It is a multi-flour decision wearing
  a Chicago costume.
- **A separate "deep dish" vs "stuffed" split.** Stuffed pizza is a different
  build with a second dough layer over the filling. One style, done well.
- **Modelling butter as a distinct ingredient from oil.** Tempting, but the only
  thing that actually differs is the row label and the percentage, both of which
  a `fatName` field solves. A real `butter` key would mean the calculator
  carrying two fat lines for no gain.
- **Making the bake step flexible so a long bake absorbs slack.** The flexible
  step must stay the ferment. A bake that stretches to fill the afternoon is not
  a bake, and it would break the one-flexible-step invariant every recipe relies
  on.
