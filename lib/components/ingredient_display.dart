/// The ingredients card.
///
/// Rows are driven by which keys exist in the map, which is how poolish makes
/// the yeast row disappear and sugar/oil appear only for the styles that use
/// them.

library;

import 'package:flutter/material.dart';

import '../styles/app_theme.dart';
import '../widgets/app_scaffolding.dart';

/// One ingredient. Kept as a public widget because the tests sum across these
/// to assert the recipe totals the requested dough weight.
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
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: theme.textTheme.bodyLarge),
              Text(
                '${amount.toStringAsFixed(1)}$unit',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: AppSpacing.md),
      ],
    );
  }
}

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
    // Order is fixed and meaningful: it is the order you weigh them out in.
    final rows = <({String name, String key})>[
      if (ingredients.containsKey('flour'))
        (name: flourType != null ? 'Flour ($flourType)' : 'Flour', key: 'flour'),
      if (ingredients.containsKey('water')) (name: 'Water', key: 'water'),
      if (ingredients.containsKey('salt')) (name: 'Salt', key: 'salt'),
      if (ingredients.containsKey('sugar')) (name: 'Sugar', key: 'sugar'),
      if (ingredients.containsKey('oil')) (name: 'Olive Oil', key: 'oil'),
      if (ingredients.containsKey('yeast')) (name: 'Yeast', key: 'yeast'),
      if (ingredients.containsKey('poolish')) (name: 'Poolish', key: 'poolish'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Ingredients'),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                IngredientRow(
                  name: rows[i].name,
                  amount: ingredients[rows[i].key] ?? 0.0,
                  unit: 'g',
                  isLast: i == rows.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
