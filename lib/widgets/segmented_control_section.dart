import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Reusable segmented control section component
class SegmentedControlSection<T extends Object> extends StatelessWidget {
  final String title;
  final T groupValue;
  final Map<T, Widget> children;
  final ValueChanged<T?> onValueChanged;

  const SegmentedControlSection({
    super.key,
    required this.title,
    required this.groupValue,
    required this.children,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CupertinoSegmentedControl<T>(
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 2,
              ),
              children: children,
              onValueChanged: (T? value) {
                HapticFeedback.selectionClick();
                onValueChanged(value);
              },
              groupValue: groupValue,
              selectedColor: const Color(0x44FFFFFF),
              unselectedColor: const Color(0x00000000),
              borderColor: const Color(0x00000000),
              pressedColor: const Color(0x66FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}
