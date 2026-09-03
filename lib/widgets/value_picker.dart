/// A scroll-wheel picker for discrete values.
///
/// Deliberately the one Cupertino survivor. Material has no wheel, and for
/// picking one of fifty doughball counts a wheel beats a long scrolling list by
/// a wide margin. It is wrapped in Material sheet chrome so it does not look
/// like a foreign object.
///
/// Commits on Done rather than live: spinning past a value should not keep
/// re-triggering a recalculation and a save.
///
/// Previously buried at the bottom of `poolish_calculator.dart`, which is why
/// it was hard to find and impossible to reuse without importing the poolish
/// feature.

library;

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';

import '../styles/app_theme.dart';
import '../utils/haptics.dart';
import 'app_scaffolding.dart';

class ValuePicker<T> {
  static Future<void> show<T>({
    required BuildContext context,
    required List<T> items,
    required T initialValue,
    required ValueChanged<T> onChanged,
    required String Function(T) displayBuilder,
    String? title,
  }) async {
    var selectedIndex = items.indexOf(initialValue);
    if (selectedIndex == -1) selectedIndex = 0;

    final theme = Theme.of(context);

    await PickerSheet.show<void>(
      context: context,
      title: title,
      height: 220,
      onDone: () => onChanged(items[selectedIndex]),
      child: CupertinoPicker(
        backgroundColor: Colors.transparent,
        itemExtent: 40,
        squeeze: 1.1,
        selectionOverlay: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
        ),
        scrollController: FixedExtentScrollController(
          initialItem: selectedIndex,
        ),
        onSelectedItemChanged: (index) {
          selectedIndex = index;
          Haptics.tick();
        },
        children: [
          for (final item in items)
            Center(
              child: Text(
                displayBuilder(item),
                style: theme.textTheme.titleMedium,
              ),
            ),
        ],
      ),
    );
  }
}
