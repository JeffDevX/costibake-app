import '../../../../core/utils/precise_decimal.dart';
import '../entities/dual_pricing_breakdown.dart';
import '../entities/pricing_strategy.dart';

/// Pure domain calculation engine for pastry commercial pricing and dual outputs
/// (JEF-16, RF-SYS-18..20, BR-PRC-01..05, RNF-02).
class PricingEngine {
  /// Computes the complete dual pricing breakdown for full batch and individual portion.
  static DualPricingBreakdown calculate({
    required PreciseDecimal totalProductionCost,
    required int yieldPortions,
    required PricingStrategy strategy,
  }) {
    final batchCost = totalProductionCost >= PreciseDecimal.zero
        ? totalProductionCost
        : PreciseDecimal.zero;

    final portions = yieldPortions > 0 ? yieldPortions : 1;
    final portionsDecimal = PreciseDecimal.fromInt(portions);
    final portionCost = batchCost / portionsDecimal;

    final targetMargin = strategy.targetProfitMargin >= PreciseDecimal.zero
        ? strategy.targetProfitMargin
        : PreciseDecimal.zero;

    // 1. Raw Suggested Batch Price (BR-PRC-01)
    final PreciseDecimal rawSuggestedBatch;
    if (batchCost == PreciseDecimal.zero) {
      rawSuggestedBatch = PreciseDecimal.zero;
    } else if (strategy.mode == PricingMode.markupOnCost) {
      // Precio_Sugerido = Costo_Total * (1 + Margen / 100)
      final multiplier = PreciseDecimal.fromInt(1) +
          (targetMargin / PreciseDecimal.fromInt(100));
      rawSuggestedBatch = batchCost * multiplier;
    } else {
      // Modo Margen sobre Venta: Precio_Sugerido = Costo_Total / (1 - Margen / 100)
      if (targetMargin >= PreciseDecimal.fromInt(100)) {
        throw ArgumentError(
          'El margen sobre venta debe ser estrictamente menor al 100%',
        );
      }
      final divisor = PreciseDecimal.fromInt(1) -
          (targetMargin / PreciseDecimal.fromInt(100));
      rawSuggestedBatch = batchCost / divisor;
    }

    // 2. Rounding Rule Application (RF-SYS-20)
    final roundingStep = strategy.roundingRule.step;
    final roundedSuggestedBatch = roundingStep != null
        ? rawSuggestedBatch.ceilToMultiple(roundingStep)
        : rawSuggestedBatch;

    // 3. Batch Effective Price & Metrics (BR-PRC-02, BR-PRC-04, BR-PRC-05)
    final effectiveBatchPrice =
        strategy.customBatchPrice ?? roundedSuggestedBatch;
    final netProfitBatch = effectiveBatchPrice - batchCost;

    final realMarkupBatch = batchCost > PreciseDecimal.zero
        ? (netProfitBatch / batchCost) * PreciseDecimal.fromInt(100)
        : PreciseDecimal.zero;

    final realMarginOnSalesBatch = effectiveBatchPrice > PreciseDecimal.zero
        ? (netProfitBatch / effectiveBatchPrice) * PreciseDecimal.fromInt(100)
        : PreciseDecimal.zero;

    final isBatchAtLoss = effectiveBatchPrice <= batchCost;

    // 4. Portion Raw & Rounded Suggested Price (BR-PRC-03)
    final rawSuggestedPortion = rawSuggestedBatch / portionsDecimal;
    final roundedSuggestedPortion = roundingStep != null
        ? rawSuggestedPortion.ceilToMultiple(roundingStep)
        : rawSuggestedPortion;

    // 5. Portion Effective Price & Metrics (BR-PRC-04, BR-PRC-05)
    final effectivePortionPrice =
        strategy.customPortionPrice ?? roundedSuggestedPortion;
    final netProfitPortion = effectivePortionPrice - portionCost;

    final realMarkupPortion = portionCost > PreciseDecimal.zero
        ? (netProfitPortion / portionCost) * PreciseDecimal.fromInt(100)
        : PreciseDecimal.zero;

    final realMarginOnSalesPortion = effectivePortionPrice > PreciseDecimal.zero
        ? (netProfitPortion / effectivePortionPrice) * PreciseDecimal.fromInt(100)
        : PreciseDecimal.zero;

    final isPortionAtLoss = effectivePortionPrice <= portionCost;

    return DualPricingBreakdown(
      strategy: strategy,
      batchCost: batchCost,
      rawSuggestedBatchPrice: rawSuggestedBatch,
      roundedSuggestedBatchPrice: roundedSuggestedBatch,
      effectiveBatchPrice: effectiveBatchPrice,
      netProfitBatch: netProfitBatch,
      realMarkupBatch: realMarkupBatch,
      realMarginOnSalesBatch: realMarginOnSalesBatch,
      isBatchAtLoss: isBatchAtLoss,
      yieldPortions: portions,
      portionCost: portionCost,
      rawSuggestedPortionPrice: rawSuggestedPortion,
      roundedSuggestedPortionPrice: roundedSuggestedPortion,
      effectivePortionPrice: effectivePortionPrice,
      netProfitPortion: netProfitPortion,
      realMarkupPortion: realMarkupPortion,
      realMarginOnSalesPortion: realMarginOnSalesPortion,
      isPortionAtLoss: isPortionAtLoss,
    );
  }
}
