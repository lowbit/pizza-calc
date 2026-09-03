/// Contrast guards for the hand-authored colour scheme.
///
/// `ColorScheme.fromSeed` used to guarantee that every colour and its `on-`
/// pair were legible together. That guarantee was the main thing seeding
/// bought us, and writing the scheme by hand gives it up. This suite is what
/// replaces it: not a promise in a doc comment, but a measurement.
///
/// If you retune the palette in `app_theme.dart`, this is the check. Don't
/// eyeball it on a bright monitor and call it done, the app is used at night
/// in a kitchen, at arm's length, by someone holding a dough scraper.

library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizza_calc/styles/app_theme.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG contrast ratio, 1.0 (identical) to 21.0 (black on white).
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Position on the colour wheel, 0–360°.
double _hue(Color color) {
  final r = color.r, g = color.g, b = color.b;
  final max = math.max(r, math.max(g, b));
  final min = math.min(r, math.min(g, b));
  final delta = max - min;
  if (delta == 0) return 0;

  final double h;
  if (max == r) {
    h = (g - b) / delta;
  } else if (max == g) {
    h = 2 + (b - r) / delta;
  } else {
    h = 4 + (r - g) / delta;
  }
  final degrees = h * 60;
  return degrees < 0 ? degrees + 360 : degrees;
}

/// Shortest angle between two hues, 0–180°.
double hueSeparation(Color a, Color b) {
  final diff = (_hue(a) - _hue(b)).abs();
  return diff > 180 ? 360 - diff : diff;
}

void main() {
  const scheme = pizzazzDark;

  group('text pairs clear WCAG AA (4.5:1)', () {
    // Foreground, background, and what breaks if it slips.
    final pairs = <String, (Color, Color)>{
      'onSurface on surface': (scheme.onSurface, scheme.surface),
      'onSurfaceVariant on surface': (scheme.onSurfaceVariant, scheme.surface),
      'onSurfaceVariant on surfaceContainer': (
        scheme.onSurfaceVariant,
        scheme.surfaceContainer,
      ),
      // The numeric readouts, grams, hydration, the bake time, are primary
      // on a raised container. This is the tightest pair in the app and the
      // reason `primary` is a tone lighter than the brand red.
      'primary on surfaceContainerHighest': (
        scheme.primary,
        scheme.surfaceContainerHighest,
      ),
      'primary on surface': (scheme.primary, scheme.surface),
      'onPrimary on primary': (scheme.onPrimary, scheme.primary),
      'secondary on surface': (scheme.secondary, scheme.surface),
      'onSecondary on secondary': (scheme.onSecondary, scheme.secondary),
      'tertiary on surface': (scheme.tertiary, scheme.surface),
      'onTertiary on tertiary': (scheme.onTertiary, scheme.tertiary),
      'error on surface': (scheme.error, scheme.surface),
      'onError on error': (scheme.onError, scheme.error),
      'onPrimaryContainer on primaryContainer': (
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
      ),
      'onSecondaryContainer on secondaryContainer': (
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
      ),
      'onTertiaryContainer on tertiaryContainer': (
        scheme.onTertiaryContainer,
        scheme.tertiaryContainer,
      ),
      'onErrorContainer on errorContainer': (
        scheme.onErrorContainer,
        scheme.errorContainer,
      ),
      'onInverseSurface on inverseSurface': (
        scheme.onInverseSurface,
        scheme.inverseSurface,
      ),
    };

    pairs.forEach((name, pair) {
      test(name, () {
        expect(
          contrastRatio(pair.$1, pair.$2),
          greaterThanOrEqualTo(4.5),
          reason: '$name is below AA, retune it in app_theme.dart',
        );
      });
    });
  });

  test('the card hairline is visible against every surface it sits on', () {
    // Not a text pair, so AA does not apply, but an invisible outline means
    // cards vanish into the ground, which is what the hairline exists to stop.
    for (final surface in [
      scheme.surface,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
    ]) {
      expect(contrastRatio(scheme.outlineVariant, surface), greaterThan(1.15));
    }
  });

  group('the accents stay tellable apart', () {
    // Separation here is carried by *hue*, not lightness, verdigris and copper
    // sit at almost the same luminance, and a brightness test would have called
    // that a failure while the eye reads them as obviously different colours.
    // So measure the thing that actually does the work.

    test('verdigris is far from copper, done vs. now', () {
      // The widest gap in the palette on purpose: this is the distinction that
      // has to survive a glance across a kitchen.
      expect(hueSeparation(scheme.secondary, scheme.primary), greaterThan(90));
    });

    test('chili is far enough from copper, error vs. now', () {
      // Why `error` is pink rather than the orange-red it would naturally be:
      // an orange error would sit right on top of a copper primary.
      expect(hueSeparation(scheme.error, scheme.primary), greaterThan(30));
    });

    test('amber clears copper by the little it can', () {
      // The honest one. Amber is *inherently* adjacent to copper, ~24°, and
      // no warning colour worth having escapes that while primary is copper.
      // What keeps them apart in use is form, not hue: warnings only ever
      // appear as a filled `tertiaryContainer` banner, and `primary` is never
      // a filled block of that size. If a future change starts painting large
      // areas in `primary`, revisit this rather than lowering the number.
      expect(hueSeparation(scheme.tertiary, scheme.primary), greaterThan(20));
    });
  });

  testWidgets('the theme is built from the hand-authored scheme', (
    tester,
  ) async {
    final theme = buildAppTheme();

    expect(theme.colorScheme.primary, pizzazzDark.primary);
    expect(theme.colorScheme.surface, pizzazzDark.surface);
    expect(theme.brightness, pizzazzDark.brightness);

    // Segments must stay stadium-shaped. Overriding this to a small radius is
    // what made the control read as an iOS segmented control.
    expect(theme.segmentedButtonTheme.style?.shape?.resolve({}), isNull);
  });
}
