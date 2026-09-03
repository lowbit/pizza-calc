# Pizzazz (pizza-calc)

Flutter **Material 3**, dark-only pizza dough calculator. Single screen, no backend, no routing.
Android is the only target; the web build exists but **never confirm a change from the web build**:
verify on the emulator.

The app was originally built with Cupertino widgets. That was dropped in September 2026: there is
no `ios/` target, and Flutter's Cupertino widgets have not adopted iOS 26 Liquid Glass, so the iOS
styling bought nothing on the platform this actually ships on. Base Material 3 is first-class in
Flutter and looks native on Android, which is where it runs.
[`docs/material-migration-plan.md`](docs/material-migration-plan.md) records the reasoning and what
was rejected. Read it before proposing a different direction.

The user-facing name is **Pizzazz** everywhere (launcher, `MaterialApp.title`, task switcher).
`pizza_calc` is only the Dart package name.

## Layout

| Path | What |
|---|---|
| `lib/main.dart` | The screen: input state, the bake lifecycle, every picker/modal launcher |
| `lib/models/pizza_type.dart` | The four styles and their per-style defaults |
| `lib/models/bake_step.dart` | `StepSpec` + `StepTiming` (fixed vs flexible), `ScheduledStep` |
| `lib/models/bake_session.dart` | A bake in progress: frozen recipe, start, ticks. JSON-persisted |
| `lib/data/recipes.dart` | The steps for each style × mode, as data |
| `lib/services/bake_schedule.dart` | The scheduler and the schedule warnings |
| `lib/services/dough_calculator.dart` | Ingredient maths, yeast curve, dough warnings |
| `lib/services/bake_notifications.dart` | Scheduled reminders + phone-alarm hand-off |
| `lib/components/steps_checklist.dart` | The checklist: compact schedule while planning, focus-on-current once started |
| `lib/components/dough_settings_section.dart` | The editable recipe form (planning only) |
| `lib/components/bake_summary_card.dart` | Two states: the locked summary while baking, "Bake complete" after |
| `lib/components/bake_time_card.dart` | The hero bake-time readout, used by the form and the summary card |
| `lib/components/ingredient_display.dart` | Ingredients card. Rows driven by which keys exist in the map |
| `lib/components/bake_issue_banner.dart` | Warning/error banners with a one-tap fix |
| `lib/components/poolish_calculator.dart` | The poolish bottom sheet |
| `lib/styles/app_theme.dart` | **The only place colours, radii and spacing are defined** |
| `lib/styles/app_typography.dart` | The display face and which text roles get it |
| `lib/widgets/app_scaffolding.dart` | `AppCard`, `SectionHeader`, `InstructionList`, `PickerSheet`, `ValueRow` |
| `lib/widgets/value_picker.dart` | The scroll-wheel picker |
| `lib/widgets/time_wheel_picker.dart` | The hour/minute wheel. Replaced `showTimePicker` |
| `lib/widgets/` | plus `PickerInput`, `EnhancedSlider`, `SegmentedControlSection` |
| `lib/utils/time_format.dart` | Clock/duration formatting |
| `lib/utils/haptics.dart` | **The only place `HapticFeedback` is called.** The four-level vocabulary |

## How a bake is scheduled

This is the heart of the app, and the thing to understand before changing
anything about steps or times.

A recipe is a list of `StepSpec`s. Each is either **fixed** (mixing takes 25
minutes) or **flexible**, and exactly one step per recipe is flexible: the bulk
ferment for a same-day dough, the fridge stretch for a cold ferment. The
flexible step absorbs whatever time is left before the bake, which is why one
scheduler covers both modes. `bake_schedule_test.dart` asserts the one-flexible
-step invariant across every style; keep it true.

A `BakeSession` is a bake actually under way: the frozen recipe, the frozen
ingredient list, `startedAt`, and a map of step id to the moment it was ticked.
It is persisted as JSON under `activeBakeSession`. While a session exists the
inputs are locked and the editable settings are replaced by a read-only summary:
what is already mixed cannot be re-specified, and nothing may silently shift a
timeline you are following. The bake *time* stays editable and re-plans only the
steps still ahead.

