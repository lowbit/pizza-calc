/// A bake that is actually under way.
///
/// This is the thing that was missing before: the app re-derived every time
/// from DateTime.now() on each rebuild, so touching any setting silently
/// restarted the timeline. A session pins the start, the target, the frozen
/// ingredient list and the real completion times, and it is persisted, so
/// closing the app or changing screens cannot move where you are.

library;

import 'dart:convert';

import '../services/dough_calculator.dart';

class BakeSession {
  /// Snapshot of the settings the dough was actually made with. Locked for the
  /// duration of the bake: you cannot re-weigh flour that is already mixed.
  final DoughInputs inputs;

  /// Ingredients frozen at the moment of starting, so the numbers on screen
  /// stay the numbers you weighed out.
  final Map<String, double> ingredients;

  /// When step one was begun. The anchor for the whole schedule.
  final DateTime startedAt;

  /// When the pizza should go in. Editable mid-bake, it re-plans the
  /// remaining steps without disturbing what is already done.
  final DateTime targetBake;

  /// Step id to the moment it was ticked off.
  final Map<String, DateTime> completed;

  const BakeSession({
    required this.inputs,
    required this.ingredients,
    required this.startedAt,
    required this.targetBake,
    this.completed = const {},
  });

  BakeSession copyWith({
    DateTime? targetBake,
    Map<String, DateTime>? completed,
  }) => BakeSession(
    inputs: inputs,
    ingredients: ingredients,
    startedAt: startedAt,
    targetBake: targetBake ?? this.targetBake,
    completed: completed ?? this.completed,
  );

  /// Mark a step finished at [at], keeping the map immutable.
  BakeSession completing(String stepId, DateTime at) => copyWith(
    completed: {...completed, stepId: at},
  );

  /// Undo [stepId] **and every step after it**, the obvious recovery from a
  /// mis-tap, and the reason completion is stored per step rather than as a
  /// simple counter. [orderedIds] is the recipe order, which the session does
  /// not otherwise know.
  ///
  /// The cascade is not a convenience. Progress is strictly sequential, so a
  /// timestamp on step 4 means nothing once step 2 is reopened. Removing only
  /// step 2 used to leave 3 and 4 stored: they rendered as upcoming, and then
  /// snapped back to done carrying their *old* times the moment step 2 was
  /// re-ticked. You cannot un-ferment dough, so reopening a step really does
  /// invalidate everything downstream of it.
  ///
  /// Ids in [completed] that are absent from [orderedIds] are left alone:
  /// they belong to a recipe this session is no longer following, and dropping
  /// them here would be a silent data loss rather than an undo.
  BakeSession uncompletingFrom(String stepId, List<String> orderedIds) {
    final from = orderedIds.indexOf(stepId);
    final doomed = from == -1
        ? {stepId}
        : orderedIds.sublist(from).toSet();
    return copyWith(
      completed: {
        for (final entry in completed.entries)
          if (!doomed.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'inputs': inputs.toJson(),
    'ingredients': ingredients,
    'startedAt': startedAt.toIso8601String(),
    'targetBake': targetBake.toIso8601String(),
    'completed': completed.map((k, v) => MapEntry(k, v.toIso8601String())),
  };

  factory BakeSession.fromJson(Map<String, dynamic> json) => BakeSession(
    inputs: DoughInputs.fromJson(json['inputs'] as Map<String, dynamic>),
    ingredients: (json['ingredients'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    ),
    startedAt: DateTime.parse(json['startedAt'] as String),
    targetBake: DateTime.parse(json['targetBake'] as String),
    completed: (json['completed'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, DateTime.parse(v as String)),
    ),
  );

  String encode() => jsonEncode(toJson());

  /// Returns null rather than throwing on malformed or outdated stored data:
  /// a corrupt session should drop you back to the calculator, not crash.
  static BakeSession? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return BakeSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
