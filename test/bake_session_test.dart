// The session is what survives a restart, so the round trip through JSON is
// the thing worth pinning down, a decode bug would lose a bake in progress.

import 'package:flutter_test/flutter_test.dart';

import 'package:pizza_calc/models/bake_session.dart';
import 'package:pizza_calc/models/pizza_type.dart';
import 'package:pizza_calc/services/dough_calculator.dart';

void main() {
  final inputs = DoughInputs(
    pizzaType: PizzaType.newYork,
    doughballs: 6,
    gramsPerBall: 280.0,
    hydrationPercent: 65.0,
    yeastType: 2,
    poolishAmount: 400.0,
    fermentationMode: 1,
    coldFermentDays: 3,
    targetBakeHour: 18,
    targetBakeMinute: 30,
  );

  BakeSession sessionAt() => BakeSession(
    inputs: inputs,
    ingredients: const {'flour': 500.5, 'water': 320.25, 'poolish': 400.0},
    startedAt: DateTime(2026, 3, 10, 20, 15),
    targetBake: DateTime(2026, 3, 13, 18, 30),
    completed: {'mix': DateTime(2026, 3, 10, 20, 42)},
  );

  test('survives a round trip through JSON intact', () {
    final restored = BakeSession.decode(sessionAt().encode())!;

    expect(restored.inputs.pizzaType, PizzaType.newYork);
    expect(restored.inputs.doughballs, 6);
    expect(restored.inputs.gramsPerBall, 280.0);
    expect(restored.inputs.yeastType, 2);
    expect(restored.inputs.poolishAmount, 400.0);
    expect(restored.inputs.coldFermentDays, 3);
    expect(restored.startedAt, DateTime(2026, 3, 10, 20, 15));
    expect(restored.targetBake, DateTime(2026, 3, 13, 18, 30));
    expect(restored.completed['mix'], DateTime(2026, 3, 10, 20, 42));
    expect(restored.ingredients['flour'], 500.5);
  });

  test('frozen ingredients come back exactly, not recomputed', () {
    // The whole point of storing them: the numbers on screen must stay the
    // numbers that were weighed out, whatever the clock has done since.
    final restored = BakeSession.decode(sessionAt().encode())!;
    expect(restored.ingredients, sessionAt().ingredients);
  });

  test('completing a step leaves the original untouched', () {
    final original = sessionAt();
    final updated = original.completing('folds', DateTime(2026, 3, 10, 22));

    expect(original.completed.keys, ['mix']);
    expect(updated.completed.keys, containsAll(['mix', 'folds']));
  });

  test('a tick can be undone', () {
    final updated = sessionAt().uncompletingFrom('mix', const ['mix', 'folds']);
    expect(updated.completed, isEmpty);
  });

  group('undo cascades', () {
    const order = ['mix', 'bulk', 'ball', 'proof', 'bake'];

    BakeSession fourDone() => sessionAt().copyWith(
      completed: {
        'mix': DateTime(2026, 3, 10, 20, 42),
        'bulk': DateTime(2026, 3, 11, 4, 0),
        'ball': DateTime(2026, 3, 11, 4, 15),
        'proof': DateTime(2026, 3, 11, 6, 15),
      },
    );

    test('undoing a step also undoes everything after it', () {
      final undone = fourDone().uncompletingFrom('bulk', order);

      expect(undone.completed.keys, ['mix']);
    });

    test('undoing the first step clears the lot', () {
      expect(fourDone().uncompletingFrom('mix', order).completed, isEmpty);
    });

    test('undoing the last done step leaves the rest alone', () {
      final undone = fourDone().uncompletingFrom('proof', order);

      expect(undone.completed.keys, containsAll(['mix', 'bulk', 'ball']));
      expect(undone.completed.containsKey('proof'), isFalse);
    });

    // The bug the cascade exists to kill. Removing only the named step used to
    // leave the later timestamps in storage: they rendered as upcoming, then
    // snapped back to done carrying their *old* times as soon as the earlier
    // step was re-ticked. You cannot un-ferment dough, reopening a step
    // genuinely invalidates everything downstream of it.
    test('re-completing an undone step does not resurrect later steps', () {
      final reticked = fourDone()
          .uncompletingFrom('bulk', order)
          .completing('bulk', DateTime(2026, 3, 11, 5, 0));

      expect(reticked.completed.keys, containsAll(['mix', 'bulk']));
      expect(reticked.completed.containsKey('ball'), isFalse);
      expect(reticked.completed.containsKey('proof'), isFalse);
    });

    test('a step missing from the recipe order only undoes itself', () {
      final undone = fourDone().uncompletingFrom('ball', const ['mix', 'bulk']);

      expect(undone.completed.containsKey('ball'), isFalse);
      expect(undone.completed.keys, containsAll(['mix', 'bulk', 'proof']));
    });
  });

  test('changing the bake time keeps the start and the progress', () {
    final moved = sessionAt().copyWith(
      targetBake: DateTime(2026, 3, 13, 20),
    );
    expect(moved.startedAt, DateTime(2026, 3, 10, 20, 15));
    expect(moved.completed['mix'], DateTime(2026, 3, 10, 20, 42));
    expect(moved.targetBake, DateTime(2026, 3, 13, 20));
  });

  test('malformed or missing stored data decodes to null, never throws', () {
    expect(BakeSession.decode(null), isNull);
    expect(BakeSession.decode(''), isNull);
    expect(BakeSession.decode('not json'), isNull);
    expect(BakeSession.decode('{"inputs": {}}'), isNull);
    expect(BakeSession.decode('[]'), isNull);
  });

  test('an unknown pizza type falls back rather than failing to load', () {
    expect(PizzaType.fromName('deepDish'), PizzaType.neapolitan);
    expect(PizzaType.fromName(null), PizzaType.neapolitan);
    expect(PizzaType.fromName('roman'), PizzaType.roman);
  });
}