Ticking a step stamps the real time, and everything after it re-plans from that
moment: finish early and the ferment gets the time back; finish late and it
gives time up. Once the flexible step is done there is nothing left to absorb
drift, so lateness becomes a plain warning ("you'll eat later") rather than an
error. An error means genuinely impossible: the ferment is already at zero and
the bake still overruns. Only that state disables Start now.

## Theme and tokens

**Everything visual comes from `lib/styles/`.** There should be zero raw `Color(0x…)` outside
`app_theme.dart` and zero bare `fontSize:` outside `app_typography.dart`. Both are one grep away
and were zero at the time of writing. If you need a value that isn't there, add a token rather than
a literal. The app previously had 16 colour literals across 62 usages and 10 font sizes across 54,
which is how it got there.

**The palette is hand-authored, not seeded.** `pizzazzDark` in `app_theme.dart` is a
`const ColorScheme` written out role by role. It is "Ink & copper": a true-neutral near-black
ground (`#0B0B0D`) under a single copper accent. It used to be `ColorScheme.fromSeed`, which
defaults to the `tonalSpot` variant. That variant drops the seed's chroma and pairs it with neutral
grey, which is why every seeded M3 app looks the same, and moving the seed does not escape it.
[`docs/palette.md`](docs/palette.md) has the reasoning, how it was picked (six candidates built as
real APKs and screenshotted), and the rejected alternatives. Read it before proposing a return to
`fromSeed`. Dark only.

Seeding's one real benefit was guaranteed contrast between each colour and its `on-` pair.
`test/app_theme_test.dart` replaces it: every pair is measured and fails below 4.5:1, plus hue
separation between the accents. **That test is the check when retuning.** Don't eyeball it. The
tightest text pair is `primary` on `surfaceContainerHighest` at 6.00:1, which is where `PickerInput`
paints grams and hydration.

Four role meanings the components depend on:

- **`primary` (copper)** is what you are doing now, and every number you will weigh.
- **`secondary` (verdigris)** is a positive state: a completed step, a finished bake, "All done",
  the one info banner. It is copper's own patina, and 138° from it on the wheel, which is the widest
  gap in the palette because done-vs-now has to survive a glance across a kitchen. Never
  decoration. It is deliberately **not** the selected-segment colour (selection is a choice, not an
  achievement) and **not** the stepper-button fill (`IconButton.filledTonal` defaults to
  `secondaryContainer`, so `PickerInput` overrides it).
- **`tertiary` (amber)** is warnings only. It sits 24° from copper, which is not fixable while
  copper is the primary. What separates them is form, not hue: warnings are always a filled
  container banner and `primary` never is. Don't lower the test's 20° floor; revisit the palette.
- **`error` (chili)** is pink on purpose. The natural orange-red would sit on top of copper.

Two things that look like styling and are not:

- **Cards are separated by a hairline, not by tone.** `surface` → `surfaceContainer` is only
  1.07:1, which is invisible on a phone in a kitchen. `AppCard` draws an `outlineVariant` edge, and
  without it the screen dissolves into one flat field.
- **The `AppBar` has `surfaceTintColor: surface` and `scrolledUnderElevation: 0`.** M3 tints the
  bar with `surfaceTint` when content scrolls under it. Our tint is copper, so the bar picked up a
  brown cast while the page stayed neutral, and it read as a rendering fault.

**M3 has no "warning" colour role.** The three banner severities map through the `IssueColors`
extension in `app_theme.dart`: error → `error`, warning → `tertiary`, info → `secondary`. Info uses
verdigris because the only info-level issue is "you're ahead", which is a positive state. Change
that mapping there, not at the call site.

**Fraunces is bundled, not fetched.** `google_fonts` downloads at runtime and *silently* falls back
to the platform font when offline. That is exactly how this app gets used: in a kitchen, on a phone
that may have no signal. The package was removed and the TTF lives in `assets/fonts/`. It is a
variable font, so weight is driven by `fontVariations`, not `fontWeight` alone, or Flutter
synthesises a fake bold.

