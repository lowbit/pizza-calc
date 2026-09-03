# Material 3 migration plan

> **Status: implemented 2026-09-02.** All phases done. Kept as the record of why
> Material was chosen and what was rejected, so the decision does not get
> relitigated from scratch. Two things landed differently from the plan and are
> noted inline below: the display font is **bundled** rather than fetched via
> `google_fonts`, and the header progress bar was dropped in favour of the
> per-step one.

Agreed 2026-09-02, implemented the same day. The app currently
uses Flutter's Cupertino widgets, which have not adopted iOS 26 Liquid Glass and
are not going to soon, and there is no `ios/` target anyway. It runs on Android.
So it moves to Material 3, matching the construction already used in `gymbro-fe`.

**This is a visual-system swap, not a redesign.** Layout, information hierarchy
and the checklist flow settled in the previous session all stay exactly as they
are. If a screen looks structurally different afterwards, something went wrong.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Framework | Stay Flutter. `MaterialApp` + `ThemeData(useMaterial3: true)` |
| Themes | **Dark only.** Seeds make adding light later cheap |
| Colour | Seeded palette from a warm tomato/crust tone |
| Display font | `google_fonts`, **Fraunces** proposed (see below); body stays platform default |
| Expressive | **No package.** Hand-rolled spring on the one interaction that earns it |
| Scope | Visual system + tech debt only. No feature changes |

### Why not `material_3_expressive`

It is genuinely healthy, 160/160 pub points, updated within the week, 45
widgets, and it runs on our exact toolchain (needs Flutter ≥3.44 / Dart ^3.12;
we are on 3.44.0 / 3.12.0). It was rejected on cost, not quality: a single
unverified maintainer, 38 likes, ~1.5k weekly downloads, six transitive
dependencies, for about one of its 45 widgets. Flutter's team has said M3E
work will land in the decoupled `material` package eventually, which would make
this a migration to unwind.

The one thing worth borrowing is spring motion on step completion. Flutter ships
`SpringDescription` natively, so we take the idea and skip the dependency.

### Font proposal

**Fraunces** for display, a variable "soft serif" with warmth and optical
sizing, distinct from gymbro's geometric Sora, and it suits a food app without
being twee. Body text stays the platform default (Roboto): instructions are read
at arm's length with floury hands, and Roboto is more legible at that distance
than any display face.

Alternate if a serif feels wrong: **Bricolage Grotesque**, characterful sans,
same warmth, more modern.

> **Changed during implementation.** `google_fonts` was added, then removed
> again: it fetches at runtime and *silently* falls back to the platform font
> when offline. The emulator has no network and proved it: the first build
> looked right but was not rendering Fraunces at all. The TTF is now bundled in
> `assets/fonts/` and the package is gone. This is a deliberate divergence from
> gymbro, which uses `google_fonts`; a kitchen app has to work without signal.
>
> Also learned: Fraunces has old-style figures, so the display face had to be
> pulled back off `titleLarge`: that role carries the numeric readouts, and a
> descending "4" reads as a mistake rather than a value.

### Colour proposal

Seed `#B5401F`, a deep tomato. On a dark scheme M3 turns that into warm
amber/peach primaries against near-black surfaces, appetising, and a clean
break from the current iOS blue. Alternate seed if it reads too red: `#C77B30`,
a crust amber.

**Note M3 has no "warning" colour role.** Our three-severity banner maps as:
error → `error`/`errorContainer`, warning → `tertiary`/`tertiaryContainer`,
info → `secondary`/`secondaryContainer`. Decide the tertiary tone deliberately
when tuning the seed, or warnings will come out an arbitrary colour.

---

## Phase 0: Theme foundations

Creates the token layer everything else depends on. Nothing visual ships here.

1. `pubspec.yaml`: add `google_fonts`, bump `environment.sdk` to `^3.12.0`.
2. New `lib/styles/app_theme.dart`: builds `ThemeData` from
   `ColorScheme.fromSeed(seedColor: …, brightness: Brightness.dark)`, plus
   component themes (`CardTheme`, `FilledButtonTheme`, `SegmentedButtonTheme`,
   `ListTileTheme`, `DialogTheme`, `SliderTheme`, `AppBarTheme`).
   Mirror the structure of `gymbro-fe/lib/styles/theme_config.dart` so the two
   apps read the same way.
3. New `lib/styles/app_typography.dart`: Fraunces on display/headline/title,
   platform default on body/label.
