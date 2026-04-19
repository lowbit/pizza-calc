import 'dart:math' show sqrt;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:pizza_calc/components/poolish_calculator.dart';
import 'package:pizza_calc/widgets/picker_input.dart';
import 'widgets/enhanced_slider.dart';
import 'components/ingredient_display.dart';
import 'widgets/segmented_control_section.dart';
import 'components/steps_display.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  runApp(const PizzaCalculatorApp());
}

class PizzaCalculatorApp extends StatelessWidget {
  const PizzaCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Pizza Calculator',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.dark,
        barBackgroundColor: Color(0xFF1C1C1C),
        scaffoldBackgroundColor: Color(0xFF000000),
      ),
      home: PizzaCalculatorScreen(),
    );
  }
}

class PizzaCalculatorScreen extends StatefulWidget {
  const PizzaCalculatorScreen({super.key});

  @override
  State<PizzaCalculatorScreen> createState() => _PizzaCalculatorScreenState();
}

// Pizza type definitions with complete defaults
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

  PizzaTypeConfig get config {
    switch (this) {
      case PizzaType.neapolitan:
        return const PizzaTypeConfig(
          displayName: 'Neapolitan',
          flourType: '00',
          defaultHydration: 60.0,
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
}

class _PizzaCalculatorScreenState extends State<PizzaCalculatorScreen> {
  int _doughballs = 4;
  double _gramsPerBall = 250.0;
  double _hydrationPercent = 60.0; // Will be set by pizza type
  PizzaType _pizzaType = PizzaType.neapolitan;
  int _yeastType =
      1; // 0 = fresh (2%), 1 = instant/active dry (0.5%), 2 = poolish
  double _poolishAmount = 300.0; // Amount of poolish to use
  bool _isScreenAwake = false; // Controls whether the screen stays awake
  int _fermentationMode = 0; // 0 = same day (room temp), 1 = cold ferment (fridge)
  int _targetBakeHour = 19; // Default bake time: 7:00 PM
  int _targetBakeMinute = 0;
  int _coldFermentDays = 2; // Default: 2 days cold ferment
  DateTime _planStartTime = DateTime.now(); // Snapshot of when the plan was created

  // Compute effective fermentation hours for yeast calculation
  double get _effectiveFermentationHours {
    if (_fermentationMode == 0) {
      final now = DateTime.now();
      final target = DateTime(
        now.year, now.month, now.day,
        _targetBakeHour, _targetBakeMinute,
      );
      final diffMinutes = target.difference(now).inMinutes;
      if (diffMinutes < 120) return 2.0; // Minimum 2 hours
      return diffMinutes / 60.0;
    } else {
      return (_coldFermentDays * 24).toDouble();
    }
  }

  // Format time for display (e.g., "19:00")
  String _formatTimeOfDay(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // Format duration for display (e.g., "5h 30m")
  String _formatDuration(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  // Get minutes from now to target bake time (for same day mode)
  int get _minutesToBakeTime {
    final now = DateTime.now();
    final target = DateTime(
      now.year, now.month, now.day,
      _targetBakeHour, _targetBakeMinute,
    );
    return target.difference(now).inMinutes;
  }

  // Dynamic yeast percentage based on type, pizza type, and fermentation time
  double get _yeastPercent {
    if (_yeastType == 2) return 0.0; // Poolish has its own yeast

    // Base yeast percentages at reference fermentation time
    // Fresh yeast (type 0) is ~3x instant (type 1) by weight
    // Same day (room temp): reference is 8h
    // Cold ferment (fridge): reference is 24h
    Map<int, Map<int, double>> baseYeastForReference = {
      0: {0: 0.9, 1: 0.3},  // Same day (room temp, 8h reference)
      1: {0: 0.6, 1: 0.2},  // Cold ferment (fridge, 24h reference)
    };

    Map<int, int> referenceTime = {
      0: 8,   // Same day reference
      1: 24,  // Cold ferment reference
    };

    double basePercent = baseYeastForReference[_fermentationMode]?[_yeastType] ?? 0.3;
    int refTime = referenceTime[_fermentationMode] ?? 8;

    // Calculate yeast using inverse square root relationship
    // Standard baker's formula: yeast adjusts inversely with square root of time
    double timeRatio = refTime / _effectiveFermentationHours;
    double calculatedPercent = basePercent * sqrt(timeRatio.clamp(0.1, 16.0));

    // Ensure reasonable bounds for yeast percentage
    Map<int, List<double>> bounds = {
      0: [0.2, 2.5],  // Fresh yeast bounds
      1: [0.05, 1.0], // Instant yeast bounds
    };

    calculatedPercent = calculatedPercent.clamp(
      bounds[_yeastType]![0],
      bounds[_yeastType]![1],
    );

    return calculatedPercent;
  }

  // Load saved settings from SharedPreferences
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      final typeKey = _pizzaType.name;
      _hydrationPercent =
          prefs.getDouble('${typeKey}_hydration') ??
          _pizzaType.config.defaultHydration;
      _doughballs =
          prefs.getInt('${typeKey}_doughballs') ??
          _pizzaType.config.defaultDoughballs;
      _gramsPerBall =
          prefs.getDouble('${typeKey}_gramsPerBall') ??
          _pizzaType.config.defaultGramsPerBall;
      _yeastType = prefs.getInt('${typeKey}_yeastType') ?? 1;
      _poolishAmount = prefs.getDouble('${typeKey}_poolishAmount') ?? 300.0;
      _fermentationMode =
          prefs.getInt('${typeKey}_fermentationMode') ??
          _pizzaType.config.defaultFermentationMode;
      _targetBakeHour = prefs.getInt('${typeKey}_targetBakeHour') ?? 19;
      _targetBakeMinute = prefs.getInt('${typeKey}_targetBakeMinute') ?? 0;
      _coldFermentDays =
          prefs.getInt('${typeKey}_coldFermentDays') ??
          _pizzaType.config.defaultColdFermentDays;
      _planStartTime = DateTime.now();
    });
  }

  // Save current settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final typeKey = _pizzaType.name;

    await prefs.setDouble('${typeKey}_hydration', _hydrationPercent);
    await prefs.setInt('${typeKey}_doughballs', _doughballs);
    await prefs.setDouble('${typeKey}_gramsPerBall', _gramsPerBall);
    await prefs.setInt('${typeKey}_yeastType', _yeastType);
    await prefs.setDouble('${typeKey}_poolishAmount', _poolishAmount);
    await prefs.setInt('${typeKey}_fermentationMode', _fermentationMode);
    await prefs.setInt('${typeKey}_targetBakeHour', _targetBakeHour);
    await prefs.setInt('${typeKey}_targetBakeMinute', _targetBakeMinute);
    await prefs.setInt('${typeKey}_coldFermentDays', _coldFermentDays);
  }

  // Check if current settings differ from defaults
  bool get _hasCustomSettings {
    return _hydrationPercent != _pizzaType.config.defaultHydration ||
        _doughballs != _pizzaType.config.defaultDoughballs ||
        _gramsPerBall != _pizzaType.config.defaultGramsPerBall ||
        _yeastType != 1 ||
        _poolishAmount != 300.0 ||
        _fermentationMode != _pizzaType.config.defaultFermentationMode ||
        _targetBakeHour != 19 ||
        _targetBakeMinute != 0 ||
        _coldFermentDays != _pizzaType.config.defaultColdFermentDays;
  }

  // Reset to default settings for current pizza type
  Future<void> _resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final typeKey = _pizzaType.name;

    await prefs.remove('${typeKey}_hydration');
    await prefs.remove('${typeKey}_doughballs');
    await prefs.remove('${typeKey}_gramsPerBall');
    await prefs.remove('${typeKey}_yeastType');
    await prefs.remove('${typeKey}_poolishAmount');
    await prefs.remove('${typeKey}_fermentationMode');
    await prefs.remove('${typeKey}_targetBakeHour');
    await prefs.remove('${typeKey}_targetBakeMinute');
    await prefs.remove('${typeKey}_coldFermentDays');

    setState(() {
      _hydrationPercent = _pizzaType.config.defaultHydration;
      _doughballs = _pizzaType.config.defaultDoughballs;
      _gramsPerBall = _pizzaType.config.defaultGramsPerBall;
      _yeastType = 1;
      _poolishAmount = 300.0;
      _fermentationMode = _pizzaType.config.defaultFermentationMode;
      _targetBakeHour = 19;
      _targetBakeMinute = 0;
      _coldFermentDays = _pizzaType.config.defaultColdFermentDays;
    });
  }

  // Calculate ingredients based on inputs
  Map<String, double> _calculateIngredients() {
    final double totalDoughWeight = _doughballs * _gramsPerBall;

    if (_yeastType == 2) {
      // Poolish calculation
      final double poolishFlour =
          _poolishAmount / 2; // 100% hydration = 50% flour, 50% water
      final double poolishWater = _poolishAmount / 2;

      // Calculate remaining flour needed
      final double multiplier =
          1 +
          (_hydrationPercent / 100) +
          (_pizzaType.config.saltPercent / 100) +
          (_pizzaType.config.sugarPercent / 100) +
          (_pizzaType.config.oilPercent / 100);
      final double totalFlourNeeded = totalDoughWeight / multiplier;
      final double remainingFlour = totalFlourNeeded - poolishFlour;

      // Calculate remaining water needed
      final double totalWaterNeeded =
          totalFlourNeeded * (_hydrationPercent / 100);
      final double remainingWater = totalWaterNeeded - poolishWater;

      final Map<String, double> ingredients = {
        'flour': remainingFlour,
        'water': remainingWater,
        'salt': totalFlourNeeded * (_pizzaType.config.saltPercent / 100),
        'poolish': _poolishAmount,
      };

      // Add sugar and oil based on pizza type
      if (_pizzaType.config.sugarPercent > 0) {
        ingredients['sugar'] =
            totalFlourNeeded * (_pizzaType.config.sugarPercent / 100);
      }
      if (_pizzaType.config.oilPercent > 0) {
        ingredients['oil'] =
            totalFlourNeeded * (_pizzaType.config.oilPercent / 100);
      }

      return ingredients;
    } else {
      // Standard yeast calculation
      final double multiplier =
          1 +
          (_hydrationPercent / 100) +
          (_pizzaType.config.saltPercent / 100) +
          (_pizzaType.config.sugarPercent / 100) +
          (_pizzaType.config.oilPercent / 100) +
          (_yeastPercent / 100);
      final double flourWeight = totalDoughWeight / multiplier;

      final Map<String, double> ingredients = {
        'flour': flourWeight,
        'water': flourWeight * (_hydrationPercent / 100),
        'salt': flourWeight * (_pizzaType.config.saltPercent / 100),
        'yeast': flourWeight * (_yeastPercent / 100),
      };

      // Add sugar and oil based on pizza type
      if (_pizzaType.config.sugarPercent > 0) {
        ingredients['sugar'] =
            flourWeight * (_pizzaType.config.sugarPercent / 100);
      }
      if (_pizzaType.config.oilPercent > 0) {
        ingredients['oil'] = flourWeight * (_pizzaType.config.oilPercent / 100);
      }

      return ingredients;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = _calculateIngredients();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        middle: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _showPizzaTypeSelector();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_pizzaType.config.displayName} Pizza',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.chevron_down,
                color: CupertinoColors.white,
                size: 16,
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1C1C1C),
        border: null,
        leading: _hasCustomSettings
            ? GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('Reset Settings'),
                      content: const Text(
                        'Reset all settings for this pizza type to defaults?',
                      ),
                      actions: [
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context);
                            _resetToDefaults();
                          },
                          child: const Text('Reset'),
                        ),
                        CupertinoDialogAction(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Icon(
                  CupertinoIcons.refresh,
                  color: CupertinoColors.systemBlue,
                  size: 24,
                ),
              )
            : null,
        trailing: GestureDetector(
          onTap: () async {
            try {
              // First async gap: getting preferences.
              final prefs = await SharedPreferences.getInstance();

              // FIX: Check if the widget is still mounted *before* using its context.
              // Using context.mounted is the modern, recommended approach.
              if (!context.mounted) return;

              final hasSeenWakelockExplanation =
                  prefs.getBool('hasSeenWakelockExplanation') ?? false;

              if (!hasSeenWakelockExplanation) {
                // The context is safe to use here because we just checked it.
                await showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: const Text('Keep Screen On'),
                    content: const Text(
                      'This feature keeps your screen on while you make pizza. Useful when your hands are covered in flour! 🍕\n\nYou can toggle this any time using the sun icon.',
                    ),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                        },
                        child: const Text('Got it!'),
                      ),
                    ],
                  ),
                );

                // FIX: Check AGAIN after the dialog closes (another async gap).
                if (!context.mounted) return;
                await prefs.setBool('hasSeenWakelockExplanation', true);
              }

              // It's now safe to update the state.
              setState(() {
                _isScreenAwake = !_isScreenAwake;
              });

              // These last operations don't rely on the context, so they're fine.
              await WakelockPlus.toggle(enable: _isScreenAwake);
              await prefs.setBool('isScreenAwake', _isScreenAwake);
              HapticFeedback.selectionClick();
            } catch (e) {
              // It's good practice to catch potential errors.
              debugPrint("Error handling wakelock toggle: $e");
            }
          },
          child: Icon(
            _isScreenAwake
                ? CupertinoIcons.sun_dust_fill
                : CupertinoIcons.sun_dust,
            color: _isScreenAwake
                ? CupertinoColors.systemBlue
                : CupertinoColors.systemGrey,
            size: 24,
          ),
        ),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputSection(),
                    const SizedBox(height: 40),
                    IngredientsDisplay(
                      ingredients: ingredients,
                      flourType: _pizzaType.config.flourType,
                    ),
                     const SizedBox(height: 24),
                    StepsDisplay(
                      pizzaType: _pizzaType.config.displayName,
                      isColdFerment: _fermentationMode == 1,
                      coldFermentDays: _coldFermentDays,
                      targetBakeTime: _fermentationMode == 0
                          ? DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                              _targetBakeHour,
                              _targetBakeMinute,
                            )
                          : null,
                      planStartTime: _fermentationMode == 0
                          ? _planStartTime
                          : null,
                    ),
                    const SizedBox(height: 20),
                    // Developer credit
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showHawaiianPizzaToast();
                            },
                            child: Text(
                              'Made by Rijad Spahic',
                              style: TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dough Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.white,
          ),
        ),
        const SizedBox(height: 20),
        PickerInput(
          title: 'Doughballs',
          value: _doughballs.toString(),
          onTap: _showDoughballsPicker,
          onDecrease: _doughballs > 1
              ? () => _updateDoughballs(_doughballs - 1)
              : null,
          onIncrease: _doughballs < 50
              ? () => _updateDoughballs(_doughballs + 1)
              : null,
        ),
        const SizedBox(height: 16),
        PickerInput(
          title: 'Grams per ball',
          value: '${_gramsPerBall.round()}g',
          onTap: _showWeightPicker,
          onDecrease: _gramsPerBall > 150
              ? () => _updateWeight(_gramsPerBall - 10)
              : null,
          onIncrease: _gramsPerBall < 1000
              ? () => _updateWeight(_gramsPerBall + 10)
              : null,
        ),
        const SizedBox(height: 16),
        EnhancedSlider(
          title: 'Hydration',
          value: _hydrationPercent,
          displayValue: '${_hydrationPercent.round()}%',
          min: 55.0,
          max: 80.0,
          divisions: 25,
          onChanged: _updateHydration,
          onTap: _showHydrationPicker,
          markers: const ['55%', '65%', '75%', '80%'],
        ),
        const SizedBox(height: 16),
        SegmentedControlSection<int>(
            title: 'Fermentation',
            groupValue: _fermentationMode,
            onValueChanged: _updateFermentationMode,
            children: {
              0: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Center(
                  child: Text(
                    'Same Day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
              1: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Center(
                  child: Text(
                    'Cold Ferment',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            },
          ),
          const SizedBox(height: 12),
          if (_fermentationMode == 0) ...[
            // Same Day: bake time picker with duration display
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _showBakeTimePicker();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bake at',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.white,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatTimeOfDay(_targetBakeHour, _targetBakeMinute),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.systemBlue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              CupertinoIcons.chevron_right,
                              color: Color(0xFF8E8E93),
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          _minutesToBakeTime < 120
                              ? CupertinoIcons.exclamationmark_triangle_fill
                              : CupertinoIcons.clock,
                          size: 14,
                          color: _minutesToBakeTime < 120
                              ? CupertinoColors.systemYellow
                              : const Color(0xFF8E8E93),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _minutesToBakeTime < 0
                              ? 'Time has passed — pick a later time'
                              : _minutesToBakeTime < 120
                                  ? 'Only ~${_formatDuration(_minutesToBakeTime / 60.0)} — dough needs more time'
                                  : '~${_formatDuration(_effectiveFermentationHours)} fermentation at room temp',
                          style: TextStyle(
                            fontSize: 13,
                            color: _minutesToBakeTime < 120
                                ? CupertinoColors.systemYellow
                                : const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Cold Ferment: days picker
            PickerInput(
              title: 'Days in fridge',
              value: '$_coldFermentDays ${_coldFermentDays == 1 ? 'day' : 'days'}',
              onTap: _showColdFermentDaysPicker,
              onDecrease: _coldFermentDays > 1
                  ? () => _updateColdFermentDays(_coldFermentDays - 1)
                  : null,
              onIncrease: _coldFermentDays < 5
                  ? () => _updateColdFermentDays(_coldFermentDays + 1)
                  : null,
            ),
            if (_coldFermentDays >= 4) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.info_circle,
                      size: 14,
                      color: Color(0xFF8E8E93),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _coldFermentDays == 4
                          ? 'Extended — flavor peaks, watch for over-proofing'
                          : 'Maximum — dough may lose structure',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        const SizedBox(height: 16),
        SegmentedControlSection<int>(
          title: 'Yeast Type',
          groupValue: _yeastType,
          onValueChanged: _updateYeastType,
          children: {
            0: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Center(
                child: Text(
                  'Fresh',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
            1: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Center(
                child: Text(
                  'Instant/Dry',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
            2: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Center(
                child: Text(
                  'Poolish',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
          },
        ),
        if (_yeastType == 2) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _showPoolishCalculator();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Poolish Amount',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${_poolishAmount.round()}g',
                        style: const TextStyle(
                          color: CupertinoColors.systemBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        color: Color(0xFF8E8E93),
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Helper methods for updating values with haptic feedback
  void _updateDoughballs(int value) {
    setState(() {
      _doughballs = value;
    });
    _saveSettings();
    HapticFeedback.lightImpact();
  }

  void _updateWeight(double value) {
    setState(() {
      _gramsPerBall = value;
    });
    _saveSettings();
    HapticFeedback.lightImpact();
  }

  void _updateHydration(double value) {
    setState(() {
      _hydrationPercent = value;
    });
    _saveSettings();
    HapticFeedback.selectionClick();
  }

  void _updateYeastType(int? yeastType) {
    if (yeastType != null) {
      setState(() {
        _yeastType = yeastType;
      });
      _saveSettings();
    }
    HapticFeedback.selectionClick();
  }

  void _updateFermentationMode(int? mode) {
    if (mode != null) {
      setState(() {
        _fermentationMode = mode;
        _planStartTime = DateTime.now();
      });
      _saveSettings();
    }
    HapticFeedback.selectionClick();
  }

  void _updateColdFermentDays(int days) {
    setState(() {
      _coldFermentDays = days;
    });
    _saveSettings();
    HapticFeedback.lightImpact();
  }

  void _showBakeTimePicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 300,
        color: const Color(0xFF1C1C1C),
        child: Column(
          children: [
            Container(
              height: 50,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                    },
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(
                  2024, 1, 1,
                  _targetBakeHour, _targetBakeMinute,
                ),
                minuteInterval: 15,
                use24hFormat: true,
                backgroundColor: const Color(0xFF1C1C1C),
                onDateTimeChanged: (DateTime value) {
                  setState(() {
                    _targetBakeHour = value.hour;
                    _targetBakeMinute = value.minute;
                    _planStartTime = DateTime.now();
                  });
                  _saveSettings();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColdFermentDaysPicker() {
    final days = List.generate(5, (index) => index + 1);
    ValuePicker.show<int>(
      context: context,
      items: days,
      initialValue: _coldFermentDays,
      onChanged: _updateColdFermentDays,
      displayBuilder: (value) => '$value ${value == 1 ? 'day' : 'days'}',
    );
  }

  void _updatePizzaType(PizzaType pizzaType) {
    setState(() {
      _pizzaType = pizzaType;
    });
    // Load saved settings for the new pizza type
    _loadSavedSettings();
    HapticFeedback.selectionClick();
  }

  void _showPizzaTypeSelector() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text(
          'Select Pizza Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: PizzaType.values.map((pizzaType) {
          return CupertinoActionSheetAction(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              _updatePizzaType(pizzaType);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pizzaType.config.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_pizzaType == pizzaType)
                  const Icon(
                    CupertinoIcons.checkmark,
                    color: CupertinoColors.systemBlue,
                    size: 20,
                  ),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showPoolishCalculator() async {
    final result = await PoolishCalculator.show(
      context: context,
      initialAmount: _poolishAmount,
    );
    if (result != null) {
      setState(() {
        _poolishAmount = result;
      });
      _saveSettings();
    }
  }

  void _showHawaiianPizzaToast() {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: CupertinoAlertDialog(
          content: const Text(
            '🍕🍍 Hawaiian pizza da best',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
              child: const Text('I agree!'),
            ),
          ],
        ),
      ),
    );
  }

  // Picker methods using reusable ValuePicker component
  void _showDoughballsPicker() {
    final values = List.generate(50, (index) => index + 1);
    ValuePicker.show<int>(
      context: context,
      items: values,
      initialValue: _doughballs,
      onChanged: _updateDoughballs,
      displayBuilder: (value) => value.toString(),
    );
  }

  void _showWeightPicker() {
    final weights = List.generate(86, (index) => 150.0 + (index * 10));
    ValuePicker.show<double>(
      context: context,
      items: weights,
      initialValue: _gramsPerBall,
      onChanged: _updateWeight,
      displayBuilder: (value) => '${value.round()}g',
    );
  }

  void _showHydrationPicker() {
    final percentages = List.generate(26, (index) => 55.0 + index);
    ValuePicker.show<double>(
      context: context,
      items: percentages,
      initialValue: _hydrationPercent,
      onChanged: _updateHydration,
      displayBuilder: (value) => '${value.round()}%',
    );
  }
}