The same figures problem is why `numericDisplay` (in `app_typography.dart`) is built *up* from
`titleLarge` rather than *down* from `displaySmall`. The bake-time card wants display-scale text,
and at 44pt a descending 9 in "19:00" reads as a bug rather than a typographic choice.

**Only headline and display roles get the display face.** `titleLarge` and below stay on the
platform default deliberately: that role carries the numeric readouts, and Fraunces has old-style
figures, so a "4" drops below the baseline and reads as a mistake rather than a value.

## The checklist, and why it looks like that

Every step is a dim one-line row **except the one you're on**, which expands into
a card with its instructions and a full-width action button. That gives
focus-mode clarity while keeping the whole timeline visible as a compact spine: no
mode toggle to discover, and the schedule is still there when you want it.

The split maps onto the two modes the app already has, which is the point: the
full schedule matters most *before* you start (when do I mix, when do I need to
be around) and least while baking (what's next). So the planning view is a
compact list of every step, and it doubles as the preview of what you're
committing to.

**Finished steps fold into one row.** Once a step is ticked it joins a single
`3 steps done · 12:35 – 16:05` summary at the top of the list; tapping expands it back
into the real rows, unchanged. Without this, by step five the card you actually need has
been pushed off the top of a phone screen. The group is keyed on the done count, so it
re-collapses itself whenever a step is ticked or undone, so marking something done tidies
the last one away without a second gesture.

Three decisions worth not undoing:

- **Completing is only possible via the button on the current step.** Making the
  whole card tappable was considered and rejected: it overloads one gesture with
  two meanings (expand vs. complete), and a stray tap stamps a real timestamp
  that shifts everything after it. Progress is strictly sequential, which is how
  dough works anyway.
- **Undo sits behind a tap on the finished row**, not on the row itself, so the
  list cannot be un-ticked by brushing past it. It is two taps now, because the row
  lives inside the done group. Finished rows keep the real time and the drift, and those
  recorded times are half the point of ticking.
- **Ticking a ferment far too early asks first, and never blocks.** A step whose
  `StepSpec.floorMinutes` is non-null shows a confirm when it has had less than that.
  Blocking was considered and rejected: the recipe's own wording for a proof is "until puffy,
  soft, and jiggly when you shake the tray", so the clock is the estimate and the baker is the
  judge. A warm kitchen really does halve a proof, and the dough may have been mixed before the
  app was opened. The confirm also catches the mis-tap, which is the expensive case.
- **Undo cascades.** Reopening a step clears every step after it
  (`BakeSession.uncompletingFrom`). This is correctness, not convenience: removing only
  the named step left the later timestamps in storage, where they rendered as upcoming
  and then snapped back to done carrying their *old* times the moment the earlier step
  was re-ticked. You cannot un-ferment dough.

**Finishing has its own state.** When `schedule.isComplete`, `BakeSummaryCard` swaps to a
verdigris-bordered "Bake complete" card reporting when it actually went in, the drift against
target, and the total start-to-oven time. It offers *Start a new bake*, which skips the
confirm dialog because there is nothing left to discard. No celebration copy: the app's
tone is sober everywhere else.

The button says **Start now**, not "Start bake": the final step is literally
"Shape & bake", so the latter reads as "put it in the oven now".

**Before this existed**, `_planStartTime` was reset in three separate places and
never persisted, so touching any setting, or just reopening the app, silently
restarted the timeline while appearing to work. That is the bug the session
model exists to kill; don't reintroduce a "recompute from now" path.

## Haptics

Feedback goes through `lib/utils/haptics.dart`, never `HapticFeedback` directly. A grep
for `HapticFeedback.` outside that file should come back empty. The rule is about what the
gesture *did*, not how big the widget is:

| Call | Maps to | For |
|---|---|---|
| `Haptics.tick()` | `lightImpact` | a value moved one notch: −/+ steppers, a slider division, a wheel item |
| `Haptics.select()` | `selectionClick` | a discrete choice, or something opened/closed |
| `Haptics.commit()` | `mediumImpact` | start a bake, mark a step done, discard |
| `Haptics.finish()` | `heavyImpact` | the last step. Fires once per bake, and nothing else uses it |

**Fire it at exactly one level.** The recurring bug here is double-buzzing: a button that
haptics *and* calls a handler that haptics again. Undo did it, poolish `_setAmount` did it
for every stepper tap, and the launchers for the bake-time and poolish sheets did it on top
of the row that opened them. Rule of thumb: the widget the finger touched owns the haptic,
and the handler stays silent. The exception is `_endBake`, which owns it because two
different buttons lead there.

## Domain rules worth knowing

- **A step's duration means one of two different things**, and `StepSpec.floorMinutes` is what
  tells them apart. For `mix`, `ball` and `bake` it estimates how long *you* take, so finishing in
  half the time is normal and must never warn. For `proof`, `pan`, the long `folds` and both
  ferments it is what the *dough* requires, so those carry a floor (proof 45 min, long folds
  20 min, fridge warm-up 30 min; the flexible steps reuse their own `minMinutes`, 60 min for bulk
  and 12 h for cold). Adding a step means deciding which kind it is. A floor must always be well
  under the planned duration, or it fires on an on-time finish; `bake_schedule_test.dart` asserts
  that across every style.
- **The flexible step is bounded at both ends.** `FlexibleDuration.minMinutes` is the point below
  which the dough will not work; `maxMinutes` is the point above which it is over-fermented rather
  than well developed. Only the **bulk ferment** carries a max (12 h), because only it can be
  overrun: a same-day target rolls to the next occurrence of the bake hour, so asking at 23:00 for
  a 19:00 bake handed the bulk 17 h in silence before this existed. The fridge steps deliberately
  have **no** max, their length is already capped by the 1-5 day picker, and a warning that cannot
  fire is just noise. The bound is set well past what anyone would choose (mixing at breakfast for
  an 8pm dinner is a 9 h bulk and perfectly normal) because a warning on an ordinary plan is a
  warning nobody reads. Its way out is `suggestColdFerment`, not a bake time: pushing the bake
  later makes it worse and pulling it earlier lands at an hour nobody eats at.
- **A suggested bake time must clear its threshold by more than nothing.** `_withMargin` rounds
  every `suggestedBakeTime` up to the next five-minute mark. Without it the "Move bake to ..." link
  could never resolve its own warning: the suggestions clear their threshold exactly, and an
  unstarted plan re-anchors to `now` on every rebuild, so the minute the suggestion bought was the
  minute the clock took back before a finger could reach it. Each tap moved the bake one minute
  later and re-displayed the identical warning, for ever. It also lands on times people actually
  eat at (02:50, not 02:47).
- 4 pizza types (`PizzaType` enum). Each carries its **own** defaults: hydration, doughballs,
  grams/ball, salt/sugar/oil %, default fermentation mode, cold-ferment days.
  A fifth, **Chicago deep dish, is planned but not built**:
  [`docs/chicago-plan.md`](docs/chicago-plan.md) is a ready-to-execute plan with the dough
  percentages, both recipes, the five files to touch and what the existing tests already cover.
  Read it before starting that work, and before changing `isPanStyle` or the hydration slider
  range, which it depends on.
- Percentages are baker's percentages **of flour**, so total always lands on
  `doughballs x gramsPerBall`. That sum is the invariant to check any calculation against.
- Yeast: `base * sqrt(referenceHours / effectiveHours)`. Same-day ref = 8 h, cold ferment
  ref = 24 h. Longer ferment ⇒ less yeast. The two `clamp` calls in `yeastPercent` are guards on
  arbitrary input, not behaviour, neither binds anywhere in the range the UI allows, and
  `dough_calculator_test.dart` pins that. Warnings about hitting those bounds were written and then
  removed for exactly that reason: they could never fire. If that test starts failing, the input
  ranges have moved and the question is worth reopening.
- Poolish (yeast type 2) is 100 % hydration, so it contributes `amount/2` flour and `amount/2`
  water, both **subtracted** from the remaining flour/water. There is no separate yeast row.
- Sugar/oil rows only render when that type's percentage is > 0 (NY and Sicilian/Roman).
- Both modes now get real clock times; cold ferment no longer uses `Day 1` / `Day N+1` labels.
  Its bake date is the mix date plus `coldFermentDays`.
- Same-day rolls the target to tomorrow once today's slot has passed, so "bake at 19:00" always
  means the *next* 19:00 rather than a time already gone.
- Pan styles (Sicilian/Detroit, Roman) have no balling step, `PizzaType.isPanStyle`. Recipes are
  selected by an exhaustive `switch` on the enum in `recipes.dart`, so a style can no longer
  silently fall through to placeholder steps the way the old string matching could.

## Preferences

Keys are namespaced per pizza type: `<typeName>_hydration`, `<typeName>_doughballs`, etc.
Plus three global keys: `lastPizzaType`, `isScreenAwake`, and `activeBakeSession` (the whole bake
in progress, as JSON). A corrupt or outdated `activeBakeSession` decodes to null rather than
throwing, a bad stored value drops you back to the calculator instead of crashing on launch.

`_saveSettings()` runs on every change. `_loadSavedSettings()` runs from `initState`
(via `_restoreSession()`) **and** from `_updatePizzaType`. Both call sites matter, a previous
version had no `initState` at all, so every setting was written but never read back on a cold
start, and the app silently reset to Neapolitan defaults on each launch while appearing to work
(switching type and back "restored" them, which makes the bug easy to miss).

The reset icon in the nav bar only renders when `_hasCustomSettings` is true, so
"icon present/absent" is a free assertion that saved state is or isn't being applied.

## Tests

```bash
flutter test                                   # 93 unit + widget tests, no device, ~3 s
flutter test integration_test -d emulator-5554 # 16 on-device main flows, ~45 s warm
```

Starting a bake asks for `POST_NOTIFICATIONS`, so the device run leaves a system dialog sitting
over the app and logs `permissionRequestInProgress`. That is expected and harmless: `_startBake`
sets and persists the session *before* awaiting the permission, so the UI is already correct, and
`BakeNotifications` swallows the error. Don't try to pre-grant it with `pm grant`: the test run
uninstalls the app at teardown, so the grant never survives to the next run.

| File | Covers |
|---|---|
| `test/bake_schedule_test.dart` | The scheduler. The most detailed suite here: planning, re-planning from real tick times, feasibility, cold ferment, recipe-shape invariants, early-finish floors |
| `test/dough_calculator_test.dart` | Ingredient totals, the yeast curve, dough warnings |
| `test/bake_session_test.dart` | JSON round trip, immutable updates, corrupt-data handling |
| `test/app_theme_test.dart` | WCAG contrast for every colour/`on-` pair. **The check when retuning the palette** |
| `test/widget_test.dart` | What the screen renders, and the start/tick lifecycle |
| `integration_test/app_test.dart` | The main flows on a real device, including persistence |

`integration_test/app_test.dart` is the repeatable version of the manual emulator pass, and the
thing to reach for first. It drives the real app against the **real** SharedPreferences plugin, so
it covers the persistence path that a plain widget test can't, and it finds widgets by type and
text rather than screen coordinates, so it survives layout changes. It covers two groups.
**Planning**: Neapolitan defaults, the checklist being on show, dough weight tracking the
doughball count, yeast falling for a longer ferment, per-type defaults, poolish replacing the yeast
row, settings and pizza type surviving a relaunch, and reset. **A bake in progress**: starting
locking the recipe, only the current step being expanded, marking done moving focus on, undo, undo
cascading to later steps, the completion card and its no-dialog reset, the session surviving a
relaunch, and starting over.

Two of those are real regression guards rather than decoration, and both have been checked to
genuinely fail when the code they cover is disabled: the planning relaunch case fails without
`_restoreSession()`, and the mid-bake relaunch case is the one that catches any return of a
"recompute from now" path.

Neither suite asserts exact gram values: yeast is derived from the time left until the bake hour,
so almost every figure moves with the wall clock. They assert the invariant instead: the rows
always total `doughballs x gramsPerBall`, plus the direction of change. Keep it that way, or the
tests will pass in the morning and fail at night.

Things that bite when adding tests here:

- **Bare digit finders are ambiguous.** Compact step rows are numbered, so `find.text('5')` matches
  both the doughball count and step 5. Read `PickerInput.value` by card title instead (there is a
  `pickerValue` helper in the integration suite).
- **Drive the checklist by its button text, not by digits.** Completing is `tap(find.text('Mark
  done'))`. There is exactly one at a time, since only the current step is actionable, and the
  last step says `Finish` instead. Undoing now takes three taps: open the group
  (`tap(find.text('1 step done'))`), open the row (its title), then `Undo`. A finished step's title
  is **not** findable while the group is collapsed. The current step is a card with no number on
  it, so digits only ever match collapsed rows.
- Widget tests need `SharedPreferences.setMockInitialValues({})` or `initState` throws
  `MissingPluginException`. The integration suite instead clears the *real* prefs in `setUp`, which
  is what makes its persistence assertions meaningful. Don't swap it to mocks.
- A "relaunch" is `pumpWidget(SizedBox.shrink())` then mounting the app again. Pumping the same
  widget type twice reuses the `State` and never re-runs `initState`.
- Most controls sit below the fold, in the 800x600 widget-test viewport and on the device alike.
  `ensureVisible` before every `tap`.
- Don't assert exact grams. Yeast tracks time-until-bake, so those figures change through the day.
  Assert the total and the direction of change.
- `BakeNotifications` swallows its own failures, so tests print `Notification init failed:` and
  carry on. That is the designed fallback, not a broken test.

## Driving the emulator by hand

**Don't do this for every change.** Obvious edits (copy, colours, padding, a renamed field, a
value that is plainly right) go straight in; `flutter analyze` and `flutter test` are enough.
Save the emulator pass for the end of a larger or fiddly feature. If something looks genuinely
uncertain (an unfamiliar plugin, a layout that might overflow, anything touching persistence or
the schedule math), offer a run and let Rijad decide, rather than either skipping it silently or
testing reflexively.

