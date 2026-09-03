/// An hour/minute wheel, for picking the bake time.
///
/// Replaces `showTimePicker`. Material's clock dial is a perfectly good
/// control, but it was the *only* picker in the app that wasn't a wheel:
/// doughballs, grams per ball, days in the fridge and the poolish amount all
/// spin. Bake time is the one you change most often, so it was also the one
/// place the app contradicted itself.
///
/// Minutes run the full 0–59 rather than in fives. Coarser steps would be
/// quicker to spin, but they would also silently round a stored 19:37 down on
/// first open, and a picker that edits a value just by being looked at is a
/// worse trade than a slightly longer scroll.
///
/// Commits on Done, like [ValuePicker], spinning past a time should not
/// re-plan the whole schedule twenty times on the way.

library;

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';

import '../styles/app_theme.dart';
import '../utils/haptics.dart';
import 'app_scaffolding.dart';

abstract final class TimeWheelPicker {
  static Future<void> show({
    required BuildContext context,
    required TimeOfDay initialTime,
    required ValueChanged<TimeOfDay> onChanged,
    String title = 'Bake at',
  }) async {
    var hour = initialTime.hour;
    var minute = initialTime.minute;

    await PickerSheet.show<void>(
      context: context,
      title: title,
      height: 220,
      onDone: () => onChanged(TimeOfDay(hour: hour, minute: minute)),
      child: Row(
        children: [
          Expanded(
            child: _Wheel(
              count: 24,
              initialItem: initialTime.hour,
              onSelected: (value) => hour = value,
              alignment: Alignment.centerRight,
              // Square on the inside edge so the two halves read as one
              // selection band with the colon sitting in it, rather than as
              // two pills with a gap between them.
              radius: const BorderRadius.horizontal(
                left: Radius.circular(AppRadius.small),
              ),
            ),
          ),
          const _Colon(),
          Expanded(
            child: _Wheel(
              count: 60,
              initialItem: initialTime.minute,
              onSelected: (value) => minute = value,
              alignment: Alignment.centerLeft,
              radius: const BorderRadius.horizontal(
                right: Radius.circular(AppRadius.small),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  final int count;
  final int initialItem;
  final ValueChanged<int> onSelected;
  final Alignment alignment;
  final BorderRadius radius;

  const _Wheel({
    required this.count,
    required this.initialItem,
    required this.onSelected,
    required this.alignment,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CupertinoPicker(
      backgroundColor: Colors.transparent,
      itemExtent: 40,
      squeeze: 1.1,
      // Each wheel paints its own half of the band; together with the squared
      // inside edges they read as one.
      selectionOverlay: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: radius,
        ),
      ),
      scrollController: FixedExtentScrollController(initialItem: initialItem),
      onSelectedItemChanged: (index) {
        onSelected(index);
        Haptics.tick();
      },
      children: [
        for (var i = 0; i < count; i++)
          Container(
            alignment: alignment,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              i.toString().padLeft(2, '0'),
              style: theme.textTheme.titleLarge,
            ),
          ),
      ],
    );
  }
}

class _Colon extends StatelessWidget {
  const _Colon();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      ':',
      style: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
