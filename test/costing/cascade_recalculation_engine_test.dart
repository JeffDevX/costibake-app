import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/costing/domain/services/cascade_recalculation_engine.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe_item.dart';
import 'package:costibake_app/features/settings/domain/entities/business_config.dart';

void main() {
  group('CascadeRecalculationEngine Unit Tests (JEF-9, RF-SYS-04, RNF-02)', () {
    const butterId = 'ing_butter';
    const flourId = 'ing_flour';
    const sugarId = 'ing_sugar';

    const r1Sponge = 'rec_sponge'; // Uses butter, flour, sugar
    const r2Cream = 'rec_cream'; // Uses butter, sugar
    const r3Milhojas = 'rec_milhojas'; // Sub-recipe of r1Sponge & r2Cream
    const r4GrandCake = 'rec_grand_cake'; // Sub-recipe of r3Milhojas
    const r5Bread = 'rec_bread'; // Uses only flour (unaffected by butter)

    final recipeToIngredientMap = {
      r1Sponge: [butterId, flourId, sugarId],
      r2Cream: [butterId, sugarId],
      r3Milhojas: <String>[], // uses only sub-recipes
      r4GrandCake: <String>[], // uses r3Milhojas
      r5Bread: [flourId],
    };

    final parentToChildSubRecipeMap = {
      r3Milhojas: [r1Sponge, r2Cream],
      r4GrandCake: [r3Milhojas],
    };

    test('findAffectedRecipeIds correctly identifies direct and multi-level ancestors in DAG (BR-PRC-02)', () {
      final affected = CascadeRecalculationEngine.findAffectedRecipeIds(
        changedIngredientId: butterId,
        recipeToIngredientMap: recipeToIngredientMap,
        parentToChildSubRecipeMap: parentToChildSubRecipeMap,
      );

      // Direct: r1Sponge, r2Cream
      // Level 1 parent: r3Milhojas
      // Level 2 parent: r4GrandCake
      // r5Bread must NOT be in affected
      expect(affected, containsAll([r1Sponge, r2Cream, r3Milhojas, r4GrandCake]));
      expect(affected.contains(r5Bread), isFalse);
      expect(affected.length, equals(4));
    });

    test('findAffectedRecipeIds returns empty set when ingredient is unused', () {
      final affected = CascadeRecalculationEngine.findAffectedRecipeIds(
        changedIngredientId: 'unused_ingredient_id',
        recipeToIngredientMap: recipeToIngredientMap,
        parentToChildSubRecipeMap: parentToChildSubRecipeMap,
      );

      expect(affected, isEmpty);
    });

    test('topologicalSort orders children strictly before parents using Kahn algorithm', () {
      final affectedIds = {r4GrandCake, r3Milhojas, r1Sponge, r2Cream};

      final sorted = CascadeRecalculationEngine.topologicalSort(
        affectedRecipeIds: affectedIds,
        parentToChildSubRecipeMap: parentToChildSubRecipeMap,
      );

      expect(sorted.length, equals(4));

      // r1Sponge and r2Cream must come before r3Milhojas
      final idxR1 = sorted.indexOf(r1Sponge);
      final idxR2 = sorted.indexOf(r2Cream);
      final idxR3 = sorted.indexOf(r3Milhojas);
      final idxR4 = sorted.indexOf(r4GrandCake);

      expect(idxR1, lessThan(idxR3));
      expect(idxR2, lessThan(idxR3));
      // r3Milhojas must come before r4GrandCake
      expect(idxR3, lessThan(idxR4));
    });

    test('recalculateRecipe propagates child sub-recipe cost to parent without numeric drift (RNF-02)', () {
      final config = BusinessConfig(
        id: 'cfg_1',
        businessName: 'Dulce Arte',
        currencySymbol: '\$',
        laborHourlyRate: PreciseDecimal.fromString('12.0000'),
        overheadPercentage: PreciseDecimal.fromString('10.0000'),
        updatedAt: DateTime(2026, 1, 1),
      );

      // Child recipe: Bizcocho with direct materials = 5.0000
      final childRecipe = Recipe(
        id: r1Sponge,
        name: 'Bizcocho Vainilla',
        yieldPortions: 1,
        prepTimeMinutes: 30, // 0.5 h * 12 = 6.00 labor
        bakeTimeMinutes: 30,
        targetProfitMargin: PreciseDecimal.fromString('40.0000'),
        status: 'ACTIVA',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        ingredients: [
          RecipeIngredientItem(
            id: 'i1',
            recipeId: r1Sponge,
            ingredientId: butterId,
            ingredientName: 'Mantequilla',
            quantity: PreciseDecimal.fromString('100.0000'),
            unit: 'g',
            baseUnit: 'g',
            unitCost: PreciseDecimal.fromString('0.0500'), // 100 * 0.05 = 5.00
          ),
        ],
      );

      final childResult = CascadeRecalculationEngine.recalculateRecipe(
        recipe: childRecipe,
        config: config,
      );

      // Direct materials = 5.00
      // Labor = 6.00
      // Overhead = 10% of 5.00 = 0.50
      // CTP = 5.00 + 6.00 + 0.50 = 11.5000
      expect(childResult.breakdown.directMaterialCost, equals(PreciseDecimal.fromString('5.0000')));
      expect(childResult.breakdown.totalProductionCost, equals(PreciseDecimal.fromString('11.5000')));

      // Parent recipe: uses 2.0 batches of childRecipe
      final parentRecipe = Recipe(
        id: r3Milhojas,
        name: 'Torta Milhojas',
        yieldPortions: 8,
        prepTimeMinutes: 15, // 0.25 h * 12 = 3.00 labor
        bakeTimeMinutes: 0,
        targetProfitMargin: PreciseDecimal.fromString('35.0000'),
        status: 'ACTIVA',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        subRecipes: [
          RecipeSubRecipeItem(
            id: 'sub1',
            parentRecipeId: r3Milhojas,
            childRecipeId: r1Sponge,
            childRecipeName: 'Bizcocho Vainilla',
            quantityFactor: PreciseDecimal.fromString('2.0000'),
            unitCost: PreciseDecimal.fromString('3.0000'), // old cost, to be updated
          ),
        ],
      );

      // Recalculate parent with updated child direct cost: 5.0000
      final parentResult = CascadeRecalculationEngine.recalculateRecipe(
        recipe: parentRecipe,
        config: config,
        updatedChildRecipeCosts: {
          r1Sponge: childResult.breakdown.directMaterialCost,
        },
      );

      // Sub-recipe cost in parent = 2.0 * 5.0000 = 10.0000
      expect(parentResult.breakdown.subRecipesCost, equals(PreciseDecimal.fromString('10.0000')));
      expect(parentResult.breakdown.directMaterialCost, equals(PreciseDecimal.fromString('10.0000')));
      // Labor = 15/60 * 12 = 3.00
      // Overhead = 10% of 10.00 = 1.00
      // Total CTP = 10.00 + 3.00 + 1.00 = 14.0000
      expect(parentResult.breakdown.totalProductionCost, equals(PreciseDecimal.fromString('14.0000')));
      // Cost per portion = 14.00 / 8 = 1.7500
      expect(parentResult.breakdown.costPerPortion, equals(PreciseDecimal.fromString('1.7500')));
      // Batch price = 14.00 * 1.35 = 18.9000
      expect(parentResult.breakdown.suggestedBatchPrice, equals(PreciseDecimal.fromString('18.9000')));
      // Portion price = 18.90 / 8 = 2.3625
      expect(parentResult.breakdown.suggestedPortionPrice, equals(PreciseDecimal.fromString('2.3625')));
    });
  });
}
