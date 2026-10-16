import '../../../../core/utils/precise_decimal.dart';
import '../../domain/entities/recipe_item.dart';

class RecipeIngredientItemModel extends RecipeIngredientItem {
  const RecipeIngredientItemModel({
    required super.id,
    required super.recipeId,
    required super.ingredientId,
    required super.ingredientName,
    required super.quantity,
    required super.unit,
    super.section = 'Base',
    required super.unitCost,
    super.densityGPerMl,
    super.baseUnit,
    super.notes,
    super.isDeleted = false,
  });

  factory RecipeIngredientItemModel.fromEntity(RecipeIngredientItem entity) {
    return RecipeIngredientItemModel(
      id: entity.id,
      recipeId: entity.recipeId,
      ingredientId: entity.ingredientId,
      ingredientName: entity.ingredientName,
      quantity: entity.quantity,
      unit: entity.unit,
      section: entity.section,
      unitCost: entity.unitCost,
      densityGPerMl: entity.densityGPerMl,
      baseUnit: entity.baseUnit,
      notes: entity.notes,
      isDeleted: entity.isDeleted,
    );
  }

  factory RecipeIngredientItemModel.fromMap(Map<String, dynamic> map) {
    final deletedFlag = (map['insumo_eliminado'] as int? ?? 0) == 1;
    final rawName = (map['insumo_nombre'] as String?) ?? '';
    return RecipeIngredientItemModel(
      id: map['id'] as String,
      recipeId: map['receta_id'] as String,
      ingredientId: map['insumo_id'] as String,
      ingredientName: rawName.isEmpty && deletedFlag ? '[ELIMINADO]' : rawName,
      quantity: PreciseDecimal.fromString(map['cantidad'] as String),
      unit: map['unidad'] as String,
      section: (map['seccion'] as String?) ?? 'Base',
      unitCost: map['costo_unitario_minimo'] != null
          ? PreciseDecimal.fromString(map['costo_unitario_minimo'] as String)
          : PreciseDecimal.zero,
      densityGPerMl: map['densidad_g_ml'] != null
          ? PreciseDecimal.tryParse(map['densidad_g_ml'] as String)
          : null,
      baseUnit: map['unidad_minima'] as String?,
      notes: map['notas'] as String?,
      isDeleted: deletedFlag || rawName.toUpperCase().contains('[ELIMINADO]'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receta_id': recipeId,
      'insumo_id': ingredientId,
      'cantidad': quantity.toStringAsFixed(4),
      'unidad': unit,
      'seccion': section,
      'notas': notes,
    };
  }
}

class RecipeSubRecipeItemModel extends RecipeSubRecipeItem {
  const RecipeSubRecipeItemModel({
    required super.id,
    required super.parentRecipeId,
    required super.childRecipeId,
    required super.childRecipeName,
    required super.quantityFactor,
    super.section = 'Componente',
    required super.unitCost,
    super.notes,
  });

  factory RecipeSubRecipeItemModel.fromEntity(RecipeSubRecipeItem entity) {
    return RecipeSubRecipeItemModel(
      id: entity.id,
      parentRecipeId: entity.parentRecipeId,
      childRecipeId: entity.childRecipeId,
      childRecipeName: entity.childRecipeName,
      quantityFactor: entity.quantityFactor,
      section: entity.section,
      unitCost: entity.unitCost,
      notes: entity.notes,
    );
  }

  factory RecipeSubRecipeItemModel.fromMap(Map<String, dynamic> map) {
    return RecipeSubRecipeItemModel(
      id: map['id'] as String,
      parentRecipeId: map['receta_padre_id'] as String,
      childRecipeId: map['receta_hija_id'] as String,
      childRecipeName: (map['receta_hija_nombre'] as String?) ?? '',
      quantityFactor: PreciseDecimal.fromString(map['cantidad_factor'] as String),
      section: (map['seccion'] as String?) ?? 'Componente',
      unitCost: map['costo_total_hija'] != null
          ? PreciseDecimal.fromString(map['costo_total_hija'] as String)
          : PreciseDecimal.zero,
      notes: map['notas'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receta_padre_id': parentRecipeId,
      'receta_hija_id': childRecipeId,
      'cantidad_factor': quantityFactor.toStringAsFixed(4),
      'seccion': section,
      'notas': notes,
    };
  }
}

class RecipePackagingItemModel extends RecipePackagingItem {
  const RecipePackagingItemModel({
    required super.id,
    required super.recipeId,
    required super.packagingId,
    required super.packagingName,
    required super.pieceQuantity,
    required super.unitCost,
    super.notes,
    super.isDeleted = false,
  });

  factory RecipePackagingItemModel.fromEntity(RecipePackagingItem entity) {
    return RecipePackagingItemModel(
      id: entity.id,
      recipeId: entity.recipeId,
      packagingId: entity.packagingId,
      packagingName: entity.packagingName,
      pieceQuantity: entity.pieceQuantity,
      unitCost: entity.unitCost,
      notes: entity.notes,
      isDeleted: entity.isDeleted,
    );
  }

  factory RecipePackagingItemModel.fromMap(Map<String, dynamic> map) {
    final deletedFlag = (map['empaque_eliminado'] as int? ?? 0) == 1;
    final rawName = (map['empaque_nombre'] as String?) ?? '';
    return RecipePackagingItemModel(
      id: map['id'] as String,
      recipeId: map['receta_id'] as String,
      packagingId: map['empaque_id'] as String,
      packagingName: rawName.isEmpty && deletedFlag ? '[ELIMINADO]' : rawName,
      pieceQuantity: map['cantidad_piezas'] as int,
      unitCost: map['costo_unitario'] != null
          ? PreciseDecimal.fromString(map['costo_unitario'] as String)
          : PreciseDecimal.zero,
      notes: map['notas'] as String?,
      isDeleted: deletedFlag || rawName.toUpperCase().contains('[ELIMINADO]'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receta_id': recipeId,
      'empaque_id': packagingId,
      'cantidad_piezas': pieceQuantity,
      'notas': notes,
    };
  }
}
