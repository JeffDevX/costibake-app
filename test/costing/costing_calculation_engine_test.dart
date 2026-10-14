import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/constants/app_constants.dart';
import 'package:costibake_app/core/errors/exceptions.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/costing/domain/services/costing_calculation_engine.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe_item.dart';
import 'package:costibake_app/features/settings/domain/entities/business_config.dart';

void main() {
  group('CostingCalculationEngine Mathematical Domain Tests (JEF-15)', () {
    late BusinessConfig defaultConfig;

    setUp(() {
      defaultConfig = BusinessConfig(
        id: 'cfg-1',
        businessName: 'Pastelería Dulce Arte',
        currencySymbol: r'$',
        laborHourlyRate: PreciseDecimal.fromString('12.00'), // $12/h
        overheadPercentage: PreciseDecimal.fromString('15.00'), // 15%
        updatedAt: DateTime.now(),
      );
    });

    test('RF-SYS-17 & BR-CST-06: Quadruple Cost Calculation CTP = CI + CE + CMO + COH', () {
      // Direct raw materials (CI): $10.00
      final ing = RecipeIngredientItem(
        id: 'i1',
        recipeId: 'rec-1',
        ingredientId: 'ing-flour',
        ingredientName: 'Harina de Trigo',
        quantity: PreciseDecimal.fromInt(2),
        unit: 'kg',
        baseUnit: 'kg',
        unitCost: PreciseDecimal.fromString('5.00'), // 2 * 5.00 = $10.00
      );

      // Packaging (CE): 4 boxes @ $0.50 = $2.00
      final pack = RecipePackagingItem(
        id: 'p1',
        recipeId: 'rec-1',
        packagingId: 'pack-box',
        packagingName: 'Caja Kraft',
        pieceQuantity: 4,
        unitCost: PreciseDecimal.fromString('0.50'),
      );

      // Recipe: prep time = 30 min (0.5 h), yield = 4 portions, margin = 50%
      final recipe = Recipe(
        id: 'rec-1',
        name: 'Pastel de Vainilla',
        yieldPortions: 4,
        prepTimeMinutes: 30, // 30 / 60 * $12 = $6.00 CMO
        bakeTimeMinutes: 45,
        targetProfitMargin: PreciseDecimal.fromString('50.00'), // 50% markup
        status: AppConstants.recipeStatusActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ingredients: [ing],
        packaging: [pack],
      );

      final breakdown = CostingCalculationEngine.calculate(
        recipe: recipe,
        config: defaultConfig,
      );

      // CI = $10.00
      expect(breakdown.rawMaterialsCost.toStringAsFixed(2), '10.00');
      // Sub-recipes = $0.00
      expect(breakdown.subRecipesCost.toStringAsFixed(2), '0.00');
      // CE = $2.00
      expect(breakdown.packagingCost.toStringAsFixed(2), '2.00');
      // Direct Material Base = 10.00 + 2.00 = $12.00
      expect(breakdown.directMaterialCost.toStringAsFixed(2), '12.00');
      // CMO = (30/60) * 12.00 = $6.00
      expect(breakdown.laborCost.toStringAsFixed(2), '6.00');
      // COH = 12.00 * (15 / 100) = $1.80
      expect(breakdown.overheadCost.toStringAsFixed(2), '1.80');
      // CTP = 12.00 + 6.00 + 1.80 = $19.80
      expect(breakdown.totalProductionCost.toStringAsFixed(2), '19.80');
      // CUP = 19.80 / 4 = $4.95
      expect(breakdown.costPerPortion.toStringAsFixed(2), '4.95');

      // Suggested Selling Price (50% Markup -> 1.5 multiplier)
      // Batch Price = 19.80 * 1.5 = $29.70
      expect(breakdown.suggestedBatchPrice.toStringAsFixed(2), '29.70');
      // Portion Price = 29.70 / 4 = $7.425
      expect(breakdown.suggestedPortionPrice.toStringAsFixed(3), '7.425');
      // Net Profit Batch = 29.70 - 19.80 = $9.90
      expect(breakdown.netProfitBatch.toStringAsFixed(2), '9.90');
      // Net Profit Portion = 7.425 - 4.95 = $2.475
      expect(breakdown.netProfitPortion.toStringAsFixed(3), '2.475');

      // Percentages
      // Raw materials: 10 / 19.80 * 100 ≈ 50.505%
      expect(breakdown.ingredientsPercentage, closeTo(50.50, 0.05));
      // Packaging: 2 / 19.80 * 100 ≈ 10.101%
      expect(breakdown.packagingPercentage, closeTo(10.10, 0.05));
      // Labor: 6 / 19.80 * 100 ≈ 30.303%
      expect(breakdown.laborPercentage, closeTo(30.30, 0.05));
      // Overhead: 1.80 / 19.80 * 100 ≈ 9.09%
      expect(breakdown.overheadPercentage, closeTo(9.09, 0.05));
    });

    test('Modular Sub-recipes prorating and inclusion in Direct Base (RF-SYS-10)', () {
      final subRecipeItem = RecipeSubRecipeItem(
        id: 'sub-1',
        parentRecipeId: 'parent-1',
        childRecipeId: 'child-1',
        childRecipeName: 'Ganache de Chocolate 70%',
        quantityFactor: PreciseDecimal.fromString('0.5'), // 50% of the child batch
        section: 'Cobertura',
        unitCost: PreciseDecimal.fromString('14.00'), // Child batch cost is $14.00 -> 0.5 * 14 = $7.00
      );

      final recipe = Recipe(
        id: 'parent-1',
        name: 'Torta Selva Negra con Ganache',
        yieldPortions: 1,
        prepTimeMinutes: 0,
        bakeTimeMinutes: 0,
        targetProfitMargin: PreciseDecimal.fromString('40.00'),
        status: AppConstants.recipeStatusActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ingredients: const [],
        subRecipes: [subRecipeItem],
        packaging: const [],
      );

      final breakdown = CostingCalculationEngine.calculate(
        recipe: recipe,
        config: defaultConfig, // 15% overhead
      );

      expect(breakdown.subRecipesCost.toStringAsFixed(2), '7.00');
      expect(breakdown.rawMaterialsCost, PreciseDecimal.zero);
      expect(breakdown.packagingCost, PreciseDecimal.zero);
      expect(breakdown.directMaterialCost.toStringAsFixed(2), '7.00');

      // Overhead is applied to modular sub-recipes: 7.00 * 0.15 = 1.05
      expect(breakdown.overheadCost.toStringAsFixed(2), '1.05');
      // CTP = 7.00 + 1.05 = 8.05
      expect(breakdown.totalProductionCost.toStringAsFixed(2), '8.05');
    });

    test('Per-recipe Overrides Precedence (RF-SYS-15, RF-SYS-16)', () {
      final recipeWithOverrides = Recipe(
        id: 'rec-special',
        name: 'Macarons de Pistacho Gourmet',
        yieldPortions: 10,
        prepTimeMinutes: 60, // 1 hour
        bakeTimeMinutes: 15,
        targetProfitMargin: PreciseDecimal.fromString('100.00'),
        status: AppConstants.recipeStatusActive,
        laborHourlyRateOverride: PreciseDecimal.fromString('25.00'), // $25/h instead of $12
        overheadPercentageOverride: PreciseDecimal.fromString('20.00'), // 20% instead of 15%
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ingredients: [
          RecipeIngredientItem(
            id: 'i1',
            recipeId: 'rec-special',
            ingredientId: 'ing-almond',
            ingredientName: 'Harina de Almendras',
            quantity: PreciseDecimal.fromInt(1),
            unit: 'kg',
            baseUnit: 'kg',
            unitCost: PreciseDecimal.fromString('20.00'),
          ),
        ],
        packaging: const [],
      );

      final breakdown = CostingCalculationEngine.calculate(
        recipe: recipeWithOverrides,
        config: defaultConfig,
      );

      // Verify effective rates applied
      expect(breakdown.effectiveLaborRatePerHour.toStringAsFixed(2), '25.00');
      expect(breakdown.effectiveOverheadPercentage.toStringAsFixed(1), '20.0');

      // Labor cost: 1 hour * $25 = $25.00
      expect(breakdown.laborCost.toStringAsFixed(2), '25.00');
      // Overhead cost: $20 * 20% = $4.00
      expect(breakdown.overheadCost.toStringAsFixed(2), '4.00');
      // CTP = $20 (Direct) + $25 (Labor) + $4 (Overhead) = $49.00
      expect(breakdown.totalProductionCost.toStringAsFixed(2), '49.00');
    });

    test('BR-CST-01: Throws NegativeCostComponentException if any cost component is negative', () {
      final recipeNegativeLabor = Recipe(
        id: 'rec-neg',
        name: 'Receta Inválida',
        yieldPortions: 1,
        prepTimeMinutes: -10, // Negative time!
        bakeTimeMinutes: 0,
        targetProfitMargin: PreciseDecimal.fromString('40.00'),
        status: AppConstants.recipeStatusActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ingredients: const [],
        packaging: const [],
      );

      expect(
        () => CostingCalculationEngine.calculate(
          recipe: recipeNegativeLabor,
          config: defaultConfig,
        ),
        throwsA(isA<NegativeCostComponentException>()),
      );

      final recipeValid = Recipe(
        id: 'rec-valid',
        name: 'Receta Válida',
        yieldPortions: 1,
        prepTimeMinutes: 10,
        bakeTimeMinutes: 0,
        targetProfitMargin: PreciseDecimal.fromString('40.00'),
        status: AppConstants.recipeStatusActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ingredients: const [],
        packaging: const [],
      );

      // Negative labor rate override
      expect(
        () => CostingCalculationEngine.calculate(
          recipe: recipeValid,
          config: defaultConfig,
          laborHourlyRateOverride: PreciseDecimal.fromString('-5.00'),
        ),
        throwsA(isA<NegativeCostComponentException>()),
      );

      // Negative overhead percentage override
      expect(
        () => CostingCalculationEngine.calculate(
          recipe: recipeValid,
          config: defaultConfig,
          overheadPercentageOverride: PreciseDecimal.fromString('-10.00'),
        ),
        throwsA(isA<NegativeCostComponentException>()),
      );
    });
  });
}
