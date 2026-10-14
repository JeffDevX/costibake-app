import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/utils/unit_converter.dart';

class RecipeIngredientItem extends Equatable {
  final String id;
  final String recipeId;
  final String ingredientId;
  final String ingredientName;
  final PreciseDecimal quantity;
  final String unit; // 'g', 'ml', 'taza', 'cda', 'cdta', etc.
  final String section; // 'Base', 'Bizcocho', 'Relleno', 'Cobertura', 'Decoración'
  final PreciseDecimal unitCost; // $/g, $/ml, or $/unidad
  final PreciseDecimal? densityGPerMl;
  final String? baseUnit; // 'g', 'ml', 'unidad'
  final String? notes;

  const RecipeIngredientItem({
    required this.id,
    required this.recipeId,
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    this.section = 'Base',
    required this.unitCost,
    this.densityGPerMl,
    this.baseUnit,
    this.notes,
  });

  /// Cost of this ingredient item in the recipe = quantity (normalized to base unit) * unitCost
  /// Conforms to RF-SYS-11 and BR-REC-03.
  PreciseDecimal calculateItemCost({PreciseDecimal? normalizedFactor}) {
    if (normalizedFactor != null) {
      return (quantity * normalizedFactor) * unitCost;
    }
    try {
      final targetUnit = baseUnit ??
          (unit.toLowerCase() == 'unidad' || unit.toLowerCase() == 'pieza'
              ? 'unidad'
              : 'g');
      final normalizedQty = UnitConverter.convertUnit(
        quantity,
        unit,
        targetUnit,
        density: densityGPerMl,
      );
      return normalizedQty * unitCost;
    } catch (_) {
      // Fallback: direct product if dimension conversion was not possible
      return quantity * unitCost;
    }
  }

  RecipeIngredientItem copyWith({
    String? id,
    String? recipeId,
    String? ingredientId,
    String? ingredientName,
    PreciseDecimal? quantity,
    String? unit,
    String? section,
    PreciseDecimal? unitCost,
    PreciseDecimal? densityGPerMl,
    String? baseUnit,
    String? notes,
  }) {
    return RecipeIngredientItem(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      ingredientId: ingredientId ?? this.ingredientId,
      ingredientName: ingredientName ?? this.ingredientName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      section: section ?? this.section,
      unitCost: unitCost ?? this.unitCost,
      densityGPerMl: densityGPerMl ?? this.densityGPerMl,
      baseUnit: baseUnit ?? this.baseUnit,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        recipeId,
        ingredientId,
        ingredientName,
        quantity,
        unit,
        section,
        unitCost,
        densityGPerMl,
        baseUnit,
        notes,
      ];
}

/// Represents an existing recipe included as a modular component/sub-recipe (RF-SYS-10).
class RecipeSubRecipeItem extends Equatable {
  final String id;
  final String parentRecipeId;
  final String childRecipeId;
  final String childRecipeName;
  final PreciseDecimal quantityFactor; // e.g. 1.0 (full recipe), 0.5 (half recipe)
  final String section; // 'Componente', 'Bizcocho', 'Relleno', etc.
  final PreciseDecimal unitCost; // Total cost of 1.0 batch of the child recipe
  final String? notes;

  const RecipeSubRecipeItem({
    required this.id,
    required this.parentRecipeId,
    required this.childRecipeId,
    required this.childRecipeName,
    required this.quantityFactor,
    this.section = 'Componente',
    required this.unitCost,
    this.notes,
  });

  /// Cost of this sub-recipe item = quantityFactor * unitCost (BR-REC-04)
  PreciseDecimal calculateItemCost() {
    return quantityFactor * unitCost;
  }

  RecipeSubRecipeItem copyWith({
    String? id,
    String? parentRecipeId,
    String? childRecipeId,
    String? childRecipeName,
    PreciseDecimal? quantityFactor,
    String? section,
    PreciseDecimal? unitCost,
    String? notes,
  }) {
    return RecipeSubRecipeItem(
      id: id ?? this.id,
      parentRecipeId: parentRecipeId ?? this.parentRecipeId,
      childRecipeId: childRecipeId ?? this.childRecipeId,
      childRecipeName: childRecipeName ?? this.childRecipeName,
      quantityFactor: quantityFactor ?? this.quantityFactor,
      section: section ?? this.section,
      unitCost: unitCost ?? this.unitCost,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        parentRecipeId,
        childRecipeId,
        childRecipeName,
        quantityFactor,
        section,
        unitCost,
        notes,
      ];
}

class RecipePackagingItem extends Equatable {
  final String id;
  final String recipeId;
  final String packagingId;
  final String packagingName;
  final int pieceQuantity;
  final PreciseDecimal unitCost;
  final String? notes;

  const RecipePackagingItem({
    required this.id,
    required this.recipeId,
    required this.packagingId,
    required this.packagingName,
    required this.pieceQuantity,
    required this.unitCost,
    this.notes,
  });

  PreciseDecimal calculateItemCost() {
    return PreciseDecimal.fromInt(pieceQuantity) * unitCost;
  }

  RecipePackagingItem copyWith({
    String? id,
    String? recipeId,
    String? packagingId,
    String? packagingName,
    int? pieceQuantity,
    PreciseDecimal? unitCost,
    String? notes,
  }) {
    return RecipePackagingItem(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      packagingId: packagingId ?? this.packagingId,
      packagingName: packagingName ?? this.packagingName,
      pieceQuantity: pieceQuantity ?? this.pieceQuantity,
      unitCost: unitCost ?? this.unitCost,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        recipeId,
        packagingId,
        packagingName,
        pieceQuantity,
        unitCost,
        notes,
      ];
}
