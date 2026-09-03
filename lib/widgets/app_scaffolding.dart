/// Small shared pieces that were previously copy-pasted around the app.
///
/// Before this existed there were 22 hand-rolled `Container` + `BoxDecoration`
/// surfaces, the instruction bullet list was written out three times, and the
/// Cancel/Done sheet header twice. Reach for these instead of drawing another.

library;

import 'package:flutter/material.dart';

import '../styles/app_theme.dart';
import '../utils/haptics.dart';

/// A padded surface. A thin wrapper over M3 `Card`. The point is to stop
/// hand-drawing surfaces, not to invent a private card system.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Every card gets an edge. The ground is dark enough that the tonal step
    // between `surface` and `surfaceContainer` is only 1.06:1, visible in a
    // swatch, invisible on a phone in a kitchen, so the hairline is what
    // actually separates a card from the page.
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      side: borderColor == null
          ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant)
          : BorderSide(color: borderColor!, width: 1.5),
    );

    return Card(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// A section heading, "Ingredients", "Steps", "Dough Settings".
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A one-line "label … value ›" row that opens a picker.
///
/// This shape was written out three times, bake time in the settings form,
/// poolish amount, bake time in the in-progress card, and had already started
/// drifting between them. One widget, so the next one is free.
class ValueRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const ValueRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        onTap: () {
          Haptics.select();
          onTap();
        },
      ),
    );
  }
}

/// The bulleted instruction list used by every step and the freezing note.
class InstructionList extends StatelessWidget {
  final List<String> instructions;

  /// Quieter styling for collapsed rows, where the text is reference rather
  /// than the thing you are doing right now.
  final bool muted;

  const InstructionList({
    super.key,
    required this.instructions,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = muted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in instructions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: AppSpacing.sm),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: muted
                          ? theme.colorScheme.outline
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Modal sheet chrome with a Cancel/Done header, wrapping a fixed-height body.
///
/// Used by the value wheels and the bake-time picker, which previously each
/// rebuilt this header by hand.
class PickerSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final double height;

  /// Called when Done is tapped, before the sheet closes. Cancel never calls
  /// it, that is what makes the sheet commit-on-confirm rather than live.
  final VoidCallback? onDone;

  const PickerSheet({
    super.key,
    this.title,
    required this.child,
    this.height = 280,
    this.onDone,
  });

  /// Shows [child] in a modal bottom sheet with the standard chrome.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    required Widget child,
    double height = 280,
    VoidCallback? onDone,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      // The wheel is a tall control; letting the sheet size itself keeps it
      // from being cramped on short screens.
      isScrollControlled: true,
      builder: (_) => PickerSheet(
        title: title,
        height: height,
        onDone: onDone,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Haptics.select();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                if (title != null)
                  Text(title!, style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: () {
                    Haptics.select();
                    onDone?.call();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}
