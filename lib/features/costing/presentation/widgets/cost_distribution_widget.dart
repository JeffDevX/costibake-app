import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/cost_breakdown.dart';

/// Visual distribution widget (progress bar & legend) displaying the percentage
/// allocation across ingredients, sub-recipes, packaging, labor, and overhead (JEF-15).
class CostDistributionWidget extends StatelessWidget {
  final CostBreakdown breakdown;
  final String currencySymbol;

  const CostDistributionWidget({
    super.key,
    required this.breakdown,
    this.currencySymbol = r'$',
  });

  static const Color ingredientsColor = AppColors.primaryCaramel;
  static const Color subRecipesColor = AppColors.primaryDarkCaramel;
  static const Color packagingColor = Color(0xFF2E7D32);
  static const Color laborColor = AppColors.honeyAccent;
  static const Color overheadColor = Color(0xFF6B7280); // Cool Grey

  @override
  Widget build(BuildContext context) {
    final ingPct = breakdown.ingredientsPercentage;
    final subPct = breakdown.subRecipesPercentage;
    final packPct = breakdown.packagingPercentage;
    final laborPct = breakdown.laborPercentage;
    final ohPct = breakdown.overheadPercentage;

    final hasCost = breakdown.totalProductionCost.toDouble() > 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      color: AppColors.butterCream,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Distribución de Costos (CTP)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$currencySymbol${breakdown.totalProductionCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDarkCaramel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segmented Distribution Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: hasCost
                    ? Row(
                        children: [
                          if (ingPct > 0)
                            Expanded(
                              flex: (ingPct * 10).round().clamp(1, 1000),
                              child: Container(color: ingredientsColor),
                            ),
                          if (subPct > 0)
                            Expanded(
                              flex: (subPct * 10).round().clamp(1, 1000),
                              child: Container(color: subRecipesColor),
                            ),
                          if (packPct > 0)
                            Expanded(
                              flex: (packPct * 10).round().clamp(1, 1000),
                              child: Container(color: packagingColor),
                            ),
                          if (laborPct > 0)
                            Expanded(
                              flex: (laborPct * 10).round().clamp(1, 1000),
                              child: Container(color: laborColor),
                            ),
                          if (ohPct > 0)
                            Expanded(
                              flex: (ohPct * 10).round().clamp(1, 1000),
                              child: Container(color: overheadColor),
                            ),
                        ],
                      )
                    : Container(color: AppColors.borderSubtle),
              ),
            ),
            const SizedBox(height: 14),

            // Legend Items
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildLegendItem(
                  color: ingredientsColor,
                  label: 'Insumos',
                  amount: breakdown.rawMaterialsCost.toStringAsFixed(2),
                  percentage: ingPct,
                ),
                if (breakdown.subRecipesCost.toDouble() > 0)
                  _buildLegendItem(
                    color: subRecipesColor,
                    label: 'Sub-recetas',
                    amount: breakdown.subRecipesCost.toStringAsFixed(2),
                    percentage: subPct,
                  ),
                _buildLegendItem(
                  color: packagingColor,
                  label: 'Empaques',
                  amount: breakdown.packagingCost.toStringAsFixed(2),
                  percentage: packPct,
                ),
                _buildLegendItem(
                  color: laborColor,
                  label: 'Mano de Obra',
                  amount: breakdown.laborCost.toStringAsFixed(2),
                  percentage: laborPct,
                ),
                _buildLegendItem(
                  color: overheadColor,
                  label: 'Overhead (${breakdown.effectiveOverheadPercentage.toStringAsFixed(1)}%)',
                  amount: breakdown.overheadCost.toStringAsFixed(2),
                  percentage: ohPct,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String amount,
    required double percentage,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$label: $currencySymbol$amount (${percentage.toStringAsFixed(1)}%)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textEspresso,
            ),
          ),
        ),
      ],
    );
  }
}
