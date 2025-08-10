import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Reusable stepper button component
class StepperButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const StepperButton({super.key, required this.icon, this.onPressed});

  @override
  State<StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<StepperButton> {
  bool _isPressed = false;
  bool _isAnimating = false;

  void _handleTapDown() {
    if (!_isAnimating) {
      setState(() {
        _isPressed = true;
        _isAnimating = true;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp() {
    // Ensure minimum visual feedback duration
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {
          _isPressed = false;
          _isAnimating = false;
        });
      }
    });
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _handleTapDown() : null,
      onTapUp: isEnabled ? (_) => _handleTapUp() : null,
      onTapCancel: isEnabled ? () => _handleTapCancel() : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isEnabled
              ? (_isPressed
                    ? CupertinoColors.systemBlue.withOpacity(0.8)
                    : const Color(0xFF2C2C2E))
              : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(10),
          border: isEnabled
              ? Border.all(
                  color: _isPressed
                      ? CupertinoColors.systemBlue
                      : const Color(0xFF3A3A3C),
                  width: 1.0,
                )
              : Border.all(color: const Color(0xFF2C2C2E), width: 1.0),
        ),
        child: Icon(
          widget.icon,
          size: 18,
          color: isEnabled
              ? (_isPressed ? CupertinoColors.white : const Color(0xFFE5E5E7))
              : const Color(0xFF636366),
        ),
      ),
    );
  }
}
