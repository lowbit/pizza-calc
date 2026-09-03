/// Pizza styles and their per-style defaults.
///
/// Percentages are baker's percentages, they are shares *of the flour weight*,
/// not of the total dough. That is what makes the finished ingredient list
/// always add up to doughballs x gramsPerBall.

library;

/// Complete set of defaults for one pizza style.
class PizzaTypeConfig {
  final String displayName;
  final String flourType;
  final double defaultHydration;
  final int defaultDoughballs;
  final double defaultGramsPerBall;
  final double saltPercent;
  final double sugarPercent;
  final double oilPercent;
  final int defaultFermentationMode; // 0 = same day, 1 = cold ferment
  final int defaultColdFermentDays;

  const PizzaTypeConfig({
    required this.displayName,
    required this.flourType,
    required this.defaultHydration,
    required this.defaultDoughballs,
    required this.defaultGramsPerBall,
    required this.saltPercent,
    required this.sugarPercent,
    required this.oilPercent,
    this.defaultFermentationMode = 0,
    this.defaultColdFermentDays = 2,
  });
}

enum PizzaType {
  neapolitan,
  newYork,
  sicilian,
  roman;

  /// Look a style up by its persisted `name`, falling back to Neapolitan.
  static PizzaType fromName(String? name) {
    for (final type in PizzaType.values) {
      if (type.name == name) return type;
    }
    return PizzaType.neapolitan;
  }

  PizzaTypeConfig get config {
    switch (this) {
      case PizzaType.neapolitan:
        return const PizzaTypeConfig(
          displayName: 'Neapolitan',
          flourType: '00',
          defaultHydration: 62.0,
          defaultDoughballs: 4,
          defaultGramsPerBall: 250.0,
          saltPercent: 2.5,
          sugarPercent: 0.0,
          oilPercent: 0.0,
          defaultFermentationMode: 0, // Same day
          defaultColdFermentDays: 2,
        );
      case PizzaType.newYork:
        return const PizzaTypeConfig(
          displayName: 'New York',
          flourType: 'Bread Flour',
          defaultHydration: 64.0,
          defaultDoughballs: 4,
          defaultGramsPerBall: 300.0,
          saltPercent: 2.5,
          sugarPercent: 1.0,
          oilPercent: 2.0,
          defaultFermentationMode: 1, // Cold ferment
          defaultColdFermentDays: 2,
        );
      case PizzaType.sicilian:
        return const PizzaTypeConfig(
          displayName: 'Sicilian/Detroit',
          flourType: 'Bread Flour',
          defaultHydration: 74.0,
          defaultDoughballs: 1,
          defaultGramsPerBall: 800.0,
          saltPercent: 2.5,
          sugarPercent: 0.0,
          oilPercent: 3.0,
          defaultFermentationMode: 1, // Cold ferment
          defaultColdFermentDays: 2,
        );
      case PizzaType.roman:
        return const PizzaTypeConfig(
          displayName: 'Roman',
          flourType: '00',
          defaultHydration: 80.0,
          defaultDoughballs: 1,
          defaultGramsPerBall: 800.0,
          saltPercent: 2.5,
          sugarPercent: 0.0,
          oilPercent: 4.0,
          defaultFermentationMode: 1, // Cold ferment
          defaultColdFermentDays: 2,
        );
    }
  }

  /// Pan styles are stretched into a tray rather than divided into balls, so
  /// they skip the balling step and word the freezing advice differently.
  bool get isPanStyle => this == PizzaType.sicilian || this == PizzaType.roman;
}