When a run *is* warranted, `flutter test integration_test -d emulator-5554` is the first choice:
it covers the main flows in ~30 s and needs no screenshot reading. Hand-driving with `adb` below
is for what that suite can't do: judging **visual** appearance, exploring an unfamiliar screen,
or diagnosing something the test can only tell you is broken.

```bash
flutter analyze                                             # clean; anything reported is yours
flutter build apk --debug --target-platform android-x64     # cold ~160 s, warm ~10 s
adb -s emulator-5554 install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n com.example.pizza_calc/.MainActivity
adb -s emulator-5554 exec-out screencap -p > shot.png       # then Read the png
```

### Gotchas that cost time: don't rediscover these

- **Foreground `sleep` is blocked by the harness.** Put the waits *inside* the adb command:
  `adb shell 'input tap 540 900; sleep 2; input swipe ...'`. This is the single most useful trick;
  without it every tap needs its own round trip.
- **Always run the build with `run_in_background: true`.** A cold Gradle build is ~160 s and
  writes nothing to its log for the first minute or two. That silence is normal, not a hang.
- **`flutter test integration_test` overwrites `build/app/outputs/flutter-apk/app-debug.apk`**
  with the *instrumented* build, whose Dart entrypoint is the test bundle, not `lib/main.dart`.
  Installing that by hand and starting `MainActivity` gives a **silent hang on the splash screen**:
  the process is alive, the engine starts, the Dart VM service logs a port, and there is no
  exception anywhere in logcat, because the entrypoint is sitting there waiting for a driver that
  will never connect. It looks exactly like a rendering bug in the app. Always `flutter build apk
  --debug` again after a device test run before installing by hand. **Check the timestamp, not the
  size**: the two are 85 MB and 84 MB, close enough to tell you nothing, but `ls -la` against the
  time the test run finished settles it immediately.
