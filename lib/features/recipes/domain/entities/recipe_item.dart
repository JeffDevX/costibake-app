import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';

class RecipeIngredientItem extends Equatable {
  final String id;
  final String recipeId;
  final String ingredientId;
  final String ingredientName;
  final PreciseDecimal quantity;
  final String unit; // 'g', 'ml', 'taza', 'cda', 'cdta', etc.
  final PreciseDecimal unitCost;
  final String? notes;

  const RecipeIngredientItem({
    required this.id,
    required this.recipeId,
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    this.notes,
  });

  /// Cost of this ingredient item in the recipe = quantity (normalized) * unitCost
  PreciseDecimal calculateItemCost({PreciseDecimal? normalizedFactor}) {
    final factor = normalizedFactor ?? PreciseDecimal.one;
    return (quantity * factor) * unitCost;
  }

  @override
  List<Object?> get props => [
        id,
        recipeId,
        ingredientId,
        ingredientName,
        quantity,
        unit,
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
