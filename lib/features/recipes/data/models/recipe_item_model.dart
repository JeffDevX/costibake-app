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
    required super.unitCost,
    super.notes,
  });

  factory RecipeIngredientItemModel.fromEntity(RecipeIngredientItem entity) {
    return RecipeIngredientItemModel(
      id: entity.id,
      recipeId: entity.recipeId,
      ingredientId: entity.ingredientId,
      ingredientName: entity.ingredientName,
      quantity: entity.quantity,
      unit: entity.unit,
      unitCost: entity.unitCost,
      notes: entity.notes,
    );
  }

  factory RecipeIngredientItemModel.fromMap(Map<String, dynamic> map) {
    return RecipeIngredientItemModel(
      id: map['id'] as String,
      recipeId: map['receta_id'] as String,
      ingredientId: map['insumo_id'] as String,
      ingredientName: (map['insumo_nombre'] as String?) ?? '',
      quantity: PreciseDecimal.fromString(map['cantidad'] as String),
      unit: map['unidad'] as String,
      unitCost: map['costo_unitario_minimo'] != null
          ? PreciseDecimal.fromString(map['costo_unitario_minimo'] as String)
          : PreciseDecimal.zero,
      notes: map['notas'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receta_id': recipeId,
      'insumo_id': ingredientId,
      'cantidad': quantity.toStringAsFixed(4),
      'unidad': unit,
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
    );
  }

  factory RecipePackagingItemModel.fromMap(Map<String, dynamic> map) {
    return RecipePackagingItemModel(
      id: map['id'] as String,
      recipeId: map['receta_id'] as String,
      packagingId: map['empaque_id'] as String,
      packagingName: (map['empaque_nombre'] as String?) ?? '',
      pieceQuantity: map['cantidad_piezas'] as int,
      unitCost: map['costo_unitario'] != null
          ? PreciseDecimal.fromString(map['costo_unitario'] as String)
          : PreciseDecimal.zero,
      notes: map['notas'] as String?,
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