- **`python` is not installed on this machine** (only the Microsoft Store alias, which exits 49).
  Patch Dart with the Edit tool, not a python/sed script.
- **Line endings are LF throughout `lib/`.** (The old CRLF warning about `main.dart` is stale:
  that file was rewritten during the Material migration.)
- **`flutter analyze` exits 1 under PowerShell even when only `info` issues exist**, and the
  wrapper reports it as `NativeCommandError`. Read the actual issue list; don't treat exit 1 as
  a failure by itself.
- **Don't grep logcat by generic keywords** (`Exception|Error|FATAL`). An offline emulator floods
  those from Play services / Cronet / auth and buries anything real. Scope to the app:
  `adb shell "logcat --pid=$(adb shell pidof -s com.example.pizza_calc)"`.
- **`install -r` keeps app data; `adb uninstall` wipes it.** Pick deliberately: `-r` to test that
  settings survive an upgrade, uninstall first to test true first-run defaults.
- **To tell a save bug from a load bug, read the prefs directly** instead of guessing:
  `adb shell 'run-as com.example.pizza_calc cat /data/data/com.example.pizza_calc/shared_prefs/FlutterSharedPreferences.xml'`
  Doubles are stored base64-prefixed (`VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu60.0` = 60.0).
  This is what isolated the missing-`initState` bug in one step.

