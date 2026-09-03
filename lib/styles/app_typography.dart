/// Typography for Pizzazz.
///
/// Display faces carry the personality; body text does not. Instructions get
/// read at arm's length with floury hands, so everything dense stays on the
/// platform default (Roboto on Android), which is more legible at that distance
/// than any display face.
///
/// Fraunces is **bundled**, not fetched. The `google_fonts` package downloads
/// at runtime and silently falls back to the platform font when the network is
/// unavailable, which is precisely how this app gets used: in a kitchen, on a
/// phone that may have no signal. Bundling also removes the first-launch flash
/// of the wrong typeface.
///
/// Swapping the display face is a two-step change: drop a TTF in
/// `assets/fonts/`, point [_displayFamily] at its declared family name.

library;

import 'package:flutter/material.dart';

/// The bundled display family, as declared in `pubspec.yaml`.
const String _displayFamily = 'Fraunces';

/// Fraunces is a variable font. Its weight axis has to be driven explicitly:
/// setting `fontWeight` alone would make Flutter synthesise a fake bold rather
/// than use the real one on the axis.
TextStyle _display(TextStyle? base, double weight) {
  return (base ?? const TextStyle()).copyWith(
    fontFamily: _displayFamily,
    fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
    fontVariations: [FontVariation('wght', weight)],
  );
}

/// Applies the display face to the headline and title roles, leaving body and
/// label roles on the platform default.
TextTheme buildTextTheme(TextTheme base) {
  return base.copyWith(
    displayLarge: _display(base.displayLarge, 600),
    displayMedium: _display(base.displayMedium, 600),
    displaySmall: _display(base.displaySmall, 600),
    headlineLarge: _display(base.headlineLarge, 600),
    headlineMedium: _display(base.headlineMedium, 600),
    headlineSmall: _display(base.headlineSmall, 600),
    // titleLarge and below stay on the default face. That role carries the
    // numeric readouts, doughball count, grams, hydration, and Fraunces has
    // old-style figures, so a "4" drops below the baseline and reads as a
    // mistake rather than a value. Character belongs on headings; numbers you
    // are about to weigh out belong in something plain.
  );
}

/// A large readout for a number you are meant to *read*, not admire.
///
/// The bake-time card wants display-scale text, but the display roles all carry
/// Fraunces, and its old-style figures put the 9 in "19:00" below the baseline,
/// which at 44pt stops looking like a typographic choice and starts looking
/// broken. So this is built up from `titleLarge`, which is deliberately still on
/// the platform face, rather than down from `displaySmall`.
///
/// The bare `fontSize` is fine here and nowhere else: this file is where sizes
/// are allowed to live.
extension NumericStyles on TextTheme {
  TextStyle get numericDisplay =>
      (titleLarge ?? const TextStyle()).copyWith(
        fontSize: 44,
        height: 1.05,
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
      );
}
