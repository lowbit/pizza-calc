/// A labelled `SegmentedButton`.
///
/// Replaces `CupertinoSegmentedControl`, which was the iOS 12-era control and
/// had been left behind twice over, once by iOS, once by the move to Material.

library;

import 'package:flutter/material.dart';

import '../styles/app_theme.dart';
import '../utils/haptics.dart';
import 'app_scaffolding.dart';

class SegmentedControlSection<T extends Object> extends StatelessWidget {
  final String title;
  final T groupValue;

  /// Value to label, in display order.
  final Map<T, String> options;
  final ValueChanged<T?> onValueChanged;

  const SegmentedControlSection({
    super.key,
    required this.title,
    required this.groupValue,
    required this.options,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              // The tick takes space that the labels need on a narrow screen,
              // and the filled segment already shows what is selected.
              showSelectedIcon: false,
              segments: [
                for (final entry in options.entries)
                  ButtonSegment<T>(
                    value: entry.key,
                    label: Text(entry.value),
                  ),
              ],
              selected: {groupValue},
              onSelectionChanged: (selection) {
                Haptics.select();
                onValueChanged(selection.firstOrNull);
              },
            ),
          ),
        ],
      ),
    );
  }
}
