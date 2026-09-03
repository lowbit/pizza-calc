/// The single source of colour, type and shape for Pizzazz.
///
/// Nothing outside this file should contain a raw `Color(0x…)` or a bare
/// `fontSize:`. If you find yourself reaching for one, the token is missing.
/// Add it here instead.
///
/// The scheme is **hand-authored**, not generated. See [pizzazzDark] for why.
/// Dark only: the app is used in a kitchen, often at night, and a second scheme
/// doubles the surface area for colour bugs.

library;

import 'package:flutter/material.dart';

import 'app_typography.dart';

/// "Ink & copper", a neutral ink ground under copper, verdigris and chili.
///
/// **Why this is written out by hand rather than seeded.** `ColorScheme.fromSeed`
/// defaults to `DynamicSchemeVariant.tonalSpot`, which deliberately drops the
/// seed's chroma and pairs the result with near-neutral grey surfaces. It is a
/// good algorithm, but every app that uses it converges on the same output,
/// and that convergence is what makes a seeded app look generated. Moving the
/// seed does not escape it: the algorithm is enforcing harmony, so a different
/// hue buys a differently-hued version of the same look.
///
/// The thing seeding was buying us was guaranteed contrast between each colour
/// and its `on-` pair. That guarantee is replaced by `test/app_theme_test.dart`,
/// which measures every pair and fails below 4.5:1. If you change a value here,
/// that test is the check, don't eyeball it.
///
/// The ground is a true neutral, near-black and slightly cool. Nothing competes
/// with the accents, which is what lets a single copper carry the whole screen.
///
/// Role meanings, which the components depend on:
/// - `primary` (copper), the thing you are doing now, and every number you
///   will weigh.
/// - `secondary` (verdigris), a *positive state*: a completed step, a finished
///   bake, being comfortably ahead. It is copper's own patina, which is a
///   better reason than "green means done", and it is 138° from copper on the
///   wheel, the widest gap in the palette, because this is the distinction
///   that has to survive a glance across a kitchen. Never decoration.
/// - `tertiary` (amber), warnings. M3 has no warning role; see [IssueColors].
/// - `error` (chili): the one place a red survives, and deliberately pink
///   rather than orange so it cannot be mistaken for `primary`.
const ColorScheme pizzazzDark = ColorScheme(
  brightness: Brightness.dark,

  // Copper.
  primary: Color(0xFFE0915C),
  onPrimary: Color(0xFF3D1E05),
  primaryContainer: Color(0xFF6B3E18),
  onPrimaryContainer: Color(0xFFFFDCC4),

  // Verdigris, copper's patina. Reserved for positive state.
  secondary: Color(0xFF7FD1B9),
  onSecondary: Color(0xFF00382C),
  secondaryContainer: Color(0xFF1F5044),
  onSecondaryContainer: Color(0xFFB8EFE0),

  // Amber. Warnings only.
  tertiary: Color(0xFFF0D257),
  onTertiary: Color(0xFF2E2500),
  tertiaryContainer: Color(0xFF4F4213),
  onTertiaryContainer: Color(0xFFFFE9B0),

  // Chili. Pink-leaning on purpose: an orange-red would sit on top of copper.
  error: Color(0xFFFF6F8E),
  onError: Color(0xFF4A0614),
  errorContainer: Color(0xFF8A1F35),
  onErrorContainer: Color(0xFFFFD9E0),

  // The ground: a true neutral, near-black, faintly cool. The ladder between
  // these is deliberately tight (surface → container is 1.07:1); cards are
  // separated by the hairline outline below, not by tone.
  surface: Color(0xFF0B0B0D),
  onSurface: Color(0xFFF5F5F7),
  onSurfaceVariant: Color(0xFFA0A0AA),
  surfaceDim: Color(0xFF060608),
  surfaceBright: Color(0xFF2E2E34),
  surfaceContainerLowest: Color(0xFF060608),
  surfaceContainerLow: Color(0xFF0B0B0D),
  surfaceContainer: Color(0xFF131316),
  surfaceContainerHigh: Color(0xFF1B1B1F),
  surfaceContainerHighest: Color(0xFF26262B),

  outline: Color(0xFF55555F),
  outlineVariant: Color(0xFF2A2A30), // the card hairline

  inverseSurface: Color(0xFFF5F5F7),
  onInverseSurface: Color(0xFF0B0B0D),
  inversePrimary: Color(0xFF8A5426),
  surfaceTint: Color(0xFFE0915C),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

abstract final class AppRadius {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const extraLarge = 28.0;
}

/// Spacing scale, on a 4pt grid.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

ThemeData buildAppTheme() {
  const scheme = pizzazzDark;

  final base = ThemeData(colorScheme: scheme, brightness: scheme.brightness);
  final textTheme = buildTextTheme(base.textTheme);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,

    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      // No surface tint, and no scrolled-under elevation. M3 tints the bar
      // with `surfaceTint` once content scrolls beneath it, and our tint is
      // copper, so the bar picked up a brown cast while the
      // rest of the page stayed blue-green. It read as a rendering fault
      // rather than as depth.
      surfaceTintColor: scheme.surface,
      scrolledUnderElevation: 0,
      centerTitle: true,
      // headlineSmall rather than titleLarge: the app bar is a heading, and
      // titleLarge is deliberately on the plain face for numeric readouts.
      titleTextStyle: textTheme.headlineSmall,
    ),

    cardTheme: CardThemeData(
      // Cards carry no shadow here: on a dark scheme, elevation reads through
      // surface tint, and drop shadows just muddy the contrast. What separates
      // a card from the ground is the hairline. The tonal ladder alone is too
      // tight to see, which is the price of a ground this dark.
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),

    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      titleTextStyle: textTheme.bodyLarge,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        // Selection is a *choice*, not a positive state, so it takes the
        // primary container rather than verdigris, which means "done" here.
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        // Unselected segments default to `primary`, which made the option you
        // had *not* chosen glow copper, brighter than the one you had.
        foregroundColor: scheme.onSurfaceVariant,
        // No `shape:` override. M3 segments are stadium-ended, and forcing them
        // to an 8pt radius is what made this control read as an iOS segmented
        // control rather than a Material one.
      ),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.primary,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.extraLarge),
      ),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.extraLarge),
        ),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.surfaceContainerHighest,
      linearMinHeight: 4,
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
  );
}

/// Severity colours for the bake warnings.
///
/// M3 has no "warning" role, so the mapping is a deliberate choice rather than
/// something the scheme hands us: error is the real error role, warning borrows
/// amber/tertiary, and info borrows verdigris/secondary, which is consistent with
/// verdigris meaning "a positive state", since the only info-level issue the app
/// raises is "you're comfortably ahead".
extension IssueColors on ColorScheme {
  Color get warning => tertiary;
  Color get onWarning => onTertiary;
  Color get warningContainer => tertiaryContainer;
  Color get onWarningContainer => onTertiaryContainer;

  Color get info => secondary;
  Color get infoContainer => secondaryContainer;
  Color get onInfoContainer => onSecondaryContainer;
}