### Coordinates

Emulator is 1080x2424 @ density 420 ⇒ 411.4 x 923.4 logical px, **scale 2.625**.
Screenshots come back scaled to 891 px wide, so **multiply what you measure by 1.21** to get the
device pixels `input tap` wants. That conversion is the durable part.

**Do not trust hard-coded anchors here.** The Material rebuild moved everything: `AppBar` is
taller than the old nav bar and the whole layout shifted, so any coordinate list goes stale the
moment the UI changes, which is often. Take a screenshot, measure the target in it, multiply by
1.21, tap. The one anchor worth knowing is that the app bar sits around `y≈200` device px, because
it is the only thing that does not scroll.

### What a full pass should confirm

The integration suite covers all of this. Do it by hand only when judging appearance, or when
chasing something the suite has flagged. Compute the expected grams by hand *first*. The point is
catching a wrong number, not confirming the screen renders.

1. Fresh install ⇒ Neapolitan, 4 x 250 g, **62 %**, Same day, bake 19:00, Instant, no reset icon.
2. Ingredients sum to `doughballs x gramsPerBall`.
3. **The last step ends exactly on the bake time.** A sub-minute rounding bug once made the chain
   finish at 18:59 for a 19:00 target, and every unit test passed because they all used
   whole-minute clocks. `buildSchedule` floors its inputs to the minute to prevent it. This is
   the single easiest thing to break and the hardest to notice.
