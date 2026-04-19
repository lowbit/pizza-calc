import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Enhanced slider with visual markers and tap-to-pick functionality
class EnhancedSlider extends StatelessWidget {
  final String title;
  final double value;
  final String displayValue;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final VoidCallback onTap;
  final List<String> markers;

  const EnhancedSlider({
    super.key,
    required this.title,
    required this.value,
    required this.displayValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onTap,
    required this.markers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.white,
                  ),
                ),
                Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.systemBlue,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 12.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlider(
                      value: value,
                      min: min,
                      max: max,
                      divisions: divisions,
                      activeColor: CupertinoColors.systemBlue,
                      thumbColor: CupertinoColors.systemBlue,
                      onChanged: onChanged,
                    ),
                  ),
                ),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 4.0),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: markers.map((marker) {
                       String cleanMarker = marker
                           .replaceAll('%', '')
                           .replaceAll('x', '')
                           .trim();
                       final markerValue = double.parse(cleanMarker);
                       final isActive = (value - markerValue).abs() <= (value >= 10 ? 5 : 0.5);
                       return Text(
                         marker,
                         style: TextStyle(
                           fontSize: 12,
                           fontWeight: FontWeight.w500,
                           color: isActive
                               ? CupertinoColors.systemBlue
                               : const Color(0xFF8E8E93),
                         ),
                       );
                     }).toList(),
                   ),
                 ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
