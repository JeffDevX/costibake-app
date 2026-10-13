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
  final PreciseDecimal targetProfitMargin; // e.g. 40.0%
  final String status; // 'ACTIVA', 'BORRADOR', 'INCOMPLETA_REQUIERE_REVISION'
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RecipeIngredientItem> ingredients;
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
    required this.targetProfitMargin,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.ingredients = const [],
    this.packaging = const [],
  });

  bool get isActive => status == AppConstants.recipeStatusActive;
  bool get isIncomplete => status == AppConstants.recipeStatusIncomplete;
  int get totalTimeMinutes => prepTimeMinutes + bakeTimeMinutes;

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
        targetProfitMargin,
        status,
        createdAt,
        updatedAt,
        ingredients,
        packaging,
      ];
}
