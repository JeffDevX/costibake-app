import '../../../../core/utils/precise_decimal.dart';
import '../../../recipes/domain/entities/recipe.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../entities/cost_breakdown.dart';

/// Domain service calculating precise financial breakdown for a bakery recipe.
class CostCalculator {
  /// Calculates the complete quad-component cost and dual pricing breakdown
  static CostBreakdown calculate({
    required Recipe recipe,
    required BusinessConfig config,
  }) {
    // 1. Raw Materials (Insumos)
    PreciseDecimal rawMaterialsCost = PreciseDecimal.zero;
    for (final item in recipe.ingredients) {
      rawMaterialsCost = rawMaterialsCost + item.calculateItemCost();
    }

    // 2. Direct Packaging (Empaques)
    PreciseDecimal packagingCost = PreciseDecimal.zero;
    for (final item in recipe.packaging) {
      packagingCost = packagingCost + item.calculateItemCost();
    }

    // Direct production base
    final directBase = rawMaterialsCost + packagingCost;

    // 3. Overhead (Costos Indirectos y Servicios)
    final overheadPercent = config.overheadPercentage;
    final overheadCost = directBase * (overheadPercent / PreciseDecimal.fromInt(100));

    // 4. Labor Cost (Mano de Obra por Minuto de Trabajo)
    // Formula: (PrepTimeMinutes / 60) * LaborHourlyRate
    final hoursWorked = PreciseDecimal.fromInt(recipe.prepTimeMinutes) /
        PreciseDecimal.fromInt(60);
    final laborCost = hoursWorked * config.laborHourlyRate;

    // 5. Total Batch Production Cost
    final totalProductionCost = directBase + overheadCost + laborCost;

    // 6. Cost per individual portion/slice
    final portions = recipe.yieldPortions > 0 ? recipe.yieldPortions : 1;
    final costPerPortion =
        totalProductionCost / PreciseDecimal.fromInt(portions);

    // 7. Pricing Markup
    // PV_lote = Costo_Total * (1 + Margin / 100)
    final marginMultiplier = PreciseDecimal.fromInt(1) +
        (recipe.targetProfitMargin / PreciseDecimal.fromInt(100));
    final suggestedBatchPrice = totalProductionCost * marginMultiplier;

    // 8. Price per portion
    final suggestedPortionPrice =
        suggestedBatchPrice / PreciseDecimal.fromInt(portions);

    // 9. Net profits
    final netProfitBatch = suggestedBatchPrice - totalProductionCost;
    final netProfitPortion = suggestedPortionPrice - costPerPortion;

    return CostBreakdown(
      rawMaterialsCost: rawMaterialsCost,
      packagingCost: packagingCost,
      overheadCost: overheadCost,
      laborCost: laborCost,
      totalProductionCost: totalProductionCost,
      costPerPortion: costPerPortion,
      suggestedBatchPrice: suggestedBatchPrice,
      suggestedPortionPrice: suggestedPortionPrice,
      netProfitBatch: netProfitBatch,
      netProfitPortion: netProfitPortion,
    );
  }
}
