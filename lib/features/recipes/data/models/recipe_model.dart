import '../../../../core/utils/precise_decimal.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_item.dart';

class RecipeModel extends Recipe {
  const RecipeModel({
    required super.id,
    required super.name,
    super.description,
    required super.yieldPortions,
    required super.prepTimeMinutes,
    required super.bakeTimeMinutes,
    super.moldType,
    super.moldDimension,
    super.laborHourlyRateOverride,
    super.overheadPercentageOverride,
    required super.targetProfitMargin,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.ingredients = const [],
    super.subRecipes = const [],
    super.packaging = const [],
  });

  factory RecipeModel.fromEntity(Recipe entity) {
    return RecipeModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      yieldPortions: entity.yieldPortions,
      prepTimeMinutes: entity.prepTimeMinutes,
      bakeTimeMinutes: entity.bakeTimeMinutes,
      moldType: entity.moldType,
      moldDimension: entity.moldDimension,
      laborHourlyRateOverride: entity.laborHourlyRateOverride,
      overheadPercentageOverride: entity.overheadPercentageOverride,
      targetProfitMargin: entity.targetProfitMargin,
      status: entity.status,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      ingredients: entity.ingredients,
      subRecipes: entity.subRecipes,
      packaging: entity.packaging,
    );
  }

  factory RecipeModel.fromMap(
    Map<String, dynamic> map, {
    List<RecipeIngredientItem> ingredients = const [],
    List<RecipeSubRecipeItem> subRecipes = const [],
    List<RecipePackagingItem> packaging = const [],
  }) {
    return RecipeModel(
      id: map['id'] as String,
      name: map['nombre'] as String,
      description: map['descripcion'] as String?,
      yieldPortions: map['porciones_rendimiento'] as int,
      prepTimeMinutes: map['tiempo_preparacion_minutos'] as int,
      bakeTimeMinutes: map['tiempo_horneado_minutos'] as int,
      moldType: map['tamano_molde_tipo'] as String?,
      moldDimension: map['tamano_molde_dimension'] as String?,
      laborHourlyRateOverride: map['tarifa_mano_obra_hora'] != null
          ? PreciseDecimal.tryParse(map['tarifa_mano_obra_hora'] as String)
          : null,
      overheadPercentageOverride: map['porcentaje_overhead'] != null
          ? PreciseDecimal.tryParse(map['porcentaje_overhead'] as String)
          : null,
      targetProfitMargin:
          PreciseDecimal.fromString(map['margen_ganancia_porcentaje'] as String),
      status: map['estado'] as String,
      createdAt: DateTime.parse(map['fecha_creacion'] as String),
      updatedAt: DateTime.parse(map['fecha_actualizacion'] as String),
      ingredients: ingredients,
      subRecipes: subRecipes,
      packaging: packaging,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': name,
      'descripcion': description,
      'porciones_rendimiento': yieldPortions,
      'tiempo_preparacion_minutos': prepTimeMinutes,
      'tiempo_horneado_minutos': bakeTimeMinutes,
      'tamano_molde_tipo': moldType,
      'tamano_molde_dimension': moldDimension,
      'tarifa_mano_obra_hora': laborHourlyRateOverride?.toStringAsFixed(4),
      'porcentaje_overhead': overheadPercentageOverride?.toStringAsFixed(4),
      'margen_ganancia_porcentaje': targetProfitMargin.toStringAsFixed(4),
      'estado': status,
      'fecha_creacion': createdAt.toIso8601String(),
      'fecha_actualizacion': updatedAt.toIso8601String(),
    };
  }
}
