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
  final String? moldType; // 'Redondo', 'Rectangular', 'Plancha'\n  final String? moldDimension; // '20 cm / 8 in', '24 cm / 9.5 in'\n  final PreciseDecimal targetProfitMargin; // e.g. 40.0%\n  final String status; // 'ACTIVA', 'BORRADOR', 'INCOMPLETA_REQUIERE_REVISION'\n  final DateTime createdAt;\n  final DateTime updatedAt;\n  final List<RecipeIngredientItem> ingredients;\n  final List<RecipePackagingItem> packaging;\n\n  const Recipe({\n    required this.id,\n    required this.name,\n    this.description,\n    required this.yieldPortions,\n    required this.prepTimeMinutes,\n    required this.bakeTimeMinutes,\n    this.moldType,\n    this.moldDimension,\n    required this.targetProfitMargin,\n    required this.status,\n    required this.createdAt,\n    required this.updatedAt,\n    this.ingredients = const [],\n    this.packaging = const [],\n  });\n\n  bool get isActive => status == AppConstants.recipeStatusActive;\n  bool get isIncomplete => status == AppConstants.recipeStatusIncomplete;\n  int get totalTimeMinutes => prepTimeMinutes + bakeTimeMinutes;\n\n  @override\n  List<Object?> get props => [\n        id,\n        name,\n        description,\n        yieldPortions,\n        prepTimeMinutes,\n        bakeTimeMinutes,\n        moldType,\n        moldDimension,\n        targetProfitMargin,\n        status,\n        createdAt,\n        updatedAt,\n        ingredients,\n        packaging,\n      ];\n}\n