4. Switch fermentation mode ⇒ yeast drops for the longer ferment and the cold-ferment steps appear
   with real clock times, not day labels.
5. Switch pizza type ⇒ that type's own defaults load, sugar/oil rows appear for NY, reset clears.
6. Poolish ⇒ yeast row replaced by a poolish row, flour and water each drop by `amount/2`.
7. Start now ⇒ settings give way to the locked summary, progress reads `0 of N`, and step one is
   the only expanded card, with a live countdown and a **Mark done** button. Every other step is a
   one-line row.
8. Mark done ⇒ finished steps fold into one `N steps done` row (tap to expand: dim,
   struck-through, carrying the real time and the drift), focus moves to the next step, the
   flexible step absorbs the difference, and **the bake time does not move**. Undo a middle
   step from inside the group and everything after it clears too.
   Tick a ferment or a proof seconds in and it asks first; mixing or baking early never does.
9. Force-stop and relaunch mid-bake ⇒ same step, same progress, timeline not restarted.
10. Finish the last step ⇒ verdigris-bordered **Bake complete** card with the real bake time and
    the start-to-oven total; *Start a new bake* goes straight through with no dialog. Mid-bake,
    *Discard this bake* sits at the card's bottom edge and still confirms.
11. Start over ⇒ back to planning, and it stays gone after a relaunch.

