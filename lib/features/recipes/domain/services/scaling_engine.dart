import '../../../../core/utils/precise_decimal.dart';
import '../../../costing/domain/services/costing_calculation_engine.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../entities/mold_preset.dart';
import '../entities/recipe.dart';
import '../entities/recipe_item.dart';
import '../entities/scaled_recipe_result.dart';

/// Pure geometric and proportional recipe scaling engine (JEF-14, RF-SYS-12, RF-SYS-13, BR-ESC-01..04).
class ScalingEngine {
  const ScalingEngine._();

  /// Standard weight of 1 whole medium/large beaten egg in grams (BR-ESC-03).
  static final PreciseDecimal standardEggWeightGrams =
      PreciseDecimal.fromInt(50);

  /// High-precision Pi constant for cross-shape (circular <-> rectangular) area/volume comparisons.
  static final PreciseDecimal pi = PreciseDecimal.fromString('3.141593');

  /// Calculates the geometric scale factor between two circular molds (RF-SYS-13):
  /// - Equal height: `Factor = (dTarget^2) / (dOrigin^2)`
  /// - Variable height: `Factor = (dTarget^2 * hTarget) / (dOrigin^2 * hOrigin)`
  ///
  /// Uses exact algebraic ratio without intermediate rounding (RNF-02).
  static PreciseDecimal calculateCircularScaleFactor(
    PreciseDecimal dOrigin,
    PreciseDecimal dTarget, {
    PreciseDecimal? hOrigin,
    PreciseDecimal? hTarget,
  }) {
    if (dOrigin <= PreciseDecimal.zero || dTarget <= PreciseDecimal.zero) {
      throw ArgumentError(
        'Los diámetros de molde deben ser mayores a cero.',
      );
    }

    final originAreaRatio = dOrigin * dOrigin;
    final targetAreaRatio = dTarget * dTarget;

    if (hOrigin != null && hTarget != null) {
      if (hOrigin <= PreciseDecimal.zero || hTarget <= PreciseDecimal.zero) {
        throw ArgumentError(
          'Las alturas de molde deben ser mayores a cero.',
        );
      }
      return (targetAreaRatio * hTarget) / (originAreaRatio * hOrigin);
    }

    return targetAreaRatio / originAreaRatio;
  }

  /// Calculates the geometric scale factor between two rectangular/square molds (RF-SYS-13, BR-ESC-02):
  /// - Equal height: `Factor = (lTarget * wTarget) / (lOrigin * wOrigin)`
  /// - Variable height: `Factor = (lTarget * wTarget * hTarget) / (lOrigin * wOrigin * hOrigin)`
  static PreciseDecimal calculateRectangularScaleFactor({
    required PreciseDecimal lOrigin,
    required PreciseDecimal wOrigin,
    required PreciseDecimal lTarget,
    required PreciseDecimal wTarget,
    PreciseDecimal? hOrigin,
    PreciseDecimal? hTarget,
  }) {
    if (lOrigin <= PreciseDecimal.zero ||
        wOrigin <= PreciseDecimal.zero ||
        lTarget <= PreciseDecimal.zero ||
        wTarget <= PreciseDecimal.zero) {
      throw ArgumentError(
        'El largo y ancho de los moldes deben ser mayores a cero.',
      );
    }

    final originArea = lOrigin * wOrigin;
    final targetArea = lTarget * wTarget;

    if (hOrigin != null && hTarget != null) {
      if (hOrigin <= PreciseDecimal.zero || hTarget <= PreciseDecimal.zero) {
        throw ArgumentError(
          'Las alturas de molde deben ser mayores a cero.',
        );
      }
      return (targetArea * hTarget) / (originArea * hOrigin);
    }

    return targetArea / originArea;
  }

  /// Calculates the proportional scale factor based on desired portions (RF-SYS-13, BR-ESC-02):
  /// `Factor = targetPortions / originPortions`
  static PreciseDecimal calculatePortionsScaleFactor(
    int originPortions,
    int targetPortions,
  ) {
    if (originPortions <= 0 || targetPortions <= 0) {
      throw ArgumentError(
        'El número de porciones debe ser mayor a cero.',
      );
    }
    return PreciseDecimal.fromInt(targetPortions) /
        PreciseDecimal.fromInt(originPortions);
  }

