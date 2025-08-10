import 'package:flutter/cupertino.dart';
import 'package:pizza_calc/widgets/stepper_button.dart';

/// Reusable picker input widget for discrete values
class PickerInput extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const PickerInput({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
    this.onDecrease,
    this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromARGB(255, 46, 44, 44),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                StepperButton(
                  icon: CupertinoIcons.minus,
                  onPressed: onDecrease,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.systemBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                StepperButton(icon: CupertinoIcons.plus, onPressed: onIncrease),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
