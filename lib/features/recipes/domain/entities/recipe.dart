import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/precise_decimal.dart';
import 'recipe_item.dart';

class Recipe extends Equatable {
  final String id;
  final String name;
  final String? description;
  final int yieldPortions;
  final int prepTimeMinutes;
  final int bakeTimeMinutes;
  final String? moldType; // 'Redondo', 'Rectangular', 'Plancha'
  final String? moldDimension; // '20 cm / 8 in', '24 cm / 9.5 in'
  final PreciseDecimal? laborHourlyRateOverride; // Nullable: inherits from business config if null (RF-SYS-16)
  final PreciseDecimal? overheadPercentageOverride; // Nullable: inherits from business config if null (RF-SYS-15)
  final PreciseDecimal targetProfitMargin; // e.g. 40.0%
  final String status; // 'ACTIVA', 'BORRADOR', 'INCOMPLETA_REQUIERE_REVISION'
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RecipeIngredientItem> ingredients;
  final List<RecipeSubRecipeItem> subRecipes;
  final List<RecipePackagingItem> packaging;

  const Recipe({
    required this.id,
    required this.name,
    this.description,
    required this.yieldPortions,
    required this.prepTimeMinutes,
    required this.bakeTimeMinutes,
    this.moldType,
    this.moldDimension,
    this.laborHourlyRateOverride,
    this.overheadPercentageOverride,
    required this.targetProfitMargin,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.ingredients = const [],
    this.subRecipes = const [],
    this.packaging = const [],
  });

  bool get isActive => status == AppConstants.recipeStatusActive;
  bool get isIncomplete => status == AppConstants.recipeStatusIncomplete;
  int get totalTimeMinutes => prepTimeMinutes + bakeTimeMinutes;

  /// Sum of all direct ingredient costs in this recipe (RF-SYS-11, BR-REC-03).
  PreciseDecimal get totalIngredientsCost {
    PreciseDecimal total = PreciseDecimal.zero;
    for (final ing in ingredients) {
      total += ing.calculateItemCost();
    }
    return total;
  }

  /// Sum of all nested sub-recipe costs prorated by their quantity factors (RF-SYS-10, BR-REC-04).
  PreciseDecimal get totalSubRecipesCost {
    PreciseDecimal total = PreciseDecimal.zero;
    for (final sub in subRecipes) {
      total += sub.calculateItemCost();
    }
    return total;
  }

  /// Sum of all packaging costs (boxes, boards, ribbons) directly allocated (RF-SYS-09).
  PreciseDecimal get totalPackagingCost {
    PreciseDecimal total = PreciseDecimal.zero;
    for (final pack in packaging) {
      total += pack.calculateItemCost();
    }
    return total;
  }

  /// Total direct costs (Ingredients + Sub-recipes + Packaging).
  PreciseDecimal get totalDirectCost =>
      totalIngredientsCost + totalSubRecipesCost + totalPackagingCost;

  /// Returns all unique modular sections defined across ingredients and sub-recipes.
  Set<String> get sections {
    final set = <String>{};
    for (final ing in ingredients) {
      set.add(ing.section);
    }
    for (final sub in subRecipes) {
      set.add(sub.section);
    }
    return set;
  }

  bool get hasModularComponents => subRecipes.isNotEmpty || sections.length > 1;

  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    int? yieldPortions,
    int? prepTimeMinutes,
    int? bakeTimeMinutes,
    String? moldType,
    String? moldDimension,
    PreciseDecimal? laborHourlyRateOverride,
    PreciseDecimal? overheadPercentageOverride,
    PreciseDecimal? targetProfitMargin,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RecipeIngredientItem>? ingredients,
    List<RecipeSubRecipeItem>? subRecipes,
    List<RecipePackagingItem>? packaging,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      yieldPortions: yieldPortions ?? this.yieldPortions,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      bakeTimeMinutes: bakeTimeMinutes ?? this.bakeTimeMinutes,
      moldType: moldType ?? this.moldType,
      moldDimension: moldDimension ?? this.moldDimension,
      laborHourlyRateOverride:
          laborHourlyRateOverride ?? this.laborHourlyRateOverride,
      overheadPercentageOverride:
          overheadPercentageOverride ?? this.overheadPercentageOverride,
      targetProfitMargin: targetProfitMargin ?? this.targetProfitMargin,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ingredients: ingredients ?? this.ingredients,
      subRecipes: subRecipes ?? this.subRecipes,
      packaging: packaging ?? this.packaging,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        yieldPortions,
        prepTimeMinutes,
        bakeTimeMinutes,
        moldType,
        moldDimension,
        laborHourlyRateOverride,
        overheadPercentageOverride,
        targetProfitMargin,
        status,
        createdAt,
        updatedAt,
        ingredients,
        subRecipes,
        packaging,
      ];
}
