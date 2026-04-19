import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:pizza_calc/widgets/picker_input.dart';

/// Poolish calculator modal component
class PoolishCalculator {
  static Future<double?> show({
    required BuildContext context,
    double initialAmount = 300.0,
  }) async {
    return await showCupertinoModalPopup<double?>(
      context: context,
      builder: (BuildContext context) {
        return _DraggablePoolishModal(initialAmount: initialAmount);
      },
    );
  }

  static Widget _buildIngredientRow(String name, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
          ),
          Text(
            '${amount.toStringAsFixed(1)}g',
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom draggable bottom sheet for poolish calculator
class _DraggablePoolishModal extends StatefulWidget {
  final double initialAmount;

  const _DraggablePoolishModal({required this.initialAmount});

  @override
  State<_DraggablePoolishModal> createState() => _DraggablePoolishModalState();
}

class _DraggablePoolishModalState extends State<_DraggablePoolishModal> {
  late double poolishAmount;
  double dragOffset = 0.0;
  final double poolishHydration = 100.0;
  final double poolishYeast = 0.1;

  @override
  void initState() {
    super.initState();
    poolishAmount = widget.initialAmount;
  }

  // Check if current settings differ from defaults
  bool get _hasCustomSettings {
    return poolishAmount != 300.0;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate poolish components
    final double poolishFlour = poolishAmount / (1 + poolishHydration / 100);
    final double poolishWater = poolishFlour * (poolishHydration / 100);
    final double poolishYeastAmount = poolishFlour * (poolishYeast / 100);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop(poolishAmount);
      },
      child: Container(
        color: CupertinoColors.black.withValues(alpha: 0.4),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {}, // Prevent dismissal when tapping content
          onPanUpdate: (details) {
            setState(() {
              dragOffset += details.delta.dy;
              dragOffset = dragOffset.clamp(0.0, 300.0);
            });
          },
          onPanEnd: (details) {
            if (dragOffset > 80 || details.velocity.pixelsPerSecond.dy > 300) {
              Navigator.of(context).pop(poolishAmount);
            } else {
              setState(() {
                dragOffset = 0.0;
              });
            }
          },
          child: Transform.translate(
            offset: Offset(0, dragOffset),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle and reset button row
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 12,
                      left: 8,
                      right: 8,
                      bottom: 0,
                    ),
                    child: SizedBox(
                      height: 28,
                      child: Stack(
                        children: [
                          // 1. The refresh button, shown conditionally on the far left
                          if (_hasCustomSettings)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: CupertinoButton(
                                  padding: EdgeInsets
                                      .zero,
                                  minimumSize: Size.zero,
                                  onPressed: () {
                                    setState(() {
                                      poolishAmount = 300.0;
                                    });
                                    HapticFeedback.mediumImpact();
                                  },
                                  child: const Icon(
                                    CupertinoIcons.refresh,
                                    color: CupertinoColors.systemBlue,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          // 2. The handle, always perfectly centered within the Stack
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3A3A3C),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Poolish Calculator',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Note about preparation timing
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: CupertinoColors.systemBlue.withOpacity(
                                0.3,
                              ),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                CupertinoIcons.info_circle,
                                color: CupertinoColors.systemBlue,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Poolish must be prepared 24 hours in advance',
                                  style: TextStyle(
                                    color: CupertinoColors.systemBlue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        PickerInput(
                          title: 'Poolish Amount',
                          value: '${poolishAmount.round()}g',
                          onTap: () {
                            final values = List.generate(
                              19,
                              (i) => (i + 2) * 50.0,
                            );
                            ValuePicker.show<double>(
                              context: context,
                              items: values,
                              initialValue: poolishAmount,
                              onChanged: (value) {
                                setState(() {
                                  poolishAmount = value;
                                });
                              },
                              displayBuilder: (value) => '${value.round()}g',
                            );
                          },
                          onDecrease: poolishAmount > 100
                              ? () {
                                  setState(() {
                                    poolishAmount = (poolishAmount - 50).clamp(
                                      100,
                                      1000,
                                    );
                                  });
                                  HapticFeedback.lightImpact();
                                }
                              : null,
                          onIncrease: poolishAmount < 1000
                              ? () {
                                  setState(() {
                                    poolishAmount = (poolishAmount + 50).clamp(
                                      100,
                                      1000,
                                    );
                                  });
                                  HapticFeedback.lightImpact();
                                }
                              : null,
                        ),

                        const SizedBox(height: 24),

                        // Poolish composition breakdown
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Poolish Composition',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              PoolishCalculator._buildIngredientRow(
                                'Flour',
                                poolishFlour,
                              ),
                              PoolishCalculator._buildIngredientRow(
                                'Water',
                                poolishWater,
                              ),
                              PoolishCalculator._buildIngredientRow(
                                'Yeast',
                                poolishYeastAmount,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Generic picker modal for selecting values
class ValuePicker<T> {
  static Future<void> show<T>({
    required BuildContext context,
    required List<T> items,
    required T initialValue,
    required ValueChanged<T> onChanged,
    required String Function(T) displayBuilder,
  }) async {
    int selectedIndex = items.indexOf(initialValue);
    if (selectedIndex == -1) selectedIndex = 0;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: const Color(0xFF1C1C1C),
          child: Column(
            children: [
              Container(
                height: 50,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                      },
                    ),
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onChanged(items[selectedIndex]);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: const Color(0xFF1C1C1C),
                  itemExtent: 32,
                  scrollController: FixedExtentScrollController(
                    initialItem: selectedIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    selectedIndex = index;
                    HapticFeedback.selectionClick();
                  },
                  children: items.map((T item) {
                    return Center(
                      child: Text(
                        displayBuilder(item),
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
