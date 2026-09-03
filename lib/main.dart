import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'components/bake_issue_banner.dart';
import 'components/bake_summary_card.dart';
import 'components/dough_settings_section.dart';
import 'components/ingredient_display.dart';
import 'components/poolish_calculator.dart';
import 'components/steps_checklist.dart';
import 'data/recipes.dart';
import 'models/bake_session.dart';
import 'models/bake_step.dart';
import 'models/pizza_type.dart';
import 'services/bake_notifications.dart';
import 'services/bake_schedule.dart';
import 'services/dough_calculator.dart';
import 'styles/app_theme.dart';
import 'utils/haptics.dart';
import 'utils/time_format.dart';
import 'widgets/time_wheel_picker.dart';
import 'widgets/value_picker.dart';

void main() {
  runApp(const PizzaCalculatorApp());
}

class PizzaCalculatorApp extends StatelessWidget {
  const PizzaCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Matches android:label, so the launcher and the task switcher agree.
      title: 'Pizzazz',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const PizzaCalculatorScreen(),
    );
  }
}

class PizzaCalculatorScreen extends StatefulWidget {
  const PizzaCalculatorScreen({super.key});

  @override
  State<PizzaCalculatorScreen> createState() => _PizzaCalculatorScreenState();
}

class _PizzaCalculatorScreenState extends State<PizzaCalculatorScreen> {
  static const _sessionKey = 'activeBakeSession';

  int _doughballs = 4;
  double _gramsPerBall = 250.0;
  double _hydrationPercent = 62.0;
  PizzaType _pizzaType = PizzaType.neapolitan;
  int _yeastType = 1; // 0 = fresh, 1 = instant/active dry, 2 = poolish
  double _poolishAmount = 300.0;
  bool _isScreenAwake = false;
  int _fermentationMode = 0; // 0 = same day, 1 = cold ferment
  int _targetBakeHour = 19;
  int _targetBakeMinute = 0;
  int _coldFermentDays = 2;

  /// The bake actually under way, if any. While this is non-null the recipe is
  /// locked: you cannot re-weigh flour that is already mixed, and nothing may
  /// silently shift the timeline you are following.
  BakeSession? _session;

  AlarmCapability _alarms = AlarmCapability.none;

  bool get _isBaking => _session != null;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  // ── Persistence ───────────────────────────────────────────────

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedType = prefs.getString('lastPizzaType');
    if (savedType != null) {
      setState(() => _pizzaType = PizzaType.fromName(savedType));
    }

    await _loadSavedSettings();
    if (!mounted) return;

    final session = BakeSession.decode(prefs.getString(_sessionKey));
    if (session != null) {
      setState(() {
        _session = session;
        // Mirror the frozen recipe into the inputs so the summary and the
        // ingredient list agree with what is actually in the bowl.
        _applyInputs(session.inputs);
      });
    }