  /// Calculates the scale factor between individual container volumes and counts (RF-SYS-13):
  /// `Factor = (targetCount * targetCapacityOz) / (originCount * originCapacityOz)`
  static PreciseDecimal calculateContainerScaleFactor({
    required int originCount,
    required PreciseDecimal originCapacityOz,
    required int targetCount,
    required PreciseDecimal targetCapacityOz,
  }) {
    if (originCount <= 0 || targetCount <= 0) {
      throw ArgumentError(
        'La cantidad de envases debe ser mayor a cero.',
      );
    }
    if (originCapacityOz <= PreciseDecimal.zero ||
        targetCapacityOz <= PreciseDecimal.zero) {
      throw ArgumentError(
        'La capacidad de los envases debe ser mayor a cero.',
      );
    }
    final originTotalVolume =
        PreciseDecimal.fromInt(originCount) * originCapacityOz;
    final targetTotalVolume =
        PreciseDecimal.fromInt(targetCount) * targetCapacityOz;
    return targetTotalVolume / originTotalVolume;
  }

  /// Determines whether an ingredient item is measured in indivisible whole units (BR-ESC-03).
  static bool isIndivisibleIngredient(RecipeIngredientItem item) {
    final normUnit = item.unit.trim().toLowerCase();
    final normBase = (item.baseUnit ?? '').trim().toLowerCase();
    return normUnit == 'u' ||
        normUnit == 'unidad' ||
        normUnit == 'unidades' ||
        normUnit == 'pza' ||
        normUnit == 'pieza' ||
        normUnit == 'piezas' ||
        (normBase == 'unidad' && (normUnit == 'u' || normUnit == 'unidad'));
  }

  /// Determines whether an indivisible ingredient is an egg (to suggest grams of beaten egg per BR-ESC-03).
  static bool isEggIngredient(RecipeIngredientItem item) {
    final normName = item.ingredientName.trim().toLowerCase();
    return normName.contains('huevo') || normName.contains('egg');
  }