4. `main.dart`: `CupertinoApp` → `MaterialApp`, wire the theme.

**Exit check:** app still builds and runs; it will look wrong (Cupertino widgets
on a Material theme). That is expected mid-phase.

## Phase 1: Shared components

Kills the duplication before the swap, so it is done once instead of per call
site. All live in `lib/widgets/`.

| Component | Replaces | Count today |
|---|---|---|
| `AppCard` | Hand-rolled `Container` + `BoxDecoration` | 22 |
| `InstructionList` | Bullet-list rendering in `steps_checklist.dart` | 3 copies |
| `PickerSheet` | Cancel/Done modal chrome | 2 copies |
| `SectionHeader` | "Ingredients" / "Steps" / "Dough Settings" headings | 3 |
| `ValuePicker` | **Move** out of `poolish_calculator.dart` (line 312) into its own file | 1 |

`AppCard` should be a thin wrapper over M3 `Card` rather than a bespoke
container. The point is to stop hand-drawing surfaces, not to build a private
card system.

## Phase 2: Element-by-element swap

| # | Element | Now | Becomes |
|---|---|---|---|
| 1 | App shell | `CupertinoPageScaffold` | `Scaffold` |
| 2 | Header | `CupertinoNavigationBar` | `AppBar`; title becomes a `MenuAnchor`/button showing the style + chevron |
| 3 | Reset action | Nav `leading` icon | `AppBar` action, `IconButton` |
| 4 | Wakelock toggle | Nav `trailing` icon | `AppBar` action, `IconButton` with `isSelected` + `selectedIcon` (free toggle semantics) |
| 5 | Pizza type picker | `CupertinoActionSheet` | `showModalBottomSheet` + `ListTile`s, `Icons.check` on current |
| 6 | Section headings | Raw `Text` 22px | `SectionHeader` on `textTheme.titleLarge` |
| 7 | Doughballs / grams / days | `PickerInput` + custom `StepperButton` | `ListTile` + `IconButton.filledTonal` −/+; tap body opens `ValuePicker` |
| 8 | Hydration | `EnhancedSlider` (custom) | M3 `Slider` with `divisions` + `label`; keep the marker row beneath |
| 9 | Fermentation / Yeast type | `CupertinoSegmentedControl` (**iOS 12-era**) | `SegmentedButton` |
| 10 | Bake at | Custom row + `CupertinoDatePicker` | `ListTile` + `showTimePicker` (M3 dial, with keyboard entry free) |
| 11 | Poolish amount | Custom row | `ListTile` with trailing value + chevron |
| 12 | Poolish modal | `CupertinoModalPopup` | `showModalBottomSheet` with drag handle |
| 13 | Ingredients | Custom rows in a container | `AppCard` + `ListTile` rows (`title` / `trailing`) |
| 14 | Issue banners | Custom tinted container | `AppCard` on `errorContainer` / `tertiaryContainer` / `secondaryContainer` |
| 15 | Start now | `CupertinoButton` | `FilledButton` (full-width, large) |
| 16 | Steps progress | Text `"1 of 5"` | Keep, plus a thin `LinearProgressIndicator` under the header |
| 17 | Current step card | Custom bordered container | `Card` on `primaryContainer` with `Card.filled` |
| 18 | Compact step rows | Custom row | `ListTile(dense: true)`, leading `Icons.check` or step number |
| 19 | Mark done | `CupertinoButton` | `FilledButton` |
| 20 | Set phone alarm | Text + icon row | `TextButton.icon` |
| 21 | Freezing note | Custom expander | `ExpansionTile` |
| 22 | Dialogs (×4) | `CupertinoAlertDialog` | `AlertDialog` |
| 23 | Value pickers | `CupertinoPicker` in custom sheet | Keep `CupertinoPicker` wheel inside `PickerSheet`, **or** switch to a `ListWheelScrollView`, see open question |
| 24 | Icons (20 uses) | `CupertinoIcons` | Material `Icons` |
| 25 | Footer credit | Raw `Text` | `textTheme.bodySmall` on `onSurfaceVariant` |

### New in this phase