    if (prefs.getBool('isScreenAwake') ?? false) {
      await WakelockPlus.toggle(enable: true);
      if (!mounted) return;
      setState(() => _isScreenAwake = true);
    }
  }

  void _applyInputs(DoughInputs inputs) {
    _pizzaType = inputs.pizzaType;
    _doughballs = inputs.doughballs;
    _gramsPerBall = inputs.gramsPerBall;
    _hydrationPercent = inputs.hydrationPercent;
    _yeastType = inputs.yeastType;
    _poolishAmount = inputs.poolishAmount;
    _fermentationMode = inputs.fermentationMode;
    _coldFermentDays = inputs.coldFermentDays;
    _targetBakeHour = inputs.targetBakeHour;
    _targetBakeMinute = inputs.targetBakeMinute;
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      final key = _pizzaType.name;
      final config = _pizzaType.config;
      _hydrationPercent =
          prefs.getDouble('${key}_hydration') ?? config.defaultHydration;
      _doughballs = prefs.getInt('${key}_doughballs') ?? config.defaultDoughballs;
      _gramsPerBall =
          prefs.getDouble('${key}_gramsPerBall') ?? config.defaultGramsPerBall;
      _yeastType = prefs.getInt('${key}_yeastType') ?? 1;
      _poolishAmount = prefs.getDouble('${key}_poolishAmount') ?? 300.0;
      _fermentationMode =
          prefs.getInt('${key}_fermentationMode') ??
          config.defaultFermentationMode;
      _targetBakeHour = prefs.getInt('${key}_targetBakeHour') ?? 19;
      _targetBakeMinute = prefs.getInt('${key}_targetBakeMinute') ?? 0;
      _coldFermentDays =
          prefs.getInt('${key}_coldFermentDays') ??
          config.defaultColdFermentDays;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _pizzaType.name;
    await prefs.setDouble('${key}_hydration', _hydrationPercent);
    await prefs.setInt('${key}_doughballs', _doughballs);
    await prefs.setDouble('${key}_gramsPerBall', _gramsPerBall);
    await prefs.setInt('${key}_yeastType', _yeastType);
    await prefs.setDouble('${key}_poolishAmount', _poolishAmount);
    await prefs.setInt('${key}_fermentationMode', _fermentationMode);
    await prefs.setInt('${key}_targetBakeHour', _targetBakeHour);
    await prefs.setInt('${key}_targetBakeMinute', _targetBakeMinute);
    await prefs.setInt('${key}_coldFermentDays', _coldFermentDays);
  }

  Future<void> _persistPizzaType(PizzaType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastPizzaType', type.name);
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    final session = _session;
    if (session == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, session.encode());
    }
  }

  // ── Derived state ─────────────────────────────────────────────

  DoughInputs get _currentInputs => DoughInputs(
    pizzaType: _pizzaType,
    doughballs: _doughballs,
    gramsPerBall: _gramsPerBall,
    hydrationPercent: _hydrationPercent,
    yeastType: _yeastType,
    poolishAmount: _poolishAmount,
    fermentationMode: _fermentationMode,
    coldFermentDays: _coldFermentDays,
    targetBakeHour: _targetBakeHour,
    targetBakeMinute: _targetBakeMinute,
  );

  /// When the pizza should go in, for a plan that has not started yet.
  ///
  /// Same-day rolls to tomorrow once today's slot has passed, so "bake at
  /// 19:00" always means the next 19:00 rather than a time in the past.
  DateTime get _plannedTargetBake {
    final now = DateTime.now();
    if (_fermentationMode == 0) {
      var target = DateTime(
        now.year,
        now.month,
        now.day,
        _targetBakeHour,
        _targetBakeMinute,
      );
      if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
      return target;
    }
    final day = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: _coldFermentDays));
    return DateTime(
      day.year,
      day.month,
      day.day,
      _targetBakeHour,
      _targetBakeMinute,
    );
  }

  DateTime get _targetBake => _session?.targetBake ?? _plannedTargetBake;

  double get _fermentationHours => effectiveFermentationHours(
    _currentInputs,
    from: _session?.startedAt ?? DateTime.now(),
    targetBake: _targetBake,
  );

  BakeSchedule get _schedule {
    final now = DateTime.now();
    final session = _session;
    if (session != null) {
      return buildSchedule(
        specs: stepsFor(
          session.inputs.pizzaType,
          isColdFerment: session.inputs.isColdFerment,
        ),
        anchorStart: session.startedAt,
        targetBake: session.targetBake,
        now: now,
        completed: session.completed,
        started: true,
      );
    }
    return buildSchedule(
      specs: stepsFor(_pizzaType, isColdFerment: _fermentationMode == 1),
      anchorStart: now,
      targetBake: _plannedTargetBake,
      now: now,
    );
  }

  /// Ingredients come from the session once baking, so the numbers on screen
  /// stay the numbers that were weighed out.
  Map<String, double> get _ingredients =>
      _session?.ingredients ??
      computeIngredients(_currentInputs, fermentationHours: _fermentationHours);

  bool get _hasCustomSettings {
    final config = _pizzaType.config;
    return _hydrationPercent != config.defaultHydration ||
        _doughballs != config.defaultDoughballs ||
        _gramsPerBall != config.defaultGramsPerBall ||
        _yeastType != 1 ||
        _poolishAmount != 300.0 ||
        _fermentationMode != config.defaultFermentationMode ||
        _targetBakeHour != 19 ||
        _targetBakeMinute != 0 ||
        _coldFermentDays != config.defaultColdFermentDays;
  }

  // ── Bake lifecycle ────────────────────────────────────────────

  Future<void> _startBake() async {
    Haptics.commit();
    final now = DateTime.now();
    final session = BakeSession(
      inputs: _currentInputs,
      ingredients: computeIngredients(
        _currentInputs,
        fermentationHours: _fermentationHours,
      ),
      startedAt: now,
      targetBake: _plannedTargetBake,
    );

    setState(() => _session = session);
    await _persistSession();

    // Ask for notification permission here rather than at first launch: this
    // is the moment it makes sense to the baker.
    final capability = await BakeNotifications.instance.requestPermissions();
    if (!mounted) return;
    setState(() => _alarms = capability);
    await _syncAlarms();
  }

  Future<void> _syncAlarms() async {
    if (!_alarms.notificationsAllowed) return;
    await BakeNotifications.instance.syncForSchedule(
      _schedule,
      exactAllowed: _alarms.exactAllowed,
    );
  }

  Future<void> _completeStep(ScheduledStep step) async {
    final session = _session;
    if (session == null) return;

    final now = DateTime.now();
    if (step.isRushedAt(now) && !await _confirmEarlyFinish(step, now)) return;
    if (!mounted) return;

    setState(() => _session = session.completing(step.spec.id, DateTime.now()));
    await _persistSession();
    await _syncAlarms();
  }

  /// Asks before ticking a step that the dough has not really had time for.
  ///
  /// Only steps with a [StepSpec.floorMinutes] can get here, so mixing or
  /// baking faster than planned never asks. It is a question, not a block: the
  /// recipe tells you to judge a proof by feel, a warm kitchen genuinely does
  /// halve it, and the dough may have been mixed before the app was opened.
  /// It also catches the mis-tap, which is the expensive case, because a tick
  /// stamps a real timestamp and re-plans everything after it.
  Future<bool> _confirmEarlyFinish(ScheduledStep step, DateTime now) async {
    final elapsed = step.elapsedAt(now);
    final floor = step.spec.floorMinutes!;
    // Two shapes, because "has had 0m of a planned 17h" is not a sentence
    // anyone would write.
    final opening = elapsed.inMinutes < 1
        ? '${step.spec.title} has only just started. It was planned for '
              '${formatSpan(step.duration)} and usually needs at least '
              '${formatMinutes(floor)}.'
        : '${step.spec.title} has had ${formatDuration(elapsed)} of a planned '
              '${formatSpan(step.duration)}, and usually needs at least '
              '${formatMinutes(floor)}.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // No figures in the title: it renders on the display face, and
        // Fraunces has old-style figures. The numbers live in the body.
        title: const Text('Finish this early?'),
        content: Text(
          '$opening Finishing now records the real time and brings the rest '
          'of the bake forward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark done'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Undo a step *and everything after it*. The checklist button already
  /// fires the haptic, so this must not, it used to, and undo buzzed twice.
  Future<void> _undoStep(ScheduledStep step) async {
    final session = _session;
    if (session == null) return;
    // Read the order before mutating. `_schedule` is a getter that rebuilds
    // from `_session`, and the recipe order is the same either side of an undo
    //, but computing it up front keeps that independence obvious.
    final orderedIds = [for (final s in _schedule.steps) s.spec.id];
    setState(
      () => _session = session.uncompletingFrom(step.spec.id, orderedIds),
    );
    await _persistSession();
    await _syncAlarms();
  }

  Future<void> _moveBakeTime(DateTime suggested) async {
    final session = _session;
    if (session != null) {
      setState(() => _session = session.copyWith(targetBake: suggested));
      await _persistSession();
      await _syncAlarms();
      return;
    }
    setState(() {
      _targetBakeHour = suggested.hour;
      _targetBakeMinute = suggested.minute;
    });
    await _saveSettings();
  }

  Future<void> _confirmStartOver() async {
    // Nothing to lose once the bake is over, the dialog would be asking you
    // to confirm discarding a pizza you have already eaten. Clearing a
    // finished bake is just tidying up.
    if (_schedule.isComplete) {
      await _endBake();
      return;
    }

    Haptics.select();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this bake?'),
        content: const Text(
          'This throws away the bake in progress, including the times you have '
          'already ticked off.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep baking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _endBake();
  }

  Future<void> _endBake() async {
    Haptics.commit();
    setState(() => _session = null);
    await _persistSession();
    await BakeNotifications.instance.cancelAll();
  }

  Future<void> _setPhoneAlarm(ScheduledStep step) async {
    final ok = await BakeNotifications.instance.setPhoneAlarm(
      step.end,
      'Pizza: ${step.spec.title} done',
    );
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Couldn't open a clock app on this device."),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = _schedule;
    final issues = [
      ...schedule.issues,
      if (!_isBaking)
        ...doughIssues(
          _currentInputs,
          start: DateTime.now(),
          targetBake: _plannedTargetBake,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: _isBaking
            ? Text(_pizzaType.config.displayName)
            : TextButton.icon(
                onPressed: _showPizzaTypeSelector,
                iconAlignment: IconAlignment.end,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  textStyle: theme.textTheme.titleLarge,
                ),
                icon: const Icon(Icons.arrow_drop_down),
                label: Text(_pizzaType.config.displayName),
              ),
        leading: (!_isBaking && _hasCustomSettings)
            ? IconButton(
                onPressed: _confirmReset,
                icon: const Icon(Icons.refresh),
                tooltip: 'Reset to defaults',
              )
            : null,
        actions: [
          IconButton(
            onPressed: _toggleWakelock,
            isSelected: _isScreenAwake,
            icon: const Icon(Icons.lightbulb_outline),
            selectedIcon: const Icon(Icons.lightbulb),
            tooltip: 'Keep screen on',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isBaking)
                BakeSummaryCard(
                  session: _session!,
                  schedule: schedule,
                  onStartOver: _confirmStartOver,
                  onBakeTimeTap: _showBakeTimePicker,
                )
              else
                DoughSettingsSection(
                  doughballs: _doughballs,
                  gramsPerBall: _gramsPerBall,
                  hydrationPercent: _hydrationPercent,
                  fermentationMode: _fermentationMode,
                  coldFermentDays: _coldFermentDays,
                  yeastType: _yeastType,
                  poolishAmount: _poolishAmount,
                  plannedTargetBake: _plannedTargetBake,
                  schedule: schedule,
                  onDoughballs: _updateDoughballs,
                  onDoughballsTap: _showDoughballsPicker,
                  onWeight: _updateWeight,
                  onWeightTap: _showWeightPicker,
                  onHydration: _updateHydration,
                  onHydrationTap: _showHydrationPicker,
                  onFermentationMode: _updateFermentationMode,
                  onColdFermentDays: _updateColdFermentDays,
                  onColdFermentDaysTap: _showColdFermentDaysPicker,
                  onBakeTimeTap: _showBakeTimePicker,
                  onYeastType: _updateYeastType,
                  onPoolishTap: _showPoolishCalculator,
                ),
              const SizedBox(height: AppSpacing.xl),
              IngredientsDisplay(
                ingredients: _ingredients,
                flourType: _pizzaType.config.flourType,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (issues.isNotEmpty) ...[
                BakeIssueBanner(
                  issues: issues,
                  onApplySuggestion: _moveBakeTime,
                  // Only offered while planning: the mode is part of the frozen
                  // recipe once a bake is under way.
                  onSwitchToColdFerment: _isBaking
                      ? null
                      : () => _updateFermentationMode(1),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (!_isBaking) ...[
                FilledButton(
                  onPressed: schedule.hasError ? null : _startBake,
                  child: Text(
                    // Not "Start bake": the final step is literally
                    // "Shape & bake", so that reads as "put it in now".
                    schedule.hasError
                        ? 'Not enough time to start'
                        : 'Start now',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              StepsChecklist(
                schedule: schedule,
                started: _isBaking,
                freezingNote: freezingNote(
                  _pizzaType,
                  isColdFerment: _fermentationMode == 1,
                ),
                onComplete: _completeStep,
                onUndo: _undoStep,
                onSetAlarm: _setPhoneAlarm,
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: TextButton(
                  onPressed: _showHawaiianPizzaToast,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: Text(
                    'Made by Rijad Spahic',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Input handlers ────────────────────────────────────────────

  void _updateDoughballs(int value) {
    setState(() => _doughballs = value);
    _saveSettings();
  }

  void _updateWeight(double value) {
    setState(() => _gramsPerBall = value);
    _saveSettings();
  }

  void _updateHydration(double value) {
    setState(() => _hydrationPercent = value);
    _saveSettings();
  }

  void _updateYeastType(int? yeastType) {
    if (yeastType == null) return;
    setState(() => _yeastType = yeastType);
    _saveSettings();
  }

  void _updateFermentationMode(int? mode) {
    if (mode == null) return;
    setState(() => _fermentationMode = mode);
    _saveSettings();
  }

  void _updateColdFermentDays(int days) {
    setState(() => _coldFermentDays = days);
    _saveSettings();
  }

  void _updatePizzaType(PizzaType pizzaType) {
    setState(() => _pizzaType = pizzaType);
    _persistPizzaType(pizzaType);
    _loadSavedSettings();
    Haptics.select();
  }

  Future<void> _confirmReset() async {
    Haptics.select();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset settings?'),
        content: Text(
          'Reset ${_pizzaType.config.displayName} back to its defaults.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _resetToDefaults();
  }

  Future<void> _resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _pizzaType.name;
    for (final suffix in const [
      'hydration',
      'doughballs',
      'gramsPerBall',
      'yeastType',
      'poolishAmount',
      'fermentationMode',
      'targetBakeHour',
      'targetBakeMinute',
      'coldFermentDays',
    ]) {
      await prefs.remove('${key}_$suffix');
    }
    if (!mounted) return;

    final config = _pizzaType.config;
    setState(() {
      _hydrationPercent = config.defaultHydration;
      _doughballs = config.defaultDoughballs;
      _gramsPerBall = config.defaultGramsPerBall;
      _yeastType = 1;
      _poolishAmount = 300.0;
      _fermentationMode = config.defaultFermentationMode;
      _targetBakeHour = 19;
      _targetBakeMinute = 0;
      _coldFermentDays = config.defaultColdFermentDays;
    });
  }

  Future<void> _toggleWakelock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      if (!(prefs.getBool('hasSeenWakelockExplanation') ?? false)) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keep screen on'),
            content: const Text(
              'Stops the screen sleeping while you make pizza. Useful when '
              'your hands are covered in flour.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        await prefs.setBool('hasSeenWakelockExplanation', true);
      }

      setState(() => _isScreenAwake = !_isScreenAwake);
      await WakelockPlus.toggle(enable: _isScreenAwake);
      await prefs.setBool('isScreenAwake', _isScreenAwake);
      Haptics.select();
    } catch (e) {
      debugPrint('Error handling wakelock toggle: $e');
    }
  }

  // ── Pickers and modals ────────────────────────────────────────

  /// No haptic here, the card that opens this already fires one.
  Future<void> _showBakeTimePicker() async {
    await TimeWheelPicker.show(
      context: context,
      initialTime: TimeOfDay(hour: _targetBakeHour, minute: _targetBakeMinute),
      onChanged: _applyBakeTime,
    );
  }

  void _applyBakeTime(TimeOfDay picked) {
    setState(() {
      _targetBakeHour = picked.hour;
      _targetBakeMinute = picked.minute;
      // Mid-bake this re-plans only what is left: the start and everything
      // already ticked off keep their real times.
      final session = _session;
      if (session != null) {
        final day = session.targetBake;
        _session = session.copyWith(
          targetBake: DateTime(
            day.year,
            day.month,
            day.day,
            picked.hour,
            picked.minute,
          ),
        );
      }
    });
    // Fire-and-forget, matching every other input handler here: the UI is
    // already correct and the write must not block the sheet closing.
    _saveSettings();
    if (_isBaking) {
      _persistSession();
      _syncAlarms();
    }
  }

  void _showColdFermentDaysPicker() {
    ValuePicker.show<int>(
      context: context,
      title: 'Days in fridge',
      items: List.generate(5, (index) => index + 1),
      initialValue: _coldFermentDays,
      onChanged: _updateColdFermentDays,
      displayBuilder: (value) => '$value ${value == 1 ? 'day' : 'days'}',
    );
  }

  void _showDoughballsPicker() {
    ValuePicker.show<int>(
      context: context,
      title: 'Doughballs',
      items: List.generate(50, (index) => index + 1),
      initialValue: _doughballs,
      onChanged: _updateDoughballs,
      displayBuilder: (value) => '$value',
    );
  }

  void _showWeightPicker() {
    ValuePicker.show<double>(
      context: context,
      title: 'Grams per ball',
      items: List.generate(86, (index) => 150.0 + (index * 10)),
      initialValue: _gramsPerBall,
      onChanged: _updateWeight,
      displayBuilder: (value) => '${value.round()}g',
    );
  }

  void _showHydrationPicker() {
    ValuePicker.show<double>(
      context: context,
      title: 'Hydration',
      items: List.generate(26, (index) => 55.0 + index),
      initialValue: _hydrationPercent,
      onChanged: _updateHydration,
      displayBuilder: (value) => '${value.round()}%',
    );
  }

  void _showPizzaTypeSelector() {
    Haptics.select();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final pizzaType in PizzaType.values)
              ListTile(
                title: Text(pizzaType.config.displayName),
                subtitle: Text(pizzaType.config.flourType),
                trailing: _pizzaType == pizzaType
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _updatePizzaType(pizzaType);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// No haptic here, the row that opens this already fires one.
  Future<void> _showPoolishCalculator() async {
    final result = await PoolishCalculator.show(
      context: context,
      initialAmount: _poolishAmount,
    );
    if (result == null || !mounted) return;
    setState(() => _poolishAmount = result);
    await _saveSettings();
  }

  void _showHawaiianPizzaToast() {
    Haptics.tick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🍕🍍 Hawaiian pizza da best')),
    );
  }
}
