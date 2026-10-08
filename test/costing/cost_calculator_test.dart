import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/costing/domain/services/cost_calculator.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe_item.dart';
import 'package:costibake_app/features/settings/domain/entities/business_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CostCalculator Quad-Cost and Dual Pricing Tests', () {
    test('SRS CA-02: Verificación de Vasitos de Tres Leches en Porciones', () {
      // Ingredients total = $8.50
      final ingredientItem = RecipeIngredientItem(
        id: 'ri-1',
        recipeId: 'rec-tres-leches',
        ingredientId: 'ing-tres-leches-mix',
        ingredientName: 'Mezcla Tres Leches',
        quantity: PreciseDecimal.fromInt(1),
        unit: 'lote',
        unitCost: PreciseDecimal.fromString('8.50'),
      );

      // Packaging: 15 cups at $0.20 each = $3.00
      final packagingItem = RecipePackagingItem(
        id: 'rp-1',
        recipeId: 'rec-tres-leches',
        packagingId: 'pack-vasito',
        packagingName: 'Vasito con tapa',
        pieceQuantity: 15,
        unitCost: PreciseDecimal.fromString('0.20'),
      );

      // Recipe: 15 portions, prep time 24 minutes (to generate $4.00 at $10/hr: 24/60 * 10 = 4.00), 100% markup
      final recipe = Recipe(
        id: 'rec-tres-leches',
        name: 'Vasitos Tres Leches',
        yieldPortions: 15,
        prepTimeMinutes: 24, // 24 min / 60 min * $10/h = $4.00
        bakeTimeMinutes: 30,
        targetProfitMargin: PreciseDecimal.fromString('100.00'), // 100% markup
        status: 'ACTIVA',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ingredients: [ingredientItem],
        packaging: [packagingItem],
      );

      // Config: $10/hr labor, 10% overhead on direct materials (10% of $8.50 raw materials = $0.85)
      // Note: in our calculator, overhead is applied to direct production base or raw materials.
      // With direct base = $8.50, overhead (10%) = $0.85
      final config = BusinessConfig(
        id: 'cfg-1',
        businessName: 'Taller Dulce',
        currencySymbol: r'$',
        laborHourlyRate: PreciseDecimal.fromString('10.00'),
        // Overhead on raw materials: 10% on $8.50
        overheadPercentage: PreciseDecimal.fromString('10.00'),
        updatedAt: DateTime.now(),
      );

      // Since our standard formula calculates overhead over raw materials ($8.50):
      // rawMaterialsCost = $8.50
      // packagingCost = $3.00 (15 * $0.20)
      // laborCost = 24 / 60 * 10 = $4.00
      final breakdown = CostCalculator.calculate(
        recipe: recipe,
        config: config,
      );

      expect(breakdown.rawMaterialsCost.toStringAsFixed(2), '8.50');
      expect(breakdown.packagingCost.toStringAsFixed(2), '3.00');
      expect(breakdown.laborCost.toStringAsFixed(2), '4.00');

      // Total production cost = Insumos ($8.50) + Empaques ($3.00) + Overhead + Mano de obra ($4.00)
      // Margin 100% doubles total cost
      expect(breakdown.suggestedBatchPrice > breakdown.totalProductionCost, isTrue);
      expect(breakdown.costPerPortion > PreciseDecimal.zero, isTrue);
      expect(breakdown.suggestedPortionPrice > PreciseDecimal.zero, isTrue);
    });
  });
}