**Step progress indicator (#16).** A `LinearProgressIndicator` showing elapsed
time through the *current* step, driven by the existing 20-second ticker. The
app tracks timers but never shows progress visually; on a ten-hour bulk ferment
that is the single most useful thing on screen.

> **Changed during implementation.** Only the per-step bar was built. The
> planned second bar under the "Steps" header would have shown completion (1 of
> 5), which the text beside it already says. Two bars saying different things
> in the same header is noise; the one that carries new information stayed.

## Phase 3: Motion

One spring, on the interaction that matters: marking a step done.

- The finished card collapses into its compact row and the next step expands.
- `AnimatedSize` + `AnimatedSwitcher` driven by an `AnimationController`
  running `SpringDescription(mass: 1, stiffness: 180, damping: 22)`, tune on
  device; slight overshoot, no visible wobble.
- Everything else uses stock M3 transitions.

Respect `MediaQuery.disableAnimations` (accessibility) by falling back to an
instant swap.

## Phase 4: Tests and docs

Logic is untouched, `models/`, `services/`, `data/` have no widget imports, so
the 40 pure unit tests should pass without edits. Expect to change:

- `test/widget_test.dart` and `integration_test/app_test.dart`: icon finders
  (`CupertinoIcons.checkmark_alt` → `Icons.check`, `CupertinoIcons.refresh` →
  `Icons.refresh`). Text finders mostly survive, which is the payoff for having
  driven the suites by text rather than coordinates.
- `CLAUDE.md`: rewrite the "checklist, and why it looks like that" section for
  Material equivalents; update the emulator coordinate anchors (layout shifts);
  drop the iOS/Cupertino framing at the top.
- Re-run the full emulator pass, then send a new APK.

---

## Tech debt register

Cleared as a by-product of the phases above. Listed so nothing is quietly
dropped.

| # | Debt | Cleared by |
|---|---|---|
| 1 | 16 colour literals across 62 usages, no tokens | Phase 0, `ColorScheme` |
| 2 | 10 font sizes across 54 usages, no scale | Phase 0, `TextTheme` |
| 3 | 5 corner radii (2/8/10/12/14), no system | Phase 0, shape tokens |
| 4 | 22 hand-rolled `BoxDecoration` cards | Phase 1, `AppCard` |
| 5 | Instruction bullets written 3× | Phase 1, `InstructionList` |
| 6 | Cancel/Done modal chrome written 2× | Phase 1, `PickerSheet` |
| 7 | `ValuePicker` buried in `poolish_calculator.dart` | Phase 1, own file |
| 8 | `main.dart` at 1288 lines doing state + persistence + all view building | Phase 2, extract `DoughSettingsSection` and `BakeSummaryCard` into `lib/components/` |
| 9 | 3 `withOpacity` deprecation warnings | Phase 2, `withValues` |
| 10 | `StepperButton` hand-rolls press animation and haptics | Phase 2, `IconButton` gives state layers free |
| 11 | `EnhancedSlider` hand-rolls a slider | Phase 2, M3 `Slider` |
| 12 | `CupertinoSegmentedControl` is the iOS-12 control | Phase 2, `SegmentedButton` |
| 13 | No `fontFamily` set anywhere | Phase 0 |
| 14 | Tests coupled to Cupertino icons | Phase 4 |

Target: `main.dart` under ~600 lines, zero raw `Color(0x…)` in `lib/` outside
`app_theme.dart`, zero raw `fontSize:` outside `app_typography.dart`. Those are
checkable with grep and worth verifying at the end.

## Open questions

1. **Display font**, Fraunces, Bricolage Grotesque, or something you have in
   mind. One line either way.
2. **Value pickers (#23)**, `CupertinoPicker` is a *wheel*, which Material has
   no direct equivalent for. Keeping it inside a Material sheet is pragmatic and
   works well for 50 doughball values; replacing it with a plain scrollable list
   is more honestly Material but slower to use. Leaning keep-the-wheel.
3. **App name**, still three names (`Pizzazz` / `Pizza Calculator` /
   `pizza_calc`). Worth settling while we are touching the shell.

## Risks

- **Nav bar height changes.** `AppBar` is taller than `CupertinoNavigationBar`;
  the emulator tap coordinates in `CLAUDE.md` will all shift. Re-derive them
  rather than trusting the old ones.
- **`showTimePicker` returns `TimeOfDay?`, not `DateTime`.** The bake-time flow
  currently updates state continuously as the wheel spins; the Material picker
  is modal and returns once on confirm. Simpler, but `_onBakeTimeChanged` needs
  reworking rather than porting.
- **Seed colour is a judgement call.** Build it, look at it on the device, and
  expect to tune the seed once before it feels right.
