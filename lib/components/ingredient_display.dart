import 'package:flutter/cupertino.dart';

/// Individual ingredient row component
class IngredientRow extends StatelessWidget {
  final String name;
  final double amount;
  final String unit;
  final bool isLast;

  const IngredientRow({
    super.key,
    required this.name,
    required this.amount,
    required this.unit,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFF2C2C2E), width: 0.5),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.white,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(1)}$unit',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemBlue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Complete ingredients display section
class IngredientsDisplay extends StatelessWidget {
  final Map<String, double> ingredients;
  final String? flourType;

  const IngredientsDisplay({
    super.key, 
    required this.ingredients,
    this.flourType,
  });

  @override
  Widget build(BuildContext context) {
    // Build ingredient list based on what's available in the ingredients map
    final List<Map<String, String>> ingredientList = [];

    if (ingredients.containsKey('flour')) {
      ingredientList.add({
        'name': flourType != null ? 'Flour ($flourType)' : 'Flour', 
        'key': 'flour', 
        'unit': 'g'
      });
    }
    if (ingredients.containsKey('water')) {
      ingredientList.add({'name': 'Water', 'key': 'water', 'unit': 'g'});
    }
    if (ingredients.containsKey('salt')) {
      ingredientList.add({'name': 'Salt', 'key': 'salt', 'unit': 'g'});
    }
    if (ingredients.containsKey('sugar')) {
      ingredientList.add({'name': 'Sugar', 'key': 'sugar', 'unit': 'g'});
    }
    if (ingredients.containsKey('oil')) {
      ingredientList.add({'name': 'Olive Oil', 'key': 'oil', 'unit': 'g'});
    }
    if (ingredients.containsKey('yeast')) {
      ingredientList.add({'name': 'Yeast', 'key': 'yeast', 'unit': 'g'});
    }
    if (ingredients.containsKey('poolish')) {
      ingredientList.add({'name': 'Poolish', 'key': 'poolish', 'unit': 'g'});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingredients',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.white,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5),
          ),
          child: Column(
            children: ingredientList.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              final isLast = index == ingredientList.length - 1;

              return IngredientRow(
                name: ingredient['name'] as String,
                amount: ingredients[ingredient['key']] ?? 0.0,
                unit: ingredient['unit'] as String,
                isLast: isLast,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