  /// Executes a full geometric/proportional scaling of [recipe] by [scaleFactor]
  /// and recalculates all direct, indirect, labor, and dual pricing metrics (BR-ESC-01..04, JEF-24).
  static ScaledRecipeResult scaleRecipe({
    required Recipe recipe,
    required ScalingMode scalingMode,
    required PreciseDecimal scaleFactor,
    required BusinessConfig businessConfig,
    int? targetYieldPortionsOverride,
    String? targetMoldType,
    String? targetMoldDimension,
    int? customPrepTimeMinutes,
    bool scaleLaborProportionally = false,
    bool scalePackagingProportionally = false,
  }) {
    if (scaleFactor <= PreciseDecimal.zero) {
      throw ArgumentError('El factor de escalado debe ser mayor a cero.');
    }

    // 1. Scale direct ingredients (BR-ESC-01, BR-ESC-03)
    final scaledIngredients = <ScaledIngredientItem>[];

    for (final item in recipe.ingredients) {
      final scaledQty = item.quantity * scaleFactor;
      final tempItem = item.copyWith(quantity: scaledQty);
      final scaledCost = tempItem.calculateItemCost();

      final indivisible = isIndivisibleIngredient(item);
      int? roundedUpUnits;
      PreciseDecimal? beatenEggGrams;

      if (indivisible) {
        roundedUpUnits = int.parse(scaledQty.ceil().toStringAsFixed(0));
        if (isEggIngredient(item)) {
          beatenEggGrams = scaledQty * standardEggWeightGrams;
        }
      }

      scaledIngredients.add(
        ScaledIngredientItem(
          originalItem: item,
          scaledQuantity: scaledQty,
          scaledItemCost: scaledCost,
          isIndivisible: indivisible,
          roundedUpWholeUnits: roundedUpUnits,
          beatenEggGramsSuggestion: beatenEggGrams,
        ),
      );
    }

    // 2. Scale modular sub-recipes (BR-ESC-01)
    final scaledSubRecipes = <ScaledSubRecipeItem>[];

    for (final sub in recipe.subRecipes) {
      final scaledSubFactor = sub.quantityFactor * scaleFactor;
      final scaledSubCost = scaledSubFactor * sub.unitCost;

      scaledSubRecipes.add(
        ScaledSubRecipeItem(
          originalItem: sub,
          scaledFactor: scaledSubFactor,
          scaledItemCost: scaledSubCost,
        ),
      );
    }

    // 3. Scale packaging items (optional proportional scaling or keep 1x)
    final scaledPackaging = <ScaledPackagingItem>[];

    for (final pack in recipe.packaging) {
      final int scaledPieces;
      if (scalePackagingProportionally) {
        final rawPieces =
            PreciseDecimal.fromInt(pack.pieceQuantity) * scaleFactor;
        final ceilInt = int.parse(rawPieces.ceil().toStringAsFixed(0));
        scaledPieces = ceilInt < 1 ? 1 : ceilInt;
      } else {
        scaledPieces = pack.pieceQuantity;
      }
      final scaledPackCost =
          PreciseDecimal.fromInt(scaledPieces) * pack.unitCost;

      scaledPackaging.add(
        ScaledPackagingItem(
          originalItem: pack,
          scaledPieceQuantity: scaledPieces,
          scaledItemCost: scaledPackCost,
        ),
      );
    }

    // 4. Determine target yield portions
    final int targetYieldPortions;
    if (targetYieldPortionsOverride != null &&
        targetYieldPortionsOverride > 0) {
      targetYieldPortions = targetYieldPortionsOverride;
    } else {
      final rawPortions =
          PreciseDecimal.fromInt(recipe.yieldPortions) * scaleFactor;
      final roundedPortions =
          double.parse(rawPortions.toStringAsFixed(2)).round();
      targetYieldPortions = roundedPortions < 1 ? 1 : roundedPortions;
    }

    // 5. Determine target preparation time (JEF-24: fixed by default with manual/proportional option)
    final int targetPrepTimeMinutes;
    if (customPrepTimeMinutes != null && customPrepTimeMinutes >= 0) {
      targetPrepTimeMinutes = customPrepTimeMinutes;
    } else if (scaleLaborProportionally) {
      final rawPrep =
          PreciseDecimal.fromInt(recipe.prepTimeMinutes) * scaleFactor;
      targetPrepTimeMinutes = double.parse(rawPrep.toStringAsFixed(2)).round();
    } else {
      targetPrepTimeMinutes = recipe.prepTimeMinutes;
    }

    // 6. Calculate original CostBreakdown
    final originalCostBreakdown = CostingCalculationEngine.calculate(
      recipe: recipe,
      config: businessConfig,
    );

    // 7. Calculate scaled CostBreakdown (BR-ESC-04)
    // Clear manual price overrides so suggested prices reflect the new scaled batch & portion costs
    final scaledPricingStrategy = recipe.pricingStrategy.copyWith(
      clearCustomBatchPrice: true,
      clearCustomPortionPrice: true,
    );

    final tempScaledRecipe = recipe.copyWith(
      yieldPortions: targetYieldPortions,
      prepTimeMinutes: targetPrepTimeMinutes,
      clearCustomBatchPrice: true,
      clearCustomPortionPrice: true,
      ingredients: scaledIngredients
          .map(
            (i) => i.originalItem.copyWith(quantity: i.scaledQuantity),
          )
          .toList(),
      subRecipes: scaledSubRecipes
          .map(
            (s) => s.originalItem.copyWith(quantityFactor: s.scaledFactor),
          )
          .toList(),
      packaging: scaledPackaging
          .map(
            (p) => p.originalItem.copyWith(
              pieceQuantity: p.scaledPieceQuantity,
            ),
          )
          .toList(),
    );

    final scaledCostBreakdown = CostingCalculationEngine.calculate(
      recipe: tempScaledRecipe,
      config: businessConfig,
      pricingStrategyOverride: scaledPricingStrategy,
      yieldPortionsOverride: targetYieldPortions,
      prepTimeMinutesOverride: targetPrepTimeMinutes,
    );

    return ScaledRecipeResult(
      originalRecipe: recipe,
      scalingMode: scalingMode,
      scaleFactor: scaleFactor,
      targetYieldPortions: targetYieldPortions,
      targetMoldType: targetMoldType ?? recipe.moldType,
      targetMoldDimension: targetMoldDimension ?? recipe.moldDimension,
      targetPrepTimeMinutes: targetPrepTimeMinutes,
      targetBakeTimeMinutes: recipe.bakeTimeMinutes,
      scaledIngredients: scaledIngredients,
      scaledSubRecipes: scaledSubRecipes,
      scaledPackaging: scaledPackaging,
      originalCostBreakdown: originalCostBreakdown,
      scaledCostBreakdown: scaledCostBreakdown,
    );
  }
}
