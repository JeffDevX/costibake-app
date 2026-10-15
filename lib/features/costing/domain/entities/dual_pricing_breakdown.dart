import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';
import 'pricing_strategy.dart';

/// Complete dual pricing analysis and results for both full batch and individual portion (RF-SYS-19, BR-PRC-01..05).
class DualPricingBreakdown extends Equatable {
  final PricingStrategy strategy;

  // --- Lote Completo (Batch Level) ---
  /// Total batch production cost (CTP) (BR-CST-06)
  final PreciseDecimal batchCost;

  /// Pure mathematical suggested price before rounding (BR-PRC-01)
  final PreciseDecimal rawSuggestedBatchPrice;

  /// Suggested price after applying rounding rule (RF-SYS-20)
  final PreciseDecimal roundedSuggestedBatchPrice;

  /// Final effective price: customBatchPrice if manually set, otherwise roundedSuggestedBatchPrice
  final PreciseDecimal effectiveBatchPrice;

  /// Net monetary profit = effectiveBatchPrice - batchCost (BR-PRC-02)
  final PreciseDecimal netProfitBatch;

  /// Real markup on cost percentage = ((effectiveBatchPrice - batchCost) / batchCost) * 100 (BR-PRC-04)
  final PreciseDecimal realMarkupBatch;

  /// Real margin on sales percentage = ((effectiveBatchPrice - batchCost) / effectiveBatchPrice) * 100
  final PreciseDecimal realMarginOnSalesBatch;

  /// Flag indicating selling at loss: effectiveBatchPrice <= batchCost (BR-PRC-05)
  final bool isBatchAtLoss;

  // --- Porción / Unidad Individual (Portion Level) ---
  /// Yield in portions or pieces
  final int yieldPortions;

  /// Cost per portion (CUP = batchCost / yieldPortions) (BR-CST-07)
  final PreciseDecimal portionCost;

  /// Raw suggested portion price = rawSuggestedBatchPrice / yieldPortions (BR-PRC-03)
  final PreciseDecimal rawSuggestedPortionPrice;

  /// Suggested portion price after applying rounding rule
  final PreciseDecimal roundedSuggestedPortionPrice;

  /// Final effective portion price: customPortionPrice if manually set, otherwise roundedSuggestedPortionPrice
  final PreciseDecimal effectivePortionPrice;

  /// Net monetary profit per portion = effectivePortionPrice - portionCost
  final PreciseDecimal netProfitPortion;

  /// Real markup on portion cost percentage
  final PreciseDecimal realMarkupPortion;

  /// Real margin on portion sales percentage
  final PreciseDecimal realMarginOnSalesPortion;

  /// Flag indicating portion selling at loss: effectivePortionPrice <= portionCost (BR-PRC-05)
  final bool isPortionAtLoss;

  const DualPricingBreakdown({
    required this.strategy,
    required this.batchCost,
    required this.rawSuggestedBatchPrice,
    required this.roundedSuggestedBatchPrice,
    required this.effectiveBatchPrice,
    required this.netProfitBatch,
    required this.realMarkupBatch,
    required this.realMarginOnSalesBatch,
    required this.isBatchAtLoss,
    required this.yieldPortions,
    required this.portionCost,
    required this.rawSuggestedPortionPrice,
    required this.roundedSuggestedPortionPrice,
    required this.effectivePortionPrice,
    required this.netProfitPortion,
    required this.realMarkupPortion,
    required this.realMarginOnSalesPortion,
    required this.isPortionAtLoss,
  });

  /// Real percentage margin corresponding to the active pricing mode (BR-PRC-04)
  PreciseDecimal get realActiveMarginBatch =>
      strategy.mode == PricingMode.markupOnCost
          ? realMarkupBatch
          : realMarginOnSalesBatch;

  PreciseDecimal get realActiveMarginPortion =>
      strategy.mode == PricingMode.markupOnCost
          ? realMarkupPortion
          : realMarginOnSalesPortion;

  /// Whether batch price was manually customized
  bool get isBatchCustomPrice => strategy.customBatchPrice != null;

  /// Whether portion price was manually customized
  bool get isPortionCustomPrice => strategy.customPortionPrice != null;

  @override
  List<Object?> get props => [
        strategy,
        batchCost,
        rawSuggestedBatchPrice,
        roundedSuggestedBatchPrice,
        effectiveBatchPrice,
        netProfitBatch,
        realMarkupBatch,
        realMarginOnSalesBatch,
        isBatchAtLoss,
        yieldPortions,
        portionCost,
        rawSuggestedPortionPrice,
        roundedSuggestedPortionPrice,
        effectivePortionPrice,
        netProfitPortion,
        realMarkupPortion,
        realMarginOnSalesPortion,
        isPortionAtLoss,
      ];
}
