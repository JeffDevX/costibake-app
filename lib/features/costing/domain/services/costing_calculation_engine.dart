import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../recipes/domain/entities/recipe.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../entities/cost_breakdown.dart';

/// Pure domain service calculating the quadruple financial cost breakdown
/// for a pastry recipe (JEF-15, RF-SYS-14..17, BR-CST-01..07, RNF-02).
class CostingCalculationEngine {
  /// Computes the complete integral cost breakdown:
  /// CTP = CI (Insumos + Sub-recetas) + CE (Empaques) + CMO (Mano de Obra) + COH (Overhead)
  static CostBreakdown calculate({
    required Recipe recipe,
    required BusinessConfig config,
    PreciseDecimal? laborHourlyRateOverride,
    PreciseDecimal? overheadPercentageOverride,
    PreciseDecimal? targetProfitMarginOverride,
    int? yieldPortionsOverride,
    int? prepTimeMinutesOverride,
  }) {
    // 1. Raw Materials & Sub-recipes (CI) (BR-CST-02, RF-SYS-10, RF-SYS-11)
    PreciseDecimal rawMaterialsCost = recipe.totalIngredientsCost;
    PreciseDecimal subRecipesCost = recipe.totalSubRecipesCost;

    if (rawMaterialsCost < PreciseDecimal.zero) {
      throw const NegativeCostComponentException('Insumos Directos');
    }
    if (subRecipesCost < PreciseDecimal.zero) {
      throw const NegativeCostComponentException('Sub-recetas Modulares');
    }

    // 2. Direct Packaging (CE) (BR-CST-03, RF-SYS-14)
    PreciseDecimal packagingCost = recipe.totalPackagingCost;
    if (packagingCost < PreciseDecimal.zero) {
      throw const NegativeCostComponentException('Empaques y Descartables');
    }

    // Base directa de producción = CI + CE
    final directBase = rawMaterialsCost + subRecipesCost + packagingCost;

    // 3. Tarifa de Mano de Obra y Tiempo (CMO) (BR-CST-04, RF-SYS-16)
    final effectiveLaborRate = laborHourlyRateOverride ??
        recipe.laborHourlyRateOverride ??
        config.laborHourlyRate;

    if (effectiveLaborRate < PreciseDecimal.zero) {
      throw const NegativeCostComponentException('Tarifa Horaria de Mano de Obra');
    }

    final prepMinutes = prepTimeMinutesOverride ?? recipe.prepTimeMinutes;
    if (prepMinutes < 0) {
      throw const NegativeCostComponentException('Tiempo de Preparación');
    }

    // CMO = (prepMinutes / 60) * effectiveLaborRate
    final hoursWorked = PreciseDecimal.fromInt(prepMinutes) /
        PreciseDecimal.fromInt(60);
    final laborCost = hoursWorked * effectiveLaborRate;

    // 4. Overhead / Costos Indirectos de Fabricación (COH) (BR-CST-05, RF-SYS-15)
    final effectiveOverheadPercent = overheadPercentageOverride ??
        recipe.overheadPercentageOverride ??
        config.overheadPercentage;

    if (effectiveOverheadPercent < PreciseDecimal.zero) {
      throw const NegativeCostComponentException('Porcentaje de Overhead');
    }

    // COH = (CI + CE) * (Overhead % / 100)
    final overheadMultiplier = effectiveOverheadPercent / PreciseDecimal.fromInt(100);
    final overheadCost = directBase * overheadMultiplier;

    // 5. Costo Total de Producción (CTP) (BR-CST-06, RF-SYS-17)
    // CTP = CI + CE + CMO + COH
    final totalProductionCost = directBase + laborCost + overheadCost;

    // 6. Costo Unitario por Porción (CUP) (BR-CST-07)
    final portions = yieldPortionsOverride ?? recipe.yieldPortions;
    final effectivePortions = portions > 0 ? portions : 1;
    final costPerPortion =
        totalProductionCost / PreciseDecimal.fromInt(effectivePortions);

    // 7. Fijación de Precios según Margen (Markup)
    final effectiveMargin = targetProfitMarginOverride ?? recipe.targetProfitMargin;
    final marginMultiplier = PreciseDecimal.fromInt(1) +
        (effectiveMargin / PreciseDecimal.fromInt(100));

    final suggestedBatchPrice = totalProductionCost * marginMultiplier;
    final suggestedPortionPrice =
        suggestedBatchPrice / PreciseDecimal.fromInt(effectivePortions);

    final netProfitBatch = suggestedBatchPrice - totalProductionCost;
    final netProfitPortion = suggestedPortionPrice - costPerPortion;

    return CostBreakdown(
      rawMaterialsCost: rawMaterialsCost,
      subRecipesCost: subRecipesCost,
      packagingCost: packagingCost,
      directMaterialCost: directBase,
      effectiveLaborRatePerHour: effectiveLaborRate,
      effectiveOverheadPercentage: effectiveOverheadPercent,
      prepTimeMinutes: prepMinutes,
      laborCost: laborCost,
      overheadCost: overheadCost,
      totalProductionCost: totalProductionCost,
      yieldPortions: effectivePortions,
      costPerPortion: costPerPortion,
      suggestedBatchPrice: suggestedBatchPrice,
      suggestedPortionPrice: suggestedPortionPrice,
      netProfitBatch: netProfitBatch,
      netProfitPortion: netProfitPortion,
    );
  }
}
