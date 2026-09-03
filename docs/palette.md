# The palette: "Ink & copper"

> **Status: implemented 2026-09-02.** Replaces the seeded scheme from the
> Material migration, and the "Napoli night" scheme that briefly replaced it.
> Kept as the record of why the colours are written out by hand, so the next
> session doesn't helpfully "simplify" it back to `ColorScheme.fromSeed` and
> undo the whole point.

## Why it isn't seeded

The Material migration generated the scheme with
`ColorScheme.fromSeed(seedColor: 0xFFB5401F)`. That was the right call at the
time: it made the migration cheap and it guaranteed contrast. It also made the
app look like every other Material 3 app, and that was the complaint that
started this change.

The cause is specific, not vague. `fromSeed` defaults to
`DynamicSchemeVariant.tonalSpot`, which deliberately **drops the seed's chroma**
and pairs the result with near-neutral grey surfaces. A deep tomato seed comes
out as a washed peach on grey. Every app that seeds converges on that same
family of output, which is why seeded apps read as generated.

Crucially, **moving the seed does not escape it.** The algorithm is enforcing
harmony; a different hue gets you a differently-hued version of the same look.

So the roles are set directly, in `lib/styles/app_theme.dart`.

## How this one was chosen

Six candidates were built as real APKs and screenshotted on the emulator running
the actual app, not swatches, not mockups. Judging a palette from hex codes
does not work, and judging it from a rendered mock is only slightly better.

The six were: *Napoli night* (cool tile blue-green + tomato), *Charred crust*
(olive-black + muted ember), *Forno* (espresso brown + bright ember), *Copper &
slate* (slate + copper), *Ink & chili* (neutral near-black + chili pink), and
*Semolina* (a light theme, warm paper + deep tomato).

The pick was a **hybrid**: Ink & chili's ground with Copper & slate's accent.
That combination wasn't one of the six, which is the argument for showing real
screens rather than asking someone to choose from a list. The answer was "that
background, that accent", and neither candidate alone was it.

## The scheme

A true-neutral ink ground, near-black and faintly cool, under copper.

| Role | Value | Notes |
|---|---|---|
| `surface` | `#0B0B0D` | neutral near-black, nothing competes with the accent |
| `surfaceContainerLowest` / `Dim` | `#060608` | |
| `surfaceContainerLow` | `#0B0B0D` | same as surface by design |
| `surfaceContainer` | `#131316` | |
| `surfaceContainerHigh` | `#1B1B1F` | |
| `surfaceContainerHighest` | `#26262B` | carries the numeric readouts |
| `onSurface` | `#F5F5F7` | |
| `onSurfaceVariant` | `#A0A0AA` | |
| `outline` | `#55555F` | |
| `outlineVariant` | `#2A2A30` | the card hairline |
| `primary` | `#E0915C` | copper |
| `onPrimary` | `#3D1E05` | |
| `primaryContainer` / `on` | `#6B3E18` / `#FFDCC4` | |
| `secondary` | `#7FD1B9` | verdigris |
| `onSecondary` | `#00382C` | |
| `secondaryContainer` / `on` | `#1F5044` / `#B8EFE0` | |
| `tertiary` | `#F0D257` | amber |
| `onTertiary` | `#2E2500` | |
| `tertiaryContainer` / `on` | `#4F4213` / `#FFE9B0` | |
| `error` | `#FF6F8E` | chili |
| `errorContainer` / `on` | `#8A1F35` / `#FFD9E0` | |

## Four things that are load-bearing

**Verdigris is what copper turns into.** `secondary` means a *positive state*:
a completed step, a finished bake, "All done", and the one info-level banner
("you're comfortably ahead"). Picking copper's own patina for it is a better
reason than "green means done", and it puts the two colours 138° apart on the
wheel: the widest gap in the palette, because done-vs-now is the distinction
that has to survive a glance across a kitchen. It is deliberately **not** the
selected-segment colour (selection is a choice, not an achievement) and **not**
the stepper-button fill: `IconButton.filledTonal` defaults to
`secondaryContainer`, so `PickerInput` overrides it. The moment it becomes
decoration it stops being a signal.

**`error` is pink on purpose.** The natural error colour is an orange-red, which
on this palette would sit directly on top of copper. Pushing it toward chili
(`#FF6F8E`, 347°) buys 37° of separation from copper's 24°. It is also the one
surviving trace of the *Ink & chili* candidate.

**Amber and copper are only 24° apart, and that is not fixable.** No warning
colour worth having escapes being adjacent to copper while copper is the
primary. What separates them in use is **form, not hue**: warnings only ever
appear as a filled `tertiaryContainer` banner, and `primary` is never a filled
block of that size. `test/app_theme_test.dart` asserts the 20° floor with that
reasoning written next to it. If a future change starts painting large areas in
`primary`, revisit the palette rather than lowering the number.

**Cards are separated by a hairline, not by tone.** The dark ladder is tight on
purpose: `surface` → `surfaceContainer` is only **1.07:1**, visible in a swatch
and invisible on a phone in a kitchen. `AppCard` draws an `outlineVariant` edge,
which is what actually makes a card read as a card. Removing that border makes
the whole screen dissolve into one flat field.

## The contrast guarantee

Hand-authoring gives up the one real thing seeding provided: every colour and
its `on-` pair being legible together. That is replaced by
[`test/app_theme_test.dart`](../test/app_theme_test.dart), which measures WCAG
contrast for every pair and fails below 4.5:1, **plus** hue separation between
the accents. That second check exists because a brightness test was the wrong
tool here: verdigris and copper sit at almost identical luminance (1.40:1) and
a lightness assertion would have flagged them as indistinguishable while the eye
reads them as obviously different colours.

Don't eyeball any of this on a bright desktop monitor: the app gets used at
night, at arm's length, by someone holding a dough scraper.

Measured at the time of writing:

| Pair | Ratio |
|---|---|
| `onSurface` / `surface` | 18.06 |
| `onSurfaceVariant` / `surface` | 7.59 |
| `primary` / `surface` | 7.84 |
| `primary` / `surfaceContainerHighest` | 6.00 ← tightest |
| `onPrimary` / `primary` | 6.04 |
| `secondary` / `surface` | 10.98 |
| `tertiary` / `surface` | 13.17 |
| `error` / `surface` | 7.41 |
| `onXContainer` / `xContainer` (all four) | 6.98 – 8.27 |

| Accent pair | Hue separation |
|---|---|
| verdigris ↔ copper | 138° |
| chili ↔ copper | 37° |
| amber ↔ copper | 24° (see above) |

## What was rejected

- **A different seed.** Covered above: it moves the hue, not the look.
- **`DynamicSchemeVariant.content` or `fidelity`.** These do preserve the seed's
  chroma, and would have been a real improvement over `tonalSpot` for one line
  of change. They still generate harmonised neutrals from the seed, so the
  surfaces stay tinted greys, and a true-neutral ground under a single warm
  accent is exactly what this palette is.
- **A light theme** (the *Semolina* candidate was built and looked good). Still
  the wrong call: the app is used in a kitchen at night, and a second scheme
  doubles the surface area for colour bugs.
- **`material_3_expressive`.** Unchanged from the migration's reasoning. Worth
  noting that Google has since deprecated `SegmentedButton` in favour of a
  connected button group, and Flutter has stated it is **not** developing M3
  Expressive and is not accepting contributions for it, so that look would be
  entirely hand-rolled, for one control.