## Alarms

Two mechanisms on purpose (`bake_notifications.dart`):

- **Scheduled notifications** fire automatically at each step boundary and are re-synced on every
  change, so finishing early genuinely cancels the old alarm rather than leaving it to go off at
  the original time.
- **Phone-alarm hand-off** (`SET_ALARM` intent) puts a real alarm in the system clock app. It rings
  through silent and Do Not Disturb, which a notification will not, so it is the right tool for a
  step you cannot afford to sleep through. Offered on steps of 30 minutes or more.

`POST_NOTIFICATIONS` is requested when the baker taps Start now, not at first launch, so the
prompt has context. Exact-alarm capability is **checked** with `canScheduleExactNotifications()`
and never *requested*: on Android 14+ requesting it throws the user out into system settings,
which is a hostile thing to do mid-tap. Without it we schedule inexact and the phone alarm covers
the difference. Every method swallows its own failures: a missing permission must never take the
app down mid-bake.

## Release builds

```bash
flutter build apk --release                    # fat APK, ~46 MB, installs anywhere
flutter build apk --release --split-per-abi    # arm64 ~17.5 MB, what a phone actually needs
```

Release is **minified and resource-shrunk** (`isMinifyEnabled`, `isShrinkResources`), and
`build.gradle.kts` has always pointed at `android/app/proguard-rules.pro`, which did not exist
until the first real release build. That file matters: `flutter_local_notifications` persists
scheduled notifications through Gson reflection so it can restore them after a reboot, and R8
strips that path. The failure mode is nasty: the app runs fine and step reminders just never
arrive, but only in release. Keep the `-keep class com.dexterous.**` and Gson `Signature`/annotation
rules.

Release is signed with the **debug** keystore (`signingConfig = signingConfigs.getByName("debug")`),
so sideloading needs "install from unknown sources". Fine for personal builds; it would need a real
keystore before any store upload.

Always smoke-test a release APK on the emulator before sending it anywhere. Debug passing proves
nothing about a minified build. Install it, start a bake, and check the app's own logcat is clean:

```bash
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
adb -s emulator-5554 shell "logcat --pid=$(adb -s emulator-5554 shell pidof -s com.example.pizza_calc)"
```

## Sending a build to Rijad

He reads Docker update notifications from `diun` in Telegram, via the bot `rijads_pc_notify_bot`.
The same bot can deliver an APK. Token and chat id live in the `diun` container's environment, so
read them from there rather than storing a copy:

```bash
ENV=$(docker inspect diun --format '{{range .Config.Env}}{{println .}}{{end}}')
TOKEN=$(printf '%s\n' "$ENV" | grep '^DIUN_NOTIF_TELEGRAM_TOKEN=' | cut -d= -f2- | tr -d '\r')
CHAT=$(printf '%s\n' "$ENV" | grep '^DIUN_NOTIF_TELEGRAM_CHATIDS=' | cut -d= -f2- | cut -d, -f1 | tr -d '\r')
curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendDocument" \
  -F "chat_id=${CHAT}" -F "document=@<abs-windows-path>.apk" -F "caption=<caption.txt"
```

Never echo the token. Two gotchas: Telegram caps bot uploads at 50 MB, so send the **arm64 split**
(17.5 MB) rather than the fat APK (46 MB, too close to the limit); and pass the caption from a file.
An inline `-F "caption=..."` with emoji or curly quotes fails with
`Bad Request: strings must be encoded in UTF-8`.

## Known issues

- `flutter analyze` is **clean**: no baseline noise to look past. If it reports anything, it is
  yours. (It used to carry 3 `withOpacity` deprecations; those files were rewritten.)
- `MaterialApp.title` never renders as a widget, so don't write `find.text(…)` against it. An old
  test did exactly that and could never have passed. The visible style name in the app bar is a
  separate widget.
- Gradle warns that the app and its plugins still apply KGP rather than built-in Kotlin. Harmless
  today; a future Flutter will break on it.
- The README still describes the app in its pre-Material form.
