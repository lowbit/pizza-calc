// Widget tests for the pizza calculator screen.
//
// These assert structure and the baker's-percentage invariant, not exact gram
// values: the yeast amount depends on the time remaining until the bake hour,
// so most individual figures move with the wall clock. The total, however, is
// always doughballs x gramsPerBall, which is the useful thing to lock down.
//
// The dough maths and the scheduler have their own unit tests; this file is
// only about what the screen renders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pizza_calc/components/ingredient_display.dart';
import 'package:pizza_calc/main.dart';

void main() {
  setUp(() {
    // The screen restores saved settings and any bake in progress in
    // initState, so the plugin has to be stubbed or SharedPreferences throws
    // MissingPluginException.
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(const PizzaCalculatorApp());
    await tester.pumpAndSettle();
  }

  Future<void> startBake(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Start now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start now'));
    await tester.pumpAndSettle();
  }

  testWidgets('loads with Neapolitan defaults', (WidgetTester tester) async {
    await launch(tester);

    expect(find.text('Neapolitan'), findsOneWidget);
    expect(find.text('Dough'), findsOneWidget);
    expect(find.text('Ingredients'), findsOneWidget);

    // Default inputs for Neapolitan: 4 balls x 250 g at 62% hydration.
    expect(find.text('Doughballs'), findsOneWidget);
    expect(find.text('250g'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);

    // Neapolitan uses 00 flour and has no sugar or oil.
    expect(find.text('Flour (00)'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Salt'), findsOneWidget);
    expect(find.text('Yeast'), findsOneWidget);
    expect(find.text('Sugar'), findsNothing);
    expect(find.text('Olive Oil'), findsNothing);
  });

  testWidgets('ingredients total the requested dough weight', (
    WidgetTester tester,
  ) async {
    await launch(tester);

    final rows = tester.widgetList<IngredientRow>(find.byType(IngredientRow));
    expect(rows, isNotEmpty);

    final total = rows.fold<double>(0.0, (sum, row) => sum + row.amount);
    expect(total, closeTo(4 * 250.0, 0.01));
  });

  testWidgets('the checklist is visible without having to open anything', (
    WidgetTester tester,
  ) async {
    await launch(tester);

    // The steps used to hide behind a dropdown. They are now always on show.
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Mix the dough'), findsOneWidget);
    expect(find.text('Bulk ferment with stretch & folds'), findsOneWidget);
    expect(find.text('Shape & bake'), findsOneWidget);
  });

  testWidgets('freezing is offered as a note, not a checklist step', (
    WidgetTester tester,
  ) async {
    await launch(tester);

    expect(find.text('Freezing (optional)'), findsOneWidget);
    // Collapsed until asked for, and it carries no schedule time.
    expect(
      find.text('Freeze for up to 3 months (best quality within 4–6 weeks).'),
      findsNothing,
    );
  });

  testWidgets('a plan offers to start and cannot be ticked off yet', (
    WidgetTester tester,
  ) async {
    await launch(tester);

    expect(find.text('Start now'), findsOneWidget);
    expect(find.text('Bake in progress'), findsNothing);
    // Nothing is done, and there is no way to tick anything until you start.
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.text('Mark done'), findsNothing);
  });

  testWidgets('starting a bake locks the recipe and enables ticking', (
    WidgetTester tester,
  ) async {
    await launch(tester);

    await tester.ensureVisible(find.text('Start now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start now'));
    await tester.pumpAndSettle();

    // The editable settings give way to a locked summary.
    expect(find.text('Bake in progress'), findsOneWidget);
    expect(find.text('Dough'), findsNothing);
    expect(find.text('Start now'), findsNothing);
    expect(find.text('Discard this bake'), findsOneWidget);

    // Progress is now tracked, and exactly one step is actionable.
    expect(find.text('0 of 5'), findsOneWidget);
    expect(find.text('Mark done'), findsOneWidget);
  });

  testWidgets('only the current step is expanded and actionable', (
    WidgetTester tester,
  ) async {
    await launch(tester);
    await startBake(tester);

    // Step one's instructions are on show...
    expect(find.text('Dissolve the yeast in the water.'), findsOneWidget);
    // ...while the step after it stays collapsed to a single line.
    expect(
      find.text('Shape into a rough ball, place in a lightly oiled bowl, and cover.'),
      findsNothing,
    );
  });

  testWidgets('marking done records the step and moves focus on', (
    WidgetTester tester,
  ) async {
    await launch(tester);
    await startBake(tester);

    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();

    expect(find.text('1 of 5'), findsOneWidget);
    // The finished step collapses to a dim row with a tick...
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Dissolve the yeast in the water.'), findsNothing);
    // ...and the next step is now the expanded, actionable one.
    expect(
      find.text('Shape into a rough ball, place in a lightly oiled bowl, and cover.'),
      findsOneWidget,
    );
    expect(find.text('Mark done'), findsOneWidget);
  });

  testWidgets('finishing a ferment far too early asks first', (
    WidgetTester tester,
  ) async {
    await launch(tester);
    await startBake(tester);

    // Mixing is a work step: ticking it instantly is normal and must not ask.
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();
    expect(find.text('Not yet'), findsNothing);
    expect(find.text('1 of 5'), findsOneWidget);

    // The bulk ferment is the dough's time, not the baker's, so ticking it
    // seconds in does ask.
    await tester.ensureVisible(find.text('Mark done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();

    expect(find.text('Not yet'), findsOneWidget);

    // Backing out leaves the step exactly as it was, with no timestamp.
    await tester.tap(find.text('Not yet'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 5'), findsOneWidget);

    // Confirming goes through, because the baker is the judge.
    await tester.ensureVisible(find.text('Mark done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark done').last);
    await tester.pumpAndSettle();

    expect(find.text('2 of 5'), findsOneWidget);
  });

  testWidgets('a finished step can be reopened and undone', (
    WidgetTester tester,
  ) async {
    await launch(tester);
    await startBake(tester);

    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 5'), findsOneWidget);

    // Undo is deliberately behind two taps now: finished steps fold away into
    // a summary row, and the row itself has to be opened before it can be
    // un-ticked. Neither the group nor the row can be undone by brushing past.
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Mix the dough'), findsNothing);

    await tester.ensureVisible(find.text('1 step done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 step done'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Mix the dough'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix the dough'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('0 of 5'), findsOneWidget);
  });
}
