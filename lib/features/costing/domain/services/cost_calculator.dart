import '../../../recipes/domain/entities/recipe.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../entities/cost_breakdown.dart';
import 'costing_calculation_engine.dart';

/// Legacy facade delegating to [CostingCalculationEngine].
class CostCalculator {
  /// Calculates the complete quad-component cost and dual pricing breakdown
  static CostBreakdown calculate({
    required Recipe recipe,
    required BusinessConfig config,
  }) {
    return CostingCalculationEngine.calculate(
      recipe: recipe,
      config: config,
    );
  }
}
