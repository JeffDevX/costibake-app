import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../costing/domain/entities/cost_breakdown.dart';
import 'mold_preset.dart';
import 'recipe.dart';
import 'recipe_item.dart';

/// Represents a single scaled ingredient item with exact mathematical quantity,
/// prorated cost, and kitchen-friendly suggestions for indivisible items (BR-ESC-03).
class ScaledIngredientItem extends Equatable {
  final RecipeIngredientItem originalItem;
  final PreciseDecimal scaledQuantity;
  final PreciseDecimal scaledItemCost;
  final bool isIndivisible;
  final int? roundedUpWholeUnits;
  final PreciseDecimal? beatenEggGramsSuggestion;

  const ScaledIngredientItem({
    required this.originalItem,
    required this.scaledQuantity,
    required this.scaledItemCost,
    required this.isIndivisible,
    this.roundedUpWholeUnits,
    this.beatenEggGramsSuggestion,
  });

  /// Returns true when the scaled quantity has a non-zero fractional remainder
  /// on an indivisible unit (e.g. 2.78 whole eggs).
  bool get hasFractionalIndivisible {
    if (!isIndivisible || roundedUpWholeUnits == null) return false;
    return scaledQuantity != PreciseDecimal.fromInt(roundedUpWholeUnits!);
  }

  /// Human-readable culinary suggestion for indivisible items (BR-ESC-03).
  String? get indivisibleSuggestionText {
    if (!hasFractionalIndivisible) return null;
    if (beatenEggGramsSuggestion != null) {
      return 'Sugerencia: $roundedUpWholeUnits ${originalItem.unit} '
          'ó ${beatenEggGramsSuggestion!.toStringAsFixed(1)} g de huevo batido';
    }
    return 'Sugerencia: Redondear a $roundedUpWholeUnits ${originalItem.unit}';
  }

  RecipeIngredientItem toRecipeIngredientItem({
    required String newId,
    required String newRecipeId,
  }) {
    return originalItem.copyWith(
      id: newId,
      recipeId: newRecipeId,
      quantity: scaledQuantity,
    );
  }

  @override
  List<Object?> get props => [
        originalItem,
        scaledQuantity,
        scaledItemCost,
        isIndivisible,
        roundedUpWholeUnits,
        beatenEggGramsSuggestion,
      ];
}

/// Represents a scaled modular sub-recipe component (BR-ESC-01).
class ScaledSubRecipeItem extends Equatable {
  final RecipeSubRecipeItem originalItem;
  final PreciseDecimal scaledFactor;
  final PreciseDecimal scaledItemCost;

  const ScaledSubRecipeItem({
    required this.originalItem,
    required this.scaledFactor,
    required this.scaledItemCost,
  });

  RecipeSubRecipeItem toRecipeSubRecipeItem({
    required String newId,
    required String newRecipeId,
  }) {
    return originalItem.copyWith(
      id: newId,
      parentRecipeId: newRecipeId,
      quantityFactor: scaledFactor,
    );
  }

  @override
  List<Object?> get props => [
        originalItem,
        scaledFactor,
        scaledItemCost,
      ];
}

/// Represents a scaled packaging item.
class ScaledPackagingItem extends Equatable {
  final RecipePackagingItem originalItem;
  final int scaledPieceQuantity;
  final PreciseDecimal scaledItemCost;

  const ScaledPackagingItem({
    required this.originalItem,
    required this.scaledPieceQuantity,
    required this.scaledItemCost,
  });

  RecipePackagingItem toRecipePackagingItem({
    required String newId,
    required String newRecipeId,
  }) {
    return originalItem.copyWith(
      id: newId,
      recipeId: newRecipeId,
      pieceQuantity: scaledPieceQuantity,
    );
  }

  @override
  List<Object?> get props => [
        originalItem,
        scaledPieceQuantity,
        scaledItemCost,
      ];
}

/// Immutable DTO holding both the original recipe and the resulting geometric/proportional
/// scaled recipe data, including recalculated costs and dual pricing (JEF-14, RF-SYS-13, BR-ESC-01..04).
class ScaledRecipeResult extends Equatable {
  final Recipe originalRecipe;
  final ScalingMode scalingMode;
  final PreciseDecimal scaleFactor;
  final int targetYieldPortions;
  final String? targetMoldType;
  final String? targetMoldDimension;
  final int targetPrepTimeMinutes;
  final int targetBakeTimeMinutes;
  final List<ScaledIngredientItem> scaledIngredients;
  final List<ScaledSubRecipeItem> scaledSubRecipes;
  final List<ScaledPackagingItem> scaledPackaging;
  final CostBreakdown originalCostBreakdown;
  final CostBreakdown scaledCostBreakdown;

  const ScaledRecipeResult({
    required this.originalRecipe,
    required this.scalingMode,
    required this.scaleFactor,
    required this.targetYieldPortions,
    this.targetMoldType,
    this.targetMoldDimension,
    required this.targetPrepTimeMinutes,
    required this.targetBakeTimeMinutes,
    required this.scaledIngredients,
    required this.scaledSubRecipes,
    required this.scaledPackaging,
    required this.originalCostBreakdown,
    required this.scaledCostBreakdown,
  });

  /// Builds a new [Recipe] entity from the scaled values so it can be persisted
  /// as an independent recipe variant (e.g. "Torta Chocolate 10 pulgadas").
  Recipe toVariantRecipe({
    required String newRecipeId,
    required String variantName,
    required String Function() idGenerator,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return originalRecipe.copyWith(
      id: newRecipeId,
      name: variantName.trim(),
      yieldPortions: targetYieldPortions,
      prepTimeMinutes: targetPrepTimeMinutes,
      bakeTimeMinutes: targetBakeTimeMinutes,
      moldType: targetMoldType ?? originalRecipe.moldType,
      moldDimension: targetMoldDimension ?? originalRecipe.moldDimension,
      clearCustomBatchPrice: true,
      clearCustomPortionPrice: true,
      createdAt: now,
      updatedAt: now,
      ingredients: scaledIngredients
          .map(
            (i) => i.toRecipeIngredientItem(
              newId: idGenerator(),
              newRecipeId: newRecipeId,
            ),
          )
          .toList(),
      subRecipes: scaledSubRecipes
          .map(
            (s) => s.toRecipeSubRecipeItem(
              newId: idGenerator(),
              newRecipeId: newRecipeId,
            ),
          )
          .toList(),
      packaging: scaledPackaging
          .map(
            (p) => p.toRecipePackagingItem(
              newId: idGenerator(),
              newRecipeId: newRecipeId,
            ),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        originalRecipe,
        scalingMode,
        scaleFactor,
        targetYieldPortions,
        targetMoldType,
        targetMoldDimension,
        targetPrepTimeMinutes,
        targetBakeTimeMinutes,
        scaledIngredients,
        scaledSubRecipes,
        scaledPackaging,
        originalCostBreakdown,
        scaledCostBreakdown,
      ];
}
