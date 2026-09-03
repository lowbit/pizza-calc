// On-device tests of the main flows. Run against a booted emulator with:
//
//   adb -s emulator-5554 shell pm grant com.example.pizza_calc \
//       android.permission.POST_NOTIFICATIONS
//   flutter test integration_test -d emulator-5554
//
// Granting the notification permission up front matters: starting a bake asks
// for it, and an ungranted permission puts a system dialog over the app that
// the test cannot dismiss.
//
// These drive the real app against the real SharedPreferences plugin, so they
// cover the persistence path that a plain widget test cannot. Widgets are
// located by type and text rather than screen coordinates, so the tests survive
// layout changes.
//
// Exact gram values are deliberately not asserted: yeast is derived from the
// time remaining until the bake hour, so most figures move with the wall clock.
// What is stable is that the ingredients always total doughballs x gramsPerBall,
// and that changes push values in a known direction.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pizza_calc/components/ingredient_display.dart';
import 'package:pizza_calc/main.dart';
import 'package:pizza_calc/widgets/picker_input.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Start every test from a genuine first-run state, with no bake running.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  Future<void> launchApp(WidgetTester tester) async {
    await tester.pumpWidget(const PizzaCalculatorApp());
    await tester.pumpAndSettle();
  }

  /// Tear the app down and mount it again, the closest thing to a cold start
  /// from inside a test. SharedPreferences survives, widget state does not.
  Future<void> relaunchApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await launchApp(tester);
  }

  Iterable<IngredientRow> rows(WidgetTester tester) =>
      tester.widgetList<IngredientRow>(find.byType(IngredientRow));

  double totalGrams(WidgetTester tester) =>
      rows(tester).fold<double>(0.0, (sum, row) => sum + row.amount);

  double amountOf(WidgetTester tester, String name) =>
      rows(tester).firstWhere((row) => row.name == name).amount;

  bool hasRow(WidgetTester tester, String name) =>
      rows(tester).any((row) => row.name == name);

  /// Read the value shown on a picker card by its title. Reading the widget is
  /// necessary rather than find.text('5'): the checklist renders numbered step
  /// badges, so any bare digit matches in more than one place.
  String pickerValue(WidgetTester tester, String title) => tester
      .widgetList<PickerInput>(find.byType(PickerInput))
      .firstWhere((picker) => picker.title == title)
      .value;

  /// Scroll [finder] into range, then tap it.
  Future<void> tapItem(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) =>
      tapItem(tester, find.text(text));

  /// Complete the current step, confirming the early-finish dialog if it
  /// appears.
  ///
  /// A test ticks every step within seconds, so the ferments and proofs are
  /// always "rushed" here. That is the dialog working, not a broken test, so
  /// these flows answer it rather than avoid it. Pass [label] 'Finish' for the
  /// last step, which is worded differently.
  Future<void> markDone(WidgetTester tester, [String label = 'Mark done']) async {
    await tapText(tester, label);
    if (find.text('Not yet').evaluate().isNotEmpty) {
      await tester.tap(find.text('Mark done').last);
      await tester.pumpAndSettle();
    }
  }

  /// Tap the +/- stepper belonging to the picker card titled [title].
  Future<void> tapStepper(
    WidgetTester tester,
    String title, {
    required bool increase,
  }) async {
    final card = find.ancestor(
      of: find.text(title),
      matching: find.byType(PickerInput),
    );
    await tapItem(
      tester,
      find.descendant(
        of: card,
        matching: find.byIcon(
          increase ? Icons.add : Icons.remove,
        ),
      ),
    );
  }

  /// Pick a pizza style from the nav-bar action sheet.
  Future<void> selectPizzaType(
    WidgetTester tester,
    String current,
    String next,
  ) async {
    await tapText(tester, current);
    await tester.tap(find.text(next).last);
    await tester.pumpAndSettle();
  }

  group('planning', () {
    testWidgets('starts on Neapolitan defaults', (tester) async {
      await launchApp(tester);

      expect(find.text('Neapolitan'), findsOneWidget);
      expect(find.text('250g'), findsOneWidget);
      expect(find.text('62%'), findsOneWidget);

      expect(hasRow(tester, 'Flour (00)'), isTrue);
      expect(hasRow(tester, 'Sugar'), isFalse);
      expect(hasRow(tester, 'Olive Oil'), isFalse);

      expect(totalGrams(tester), closeTo(4 * 250.0, 0.05));
    });

    testWidgets('the checklist is on show without opening anything', (
      tester,
    ) async {
      await launchApp(tester);

      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('Mix the dough'), findsOneWidget);
      expect(find.text('Shape & bake'), findsOneWidget);
      expect(find.text('Freezing (optional)'), findsOneWidget);
    });

    testWidgets('dough weight tracks the doughball count', (tester) async {
      await launchApp(tester);
      expect(totalGrams(tester), closeTo(1000.0, 0.05));

      await tapStepper(tester, 'Doughballs', increase: true);
      await tapStepper(tester, 'Doughballs', increase: true);

      expect(pickerValue(tester, 'Doughballs'), '6');
      expect(totalGrams(tester), closeTo(6 * 250.0, 0.05));
    });

    testWidgets('a longer ferment calls for less yeast', (tester) async {
      await launchApp(tester);
      final sameDayYeast = amountOf(tester, 'Yeast');

      await tapText(tester, 'Cold ferment');

      expect(find.text('Days in fridge'), findsOneWidget);
      expect(amountOf(tester, 'Yeast'), lessThan(sameDayYeast));
      expect(totalGrams(tester), closeTo(1000.0, 0.05));
      // The cold-ferment recipe is a different set of steps. Asserted on a
      // step unique to it rather than on 'Cold ferment', which now matches
      // both the segment label and the fridge step itself.
      expect(find.text('Stretch & folds, then fridge'), findsOneWidget);
    });

    testWidgets('each pizza type loads its own defaults', (tester) async {
      await launchApp(tester);
      await selectPizzaType(tester, 'Neapolitan', 'New York');

      expect(find.text('New York'), findsOneWidget);
      expect(find.text('300g'), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);
      expect(find.text('Days in fridge'), findsOneWidget);
      expect(hasRow(tester, 'Flour (Bread Flour)'), isTrue);
      expect(hasRow(tester, 'Sugar'), isTrue);
      expect(hasRow(tester, 'Olive Oil'), isTrue);

      expect(totalGrams(tester), closeTo(4 * 300.0, 0.05));
    });

    testWidgets('poolish replaces the yeast row and supplies flour and water', (
      tester,
    ) async {
      await launchApp(tester);
      final directFlour = amountOf(tester, 'Flour (00)');

      await tapText(tester, 'Poolish');

      expect(hasRow(tester, 'Yeast'), isFalse);
      expect(amountOf(tester, 'Poolish'), closeTo(300.0, 0.05));
      expect(amountOf(tester, 'Flour (00)'), lessThan(directFlour));
      expect(totalGrams(tester), closeTo(1000.0, 0.05));
    });

    testWidgets('settings and pizza type survive a relaunch', (tester) async {
      await launchApp(tester);

      await tapStepper(tester, 'Doughballs', increase: true);
      await tapText(tester, 'Cold ferment');
      await selectPizzaType(tester, 'Neapolitan', 'New York');
      await tapStepper(tester, 'Days in fridge', increase: true);

      await relaunchApp(tester);

      // Comes back on New York, not the Neapolitan the app hardcodes as its
      // initial field value, the regression guard for the missing initState
      // that made every saved setting unreadable on a cold start.
      expect(find.text('New York'), findsOneWidget);
      expect(pickerValue(tester, 'Days in fridge'), '3 days');

      // ...and the Neapolitan edits are still filed under Neapolitan.
      await selectPizzaType(tester, 'New York', 'Neapolitan');
      expect(pickerValue(tester, 'Doughballs'), '5');
      expect(find.text('Days in fridge'), findsOneWidget);
    });

    testWidgets('reset restores the defaults for the current type', (
      tester,
    ) async {
      await launchApp(tester);

      await tapStepper(tester, 'Doughballs', increase: true);
      expect(pickerValue(tester, 'Doughballs'), '5');

      final resetButton = find.byIcon(Icons.refresh);
      expect(resetButton, findsOneWidget);
      await tapItem(tester, resetButton);
      await tapText(tester, 'Reset');

      expect(pickerValue(tester, 'Doughballs'), '4');
      expect(totalGrams(tester), closeTo(1000.0, 0.05));
      expect(find.byIcon(Icons.refresh), findsNothing);
    });
  });

  group('a bake in progress', () {
    testWidgets('starting locks the recipe and begins tracking', (
      tester,
    ) async {
      await launchApp(tester);
      final plannedTotal = totalGrams(tester);

      await tapText(tester, 'Start now');

      expect(find.text('Bake in progress'), findsOneWidget);
      expect(find.text('Dough'), findsNothing);
      expect(find.text('Start now'), findsNothing);
      expect(find.text('0 of 5'), findsOneWidget);
      // Exactly one step is actionable at a time.
      expect(find.text('Mark done'), findsOneWidget);
      // Ingredients are frozen, not recomputed.
      expect(totalGrams(tester), closeTo(plannedTotal, 0.05));
    });

    testWidgets('only the current step is expanded', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'Start now');

      // Step one's instructions are on show...
      expect(find.text('Dissolve the yeast in the water.'), findsOneWidget);
      // ...and the next step stays collapsed to a single line.
      expect(
        find.text(
          'Shape into a rough ball, place in a lightly oiled bowl, and cover.',
        ),
        findsNothing,
      );
    });

    testWidgets('marking done records it and moves focus on', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'Start now');

      await markDone(tester);

      expect(find.text('1 of 5'), findsOneWidget);
      // The finished step collapses to a dim row carrying a tick.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Dissolve the yeast in the water.'), findsNothing);
      // The next step is now the expanded, actionable one.
      expect(
        find.text(
          'Shape into a rough ball, place in a lightly oiled bowl, and cover.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tick can be undone', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'Start now');

      await markDone(tester);
      expect(find.text('1 of 5'), findsOneWidget);

      // Undo sits behind two taps: finished steps fold into a summary row,
      // and the row inside it has to be opened before it can be un-ticked.
      // Neither can be undone by brushing past the list.
      expect(find.text('Undo'), findsNothing);
      expect(find.text('Mix the dough'), findsNothing);
      await tapText(tester, '1 step done');
      await tapText(tester, 'Mix the dough');
      await tapText(tester, 'Undo');

      expect(find.text('0 of 5'), findsOneWidget);
    });

    testWidgets('undoing a step also undoes the ones after it', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'Start now');

      await markDone(tester);
      await markDone(tester);
      await markDone(tester);
      expect(find.text('3 of 5'), findsOneWidget);

      // Reopen step two. Progress is sequential, so steps three and four are
      // meaningless once it is reopened, and leaving them stored used to make
      // them reappear, with their old times, the moment step two was re-ticked.
      await tapText(tester, '3 steps done');
      await tapText(tester, 'Mix the dough');
      await tapText(tester, 'Undo');

      expect(find.text('0 of 5'), findsOneWidget);
    });

    testWidgets('finishing the last step reports the bake complete', (
      tester,
    ) async {
      await launchApp(tester);
      await tapText(tester, 'Start now');

      // Four "Mark done"s and a "Finish". The last step is worded differently
      // because it is the one that ends the bake.
      for (var i = 0; i < 4; i++) {
        await markDone(tester);
      }
      await markDone(tester, 'Finish');

      expect(find.text('Bake complete'), findsOneWidget);
      expect(find.text('Bake in progress'), findsNothing);
      expect(find.text('All done'), findsOneWidget);
      // Every step is behind the summary row now, so nothing is actionable.
      expect(find.text('Mark done'), findsNothing);
      expect(find.text('5 steps done'), findsOneWidget);

      // Clearing a finished bake skips the confirm dialog, there is nothing
      // left to lose.
      await tapText(tester, 'Start a new bake');
      expect(find.text('Start now'), findsOneWidget);
      expect(find.text('Bake complete'), findsNothing);
    });

    testWidgets('the bake in progress survives a relaunch', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'Start now');
      await markDone(tester);
      expect(find.text('1 of 5'), findsOneWidget);

      await relaunchApp(tester);

      // This is the whole point of the feature: closing the app must not lose
      // where you are, and must not restart the timeline.
      expect(find.text('Bake in progress'), findsOneWidget);
      expect(find.text('1 of 5'), findsOneWidget);
      expect(find.text('Dough'), findsNothing);
    });

    testWidgets('starting over returns to planning', (tester) async {
      await launchApp(tester);
      await tapText(tester, 'Start now');
      expect(find.text('Bake in progress'), findsOneWidget);

      await tapText(tester, 'Discard this bake');
      await tapItem(tester, find.text('Discard').last);

      expect(find.text('Dough'), findsOneWidget);
      expect(find.text('Start now'), findsOneWidget);
      expect(find.text('Bake in progress'), findsNothing);

      // And it stays gone across a relaunch.
      await relaunchApp(tester);
      expect(find.text('Start now'), findsOneWidget);
    });
  });
}
