import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';

/// Consolidated financial and cost breakdown for a bakery recipe (JEF-15, RF-SYS-17).
class CostBreakdown extends Equatable {
  /// Cost of direct raw ingredients (CI) (BR-CST-02)
  final PreciseDecimal rawMaterialsCost;

  /// Cost of nested sub-recipes (modular components) (RF-SYS-10)
  final PreciseDecimal subRecipesCost;

  /// Cost of packaging & single-use containers (CE) (BR-CST-03, RF-SYS-14)
  final PreciseDecimal packagingCost;

  /// Total direct base = rawMaterialsCost + subRecipesCost + packagingCost
  final PreciseDecimal directMaterialCost;

  /// Effective hourly labor rate applied ($/h) (RF-SYS-16)
  final PreciseDecimal effectiveLaborRatePerHour;

  /// Effective overhead percentage applied (%) (RF-SYS-15)
  final PreciseDecimal effectiveOverheadPercentage;

  /// Preparation/labor time in minutes
  final int prepTimeMinutes;

  /// Cost of labor (CMO) = (prepTimeMinutes / 60) * effectiveLaborRatePerHour (BR-CST-04)
  final PreciseDecimal laborCost;

  /// Overhead cost (COH) = directMaterialCost * (% Overhead / 100) (BR-CST-05)
  final PreciseDecimal overheadCost;

  /// Total batch production cost (CTP) = directMaterialCost + laborCost + overheadCost (BR-CST-06)
  final PreciseDecimal totalProductionCost;

  /// Yield in portions or units
  final int yieldPortions;

  /// Unit cost per portion (CUP) = totalProductionCost / yieldPortions (BR-CST-07)
  final PreciseDecimal costPerPortion;

  /// Suggested batch selling price according to target profit margin markup
  final PreciseDecimal suggestedBatchPrice;

  /// Suggested portion selling price
  final PreciseDecimal suggestedPortionPrice;

  /// Net profit batch = suggestedBatchPrice - totalProductionCost
  final PreciseDecimal netProfitBatch;

  /// Net profit portion = suggestedPortionPrice - costPerPortion
  final PreciseDecimal netProfitPortion;

  const CostBreakdown({
    required this.rawMaterialsCost,
    required this.subRecipesCost,
    required this.packagingCost,
    required this.directMaterialCost,
    required this.effectiveLaborRatePerHour,
    required this.effectiveOverheadPercentage,
    required this.prepTimeMinutes,
    required this.laborCost,
    required this.overheadCost,
    required this.totalProductionCost,
    required this.yieldPortions,
    required this.costPerPortion,
    required this.suggestedBatchPrice,
    required this.suggestedPortionPrice,
    required this.netProfitBatch,
    required this.netProfitPortion,
  });

  /// Factory producing an empty/zero breakdown for initialization or fallback.
  factory CostBreakdown.empty() {
    return CostBreakdown(
      rawMaterialsCost: PreciseDecimal.zero,
      subRecipesCost: PreciseDecimal.zero,
      packagingCost: PreciseDecimal.zero,
      directMaterialCost: PreciseDecimal.zero,
      effectiveLaborRatePerHour: PreciseDecimal.zero,
      effectiveOverheadPercentage: PreciseDecimal.zero,
      prepTimeMinutes: 0,
      laborCost: PreciseDecimal.zero,
      overheadCost: PreciseDecimal.zero,
      totalProductionCost: PreciseDecimal.zero,
      yieldPortions: 1,
      costPerPortion: PreciseDecimal.zero,
      suggestedBatchPrice: PreciseDecimal.zero,
      suggestedPortionPrice: PreciseDecimal.zero,
      netProfitBatch: PreciseDecimal.zero,
      netProfitPortion: PreciseDecimal.zero,
    );
  }

  /// Percentage of total cost attributed to raw materials (0.0 to 100.0)
  double get ingredientsPercentage => totalProductionCost > PreciseDecimal.zero
      ? (rawMaterialsCost / totalProductionCost).toDouble() * 100.0
      : 0.0;

  /// Percentage of total cost attributed to modular sub-recipes (0.0 to 100.0)
  double get subRecipesPercentage => totalProductionCost > PreciseDecimal.zero
      ? (subRecipesCost / totalProductionCost).toDouble() * 100.0
      : 0.0;

  /// Percentage of total cost attributed to direct packaging (0.0 to 100.0)
  double get packagingPercentage => totalProductionCost > PreciseDecimal.zero
      ? (packagingCost / totalProductionCost).toDouble() * 100.0
      : 0.0;

  /// Percentage of total cost attributed to labor time (0.0 to 100.0)
  double get laborPercentage => totalProductionCost > PreciseDecimal.zero
      ? (laborCost / totalProductionCost).toDouble() * 100.0
      : 0.0;

  /// Percentage of total cost attributed to overhead / indirect services (0.0 to 100.0)
  double get overheadPercentage => totalProductionCost > PreciseDecimal.zero
      ? (overheadCost / totalProductionCost).toDouble() * 100.0
      : 0.0;

  @override
  List<Object?> get props => [
        rawMaterialsCost,
        subRecipesCost,
        packagingCost,
        directMaterialCost,
        effectiveLaborRatePerHour,
        effectiveOverheadPercentage,
        prepTimeMinutes,
        laborCost,
        overheadCost,
        totalProductionCost,
        yieldPortions,
        costPerPortion,
        suggestedBatchPrice,
        suggestedPortionPrice,
        netProfitBatch,
        netProfitPortion,
      ];
}
