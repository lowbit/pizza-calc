/// The app's haptic vocabulary.
///
/// Colour lives in one file and type in another; feedback deserves the same
/// treatment. Before this, four different `HapticFeedback` strengths were
/// spread across 22 call sites with no stated rule, which is how the hydration
/// slider, the most tactile control in the app, ended up with none at all
/// while opening a bottom sheet had two.
///
/// The rule is about *what the gesture did*, not how big the widget is:
///
/// | Call        | Meaning                                            |
/// |-------------|----------------------------------------------------|
/// | [tick]      | a value moved by one notch                         |
/// | [select]    | a discrete choice, or something opened/closed       |
/// | [commit]    | a decision that changes the bake                   |
/// | [finish]    | the bake is over, fires exactly once per bake      |
///
/// Reach for these rather than `HapticFeedback` directly; a grep for
/// `HapticFeedback.` outside this file should come back empty.
library;

import 'package:flutter/services.dart';

abstract final class Haptics {
  /// A value moved by one notch: −/+ steppers, a slider crossing a division,
  /// a picker wheel passing an item. The lightest thing we have, because it
  /// can fire twenty times in a drag.
  static void tick() => HapticFeedback.lightImpact();

  /// A discrete choice was made, or something opened or closed: segmented
  /// buttons, list rows, expanders, sheet chrome, undo.
  static void select() => HapticFeedback.selectionClick();

  /// A decision that changes the bake: starting one, marking a step done,
  /// discarding one. Deliberately heavier than [select], these are the taps
  /// you want to feel land through an oven glove.
  static void commit() => HapticFeedback.mediumImpact();

  /// The last step of a bake. The heaviest, and the rarest: it fires once per
  /// bake, which is what makes it read as an ending rather than another tap.
  static void finish() => HapticFeedback.heavyImpact();
}
