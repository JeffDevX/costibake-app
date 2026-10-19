import 'package:flutter_test/flutter_test.dart';

import 'package:costibake_app/core/constants/app_constants.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/costing/domain/entities/pricing_strategy.dart';
import 'package:costibake_app/features/recipes/domain/entities/mold_preset.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe_item.dart';
import 'package:costibake_app/features/recipes/domain/services/scaling_engine.dart';
import 'package:costibake_app/features/settings/domain/entities/business_config.dart';

void main() {
  final defaultConfig = BusinessConfig(
    id: 'cfg-1',
    businessName: 'Pastelería Test',
    currencySymbol: r'$',
    laborHourlyRate: PreciseDecimal.fromInt(12), // $12/hr -> $0.20/min
    overheadPercentage: PreciseDecimal.fromInt(15), // 15%
    updatedAt: DateTime(2026, 10, 16),
  );

  Recipe createSampleBaseRecipe() {
    return Recipe(
      id: 'rec-base-6in',
      name: 'Torta de Chocolate',
      description: 'Receta base para molde redondo de 6 pulgadas',
      yieldPortions: 8,
      prepTimeMinutes: 60, // 1 hr -> $12.00 labor
      bakeTimeMinutes: 45,
      moldType: 'Redondo',
      moldDimension: '6" (15 cm)',
      targetProfitMargin: PreciseDecimal.fromInt(50),
      pricingMode: PricingMode.markupOnCost,
      roundingRule: RoundingRule.none,
      status: AppConstants.recipeStatusActive,
      createdAt: DateTime(2026, 10, 16),
      updatedAt: DateTime(2026, 10, 16),
      ingredients: [
        RecipeIngredientItem(
          id: 'item-flour',
          recipeId: 'rec-base-6in',
          ingredientId: 'ing-flour',
          ingredientName: 'Harina Pastelera',
          quantity: PreciseDecimal.fromInt(180), // 180 g
          unit: 'g',
          baseUnit: 'g',
          section: 'Base / Bizcocho',
          unitCost: PreciseDecimal.fromString('0.005'), // $0.90 total
        ),
        RecipeIngredientItem(
          id: 'item-eggs',
          recipeId: 'rec-base-6in',
          ingredientId: 'ing-eggs',
          ingredientName: 'Huevos Frescos',
          quantity: PreciseDecimal.fromInt(1), // 1 huevo -> scaled by 2.7778 = 2.78 huevos
          unit: 'u',
          baseUnit: 'unidad',
          section: 'Base / Bizcocho',
          unitCost: PreciseDecimal.fromString('0.36'), // $0.36 per egg
        ),
      ],
      subRecipes: [
        RecipeSubRecipeItem(
          id: 'sub-ganache',
          parentRecipeId: 'rec-base-6in',
          childRecipeId: 'rec-ganache',
          childRecipeName: 'Ganache de Chocolate',
          quantityFactor: PreciseDecimal.one,
          section: 'Cobertura / Frosting',
          unitCost: PreciseDecimal.fromString('3.60'),
        ),
      ],
      packaging: [
        RecipePackagingItem(
          id: 'pack-box',
          recipeId: 'rec-base-6in',
          packagingId: 'pkg-1',
          packagingName: 'Caja Pastelera',
          pieceQuantity: 1,
          unitCost: PreciseDecimal.fromString('1.50'),
        ),
      ],
    );
  }

  group('ScalingEngine - Geometric & Proportional Factor Calculations (JEF-14)', () {
    test('Calculates exact circular scale factor from 6" to 10" (2.7778)', () {
      final factor = ScalingEngine.calculateCircularScaleFactor(
        PreciseDecimal.fromInt(6),
        PreciseDecimal.fromInt(10),
      );

      // (10^2) / (6^2) = 100 / 36 = 2.777778
      expect(factor.toStringAsFixed(4), equals('2.7778'));
    });

    test('Calculates circular scale factor from 8" to 12" (2.2500) and 8" to 6" (0.5625)', () {
      final factorUp = ScalingEngine.calculateCircularScaleFactor(
        PreciseDecimal.fromInt(8),
        PreciseDecimal.fromInt(12),
      );
      expect(factorUp.toStringAsFixed(4), equals('2.2500'));

      final factorDown = ScalingEngine.calculateCircularScaleFactor(
        PreciseDecimal.fromInt(8),
        PreciseDecimal.fromInt(6),
      );
      expect(factorDown.toStringAsFixed(4), equals('0.5625'));
    });

    test('Calculates circular 3D volume scale factor when mold height varies (RF-SYS-13)', () {
      // 6" (h=5cm) -> 10" (h=7.5cm): (100/36) * (7.5/5) = 150 / 36 = 4.166667
      final factor = ScalingEngine.calculateCircularScaleFactor(
        PreciseDecimal.fromInt(6),
        PreciseDecimal.fromInt(10),
        hOrigin: PreciseDecimal.fromInt(5),
        hTarget: PreciseDecimal.fromString('7.5'),
      );
      expect(factor.toStringAsFixed(4), equals('4.1667'));
    });

    test('Calculates rectangular mold scale factor with and without height (BR-ESC-02)', () {
      // 20x20 cm (400 cm2) -> 20x30 cm (600 cm2) = 1.50
      final factor2D = ScalingEngine.calculateRectangularScaleFactor(
        lOrigin: PreciseDecimal.fromInt(20),
        wOrigin: PreciseDecimal.fromInt(20),
        lTarget: PreciseDecimal.fromInt(30),
        wTarget: PreciseDecimal.fromInt(20),
      );
      expect(factor2D.toStringAsFixed(2), equals('1.50'));

      // With height: 20x20x5 (2000 cm3) -> 30x40x6 (7200 cm3) = 3.60
      final factor3D = ScalingEngine.calculateRectangularScaleFactor(
        lOrigin: PreciseDecimal.fromInt(20),
        wOrigin: PreciseDecimal.fromInt(20),
        lTarget: PreciseDecimal.fromInt(40),
        wTarget: PreciseDecimal.fromInt(30),
        hOrigin: PreciseDecimal.fromInt(5),
        hTarget: PreciseDecimal.fromInt(6),
      );
      expect(factor3D.toStringAsFixed(2), equals('3.60'));
    });

    test('Calculates portions proportional scale factor (RF-SYS-13)', () {
      final factor = ScalingEngine.calculatePortionsScaleFactor(8, 20);
      expect(factor.toStringAsFixed(2), equals('2.50'));
    });

    test('Throws ArgumentError when dimensions or portions are <= 0', () {
      expect(
        () => ScalingEngine.calculateCircularScaleFactor(
          PreciseDecimal.zero,
          PreciseDecimal.fromInt(10),
        ),
        throwsArgumentError,
      );
      expect(
        () => ScalingEngine.calculateRectangularScaleFactor(
          lOrigin: PreciseDecimal.fromInt(20),
          wOrigin: PreciseDecimal.fromInt(-5),
          lTarget: PreciseDecimal.fromInt(30),
          wTarget: PreciseDecimal.fromInt(20),
        ),
        throwsArgumentError,
      );
      expect(
        () => ScalingEngine.calculatePortionsScaleFactor(0, 12),
        throwsArgumentError,
      );
    });
  });

  group('ScalingEngine.scaleRecipe - Ingredients, Indivisibles, Costs & Variants', () {
    test('Scales 6" recipe to 10" mold multiplying ingredients, sub-recipes and costs accurately', () {
      final baseRecipe = createSampleBaseRecipe();
      final factor = ScalingEngine.calculateCircularScaleFactor(
        PreciseDecimal.fromInt(6),
        PreciseDecimal.fromInt(10),
      ); // 2.777778

      final result = ScalingEngine.scaleRecipe(
        recipe: baseRecipe,
        scalingMode: ScalingMode.circularMold,
        scaleFactor: factor,
        businessConfig: defaultConfig,
        targetMoldType: 'Redondo',
        targetMoldDimension: '10" (25 cm)',
      );

      // 1. Check flour: 180g * (100/36) = 500.00g
      final scaledFlour = result.scaledIngredients.first;
      expect(scaledFlour.scaledQuantity.toStringAsFixed(2), equals('500.00'));
      expect(scaledFlour.isIndivisible, isFalse);
      // Flour cost: 500g * $0.005 = $2.50
      expect(scaledFlour.scaledItemCost.toStringAsFixed(2), equals('2.50'));

      // 2. Check indivisible eggs (BR-ESC-03): 1 * 2.777778 = 2.78 u -> 3 u or 138.9 g beaten egg
      final scaledEggs = result.scaledIngredients[1];
      expect(scaledEggs.isIndivisible, isTrue);
      expect(scaledEggs.hasFractionalIndivisible, isTrue);
      expect(scaledEggs.scaledQuantity.toStringAsFixed(2), equals('2.78'));
      expect(scaledEggs.roundedUpWholeUnits, equals(3));
      expect(
        scaledEggs.beatenEggGramsSuggestion!.toStringAsFixed(1),
        equals('138.9'),
      );
      expect(
        scaledEggs.indivisibleSuggestionText,
        contains('3 u ó 138.9 g de huevo batido'),
      );

      // 3. Check sub-recipe scaling: 1.0 * 2.777778 = 2.78x, cost = 3.60 * 2.777778 = $10.00
      final scaledSub = result.scaledSubRecipes.first;
      expect(scaledSub.scaledFactor.toStringAsFixed(2), equals('2.78'));
      expect(scaledSub.scaledItemCost.toStringAsFixed(2), equals('10.00'));

      // 4. Check recalculated costs (BR-ESC-04):
      // Scaled Ingredients = $2.50 (flour) + $1.00 (eggs: 2.777778 * 0.36) = $3.50
      expect(
        result.scaledCostBreakdown.rawMaterialsCost.toStringAsFixed(2),
        equals('3.50'),
      );
      expect(
        result.scaledCostBreakdown.subRecipesCost.toStringAsFixed(2),
        equals('10.00'),
      );
      // Labor time stays fixed at 60 min by default (JEF-24 Alternativa 1) -> $12.00
      expect(result.targetPrepTimeMinutes, equals(60));
      expect(
        result.scaledCostBreakdown.laborCost.toStringAsFixed(2),
        equals('12.00'),
      );

      // 5. Generate Variant Recipe (toVariantRecipe)
      int seq = 0;
      final variant = result.toVariantRecipe(
        newRecipeId: 'rec-variant-10in',
        variantName: 'Torta de Chocolate (10" / 25 cm)',
        idGenerator: () => 'id-${++seq}',
      );

      expect(variant.id, equals('rec-variant-10in'));
      expect(variant.name, equals('Torta de Chocolate (10" / 25 cm)'));
      expect(variant.moldDimension, equals('10" (25 cm)'));
      expect(
        variant.ingredients.first.quantity.toStringAsFixed(2),
        equals('500.00'),
      );
    });

    test('Supports proportional labor time scaling when requested (JEF-24)', () {
      final baseRecipe = createSampleBaseRecipe();
      final result = ScalingEngine.scaleRecipe(
        recipe: baseRecipe,
        scalingMode: ScalingMode.directMultiplier,
        scaleFactor: PreciseDecimal.fromInt(2),
        businessConfig: defaultConfig,
        scaleLaborProportionally: true,
      );

      // Base prep time = 60 min * 2 = 120 min -> $24.00 labor
      expect(result.targetPrepTimeMinutes, equals(120));
      expect(
        result.scaledCostBreakdown.laborCost.toStringAsFixed(2),
        equals('24.00'),
      );
    });

    test('MoldPreset.tryMatchFromRecipe matches standard circular and rectangular molds', () {
      final match8 = MoldPreset.tryMatchFromRecipe('Redondo', '20 cm / 8"');
      expect(match8, isNotNull);
      expect(match8!.id, equals('round_8in'));

      final matchRect =
          MoldPreset.tryMatchFromRecipe('Rectangular', '20x30 cm');
      expect(matchRect, isNotNull);
      expect(matchRect!.id, equals('rect_20x30'));
    });

    test('Calculates exact container scale factor between counts and oz capacities (RF-SYS-13)', () {
      // 12 envases de 4 oz a 24 envases de 4 oz -> 2.0000
      final factorDoubleCount = ScalingEngine.calculateContainerScaleFactor(
        originCount: 12,
        originCapacityOz: PreciseDecimal.fromInt(4),
        targetCount: 24,
        targetCapacityOz: PreciseDecimal.fromInt(4),
      );
      expect(factorDoubleCount.toStringAsFixed(4), equals('2.0000'));

      // 12 envases de 4 oz (48 oz total) a 12 envases de 6 oz (72 oz total) -> 1.5000
      final factorDifferentSize = ScalingEngine.calculateContainerScaleFactor(
        originCount: 12,
        originCapacityOz: PreciseDecimal.fromInt(4),
        targetCount: 12,
        targetCapacityOz: PreciseDecimal.fromInt(6),
      );
      expect(factorDifferentSize.toStringAsFixed(4), equals('1.5000'));

      // 10 envases de 4 oz (40 oz total) a 15 envases de 8 oz (120 oz total) -> 3.0000
      final factorComplex = ScalingEngine.calculateContainerScaleFactor(
        originCount: 10,
        originCapacityOz: PreciseDecimal.fromInt(4),
        targetCount: 15,
        targetCapacityOz: PreciseDecimal.fromInt(8),
      );
      expect(factorComplex.toStringAsFixed(4), equals('3.0000'));

      expect(
        () => ScalingEngine.calculateContainerScaleFactor(
          originCount: 0,
          originCapacityOz: PreciseDecimal.fromInt(4),
          targetCount: 10,
          targetCapacityOz: PreciseDecimal.fromInt(4),
        ),
        throwsArgumentError,
      );

      expect(
        () => ScalingEngine.calculateContainerScaleFactor(
          originCount: 12,
          originCapacityOz: PreciseDecimal.zero,
          targetCount: 10,
          targetCapacityOz: PreciseDecimal.fromInt(4),
        ),
        throwsArgumentError,
      );
    });

    test('MoldPreset.tryMatchFromRecipe matches individual presets and cupcakes', () {
      final match4oz = MoldPreset.tryMatchFromRecipe('Individual', 'Vasito 4 oz');
      expect(match4oz, isNotNull);
      expect(match4oz!.id, equals('cup_4oz'));
      expect(match4oz.volumeOz, equals(PreciseDecimal.fromInt(4)));

      final match6oz = MoldPreset.tryMatchFromRecipe('Individual', 'Vasito 6 oz (180 ml)');
      expect(match6oz, isNotNull);
      expect(match6oz!.id, equals('cup_6oz'));

      final matchCupcake = MoldPreset.tryMatchFromRecipe('Cupcakes / Muffins', 'Cupcake Estándar');
      expect(matchCupcake, isNotNull);
      expect(matchCupcake!.id, equals('cupcake_std'));
    });
  });
}
