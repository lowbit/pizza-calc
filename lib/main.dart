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

  const PizzaTypeConfig({
    required this.displayName,
    required this.flourType,
    required this.defaultHydration,
    required this.defaultDoughballs,
    required this.defaultGramsPerBall,
    required this.saltPercent,
    required this.sugarPercent,
    required this.oilPercent,
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
          saltPercent: 2.0,
          sugarPercent: 0.0,
          oilPercent: 0.0,
        );
      case PizzaType.newYork:
        return const PizzaTypeConfig(
          displayName: 'New York',
          flourType: 'Bread Flour',
          defaultHydration: 64.0,
          defaultDoughballs: 4,
          defaultGramsPerBall: 280.0,
          saltPercent: 2.0,
          sugarPercent: 1.0,
          oilPercent: 2.0,
        );
      case PizzaType.sicilian:
        return const PizzaTypeConfig(
          displayName: 'Sicilian/Detroit',
          flourType: 'Bread Flour',
          defaultHydration: 74.0,
          defaultDoughballs: 1,
          defaultGramsPerBall: 800.0,
          saltPercent: 2.0,
          sugarPercent: 0.0,
          oilPercent: 3.0,
        );
      case PizzaType.roman:
        return const PizzaTypeConfig(
          displayName: 'Roman',
          flourType: '00',
          defaultHydration: 70.0,
          defaultDoughballs: 1,
          defaultGramsPerBall: 800.0,
          saltPercent: 2.0,
          sugarPercent: 0.0,
          oilPercent: 4.0,
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
  bool _isOvernightRise = false; // false = same day, true = overnight (24h)
  bool _isScreenAwake = false; // Controls whether the screen stays awake

  // Dynamic yeast percentage based on type and rise time (not used for poolish)
  double get _yeastPercent {
    double basePercent;
    switch (_yeastType) {
      case 0:
        basePercent = 2.0; // Fresh
        break;
      case 1:
        basePercent = 0.5; // Instant/Active Dry
        break;
      default:
        return 0.0; // Poolish (no additional yeast, not affected by rise time)
    }

    // Halve yeast for overnight rise (24h fermentation)
    return _isOvernightRise ? basePercent / 2 : basePercent;
  }

  // Load saved settings from SharedPreferences
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // Load settings for current pizza type
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
      _isOvernightRise = prefs.getBool('${typeKey}_isOvernightRise') ?? false;
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
    await prefs.setBool('${typeKey}_isOvernightRise', _isOvernightRise);
  }

  // Check if current settings differ from defaults
  bool get _hasCustomSettings {
    return _hydrationPercent != _pizzaType.config.defaultHydration ||
        _doughballs != _pizzaType.config.defaultDoughballs ||
        _gramsPerBall != _pizzaType.config.defaultGramsPerBall ||
        _yeastType != 1 ||
        _poolishAmount != 300.0 ||
        _isOvernightRise != false;
  }

  // Reset to default settings for current pizza type
  Future<void> _resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final typeKey = _pizzaType.name;

    // Remove saved settings for current type
    await prefs.remove('${typeKey}_hydration');
    await prefs.remove('${typeKey}_doughballs');
    await prefs.remove('${typeKey}_gramsPerBall');
    await prefs.remove('${typeKey}_yeastType');
    await prefs.remove('${typeKey}_poolishAmount');
    await prefs.remove('${typeKey}_isOvernightRise');

    // Reset to defaults
    setState(() {
      _hydrationPercent = _pizzaType.config.defaultHydration;
      _doughballs = _pizzaType.config.defaultDoughballs;
      _gramsPerBall = _pizzaType.config.defaultGramsPerBall;
      _yeastType = 1;
      _poolishAmount = 300.0;
      _isOvernightRise = false;
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
          onTap: _showPizzaTypeSelector,
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
                            Navigator.pop(context);
                            _resetToDefaults();
                          },
                          child: const Text('Reset'),
                        ),
                        CupertinoDialogAction(
                          onPressed: () => Navigator.pop(context),
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
            final prefs = await SharedPreferences.getInstance();
            final hasSeenWakelockExplanation =
                prefs.getBool('hasSeenWakelockExplanation') ?? false;

            if (!hasSeenWakelockExplanation) {
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
                        Navigator.pop(context);
                      },
                      child: const Text('Got it!'),
                    ),
                  ],
                ),
              );
              await prefs.setBool('hasSeenWakelockExplanation', true);
            }

            setState(() {
              _isScreenAwake = !_isScreenAwake;
            });
            await WakelockPlus.toggle(enable: _isScreenAwake);
            await prefs.setBool('isScreenAwake', _isScreenAwake);
            HapticFeedback.selectionClick();
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
                      isOvernightRise: _isOvernightRise,
                    ),
                    const SizedBox(height: 20),
                    // Developer credit
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _showHawaiianPizzaToast,
                            child: Text(
                              'Made with ❤️ by Rijad Spahic',
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
        SegmentedControlSection<bool>(
          title: 'Rise Time',
          groupValue: _isOvernightRise,
          onValueChanged: _updateRiseTime,
          children: {
            false: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.sun_max,
                    color: !_isOvernightRise
                        ? const Color(0xFFFF6B35) // Orange when selected
                        : CupertinoColors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Same Day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.white,
                    ),
                  ),
                ],
              ),
            ),
            true: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.moon,
                    color: _isOvernightRise
                        ? const Color(0xFF4A90E2) // Blue when selected
                        : CupertinoColors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Overnight',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.white,
                    ),
                  ),
                ],
              ),
            ),
          },
        ),
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
            onTap: _showPoolishCalculator,
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

  void _updateRiseTime(bool? isOvernight) {
    if (isOvernight != null) {
      setState(() {
        _isOvernightRise = isOvernight;
      });
      _saveSettings();
    }
    HapticFeedback.selectionClick();
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
      builder: (context) => WillPopScope(
        onWillPop: () async {
          // Don't allow back button to dismiss
          return false;
        },
        child: CupertinoAlertDialog(
          content: const Text(
            '🍕🍍 Hawaiian pizza da best',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
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
