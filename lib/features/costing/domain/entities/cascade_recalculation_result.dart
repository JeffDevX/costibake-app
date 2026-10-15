import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../recipes/domain/entities/recipe.dart';

/// Represents the summary result of a cascade price recalculation
/// across the recipe dependency graph (JEF-9, RF-SYS-04, BR-PRC-01..04, RNF-04).
class CascadeRecalculationResult extends Equatable {
  final String ingredientId;
  final String ingredientName;
  final PreciseDecimal? oldCost;
  final PreciseDecimal newCost;
  final List<String> affectedRecipeIds;
  final List<String> affectedRecipeNames;
  final List<Recipe> recalculatedRecipes;
  final int elapsedMilliseconds;
  final DateTime timestamp;

  const CascadeRecalculationResult({
    required this.ingredientId,
    required this.ingredientName,
    this.oldCost,
    required this.newCost,
    required this.affectedRecipeIds,
    required this.affectedRecipeNames,
    this.recalculatedRecipes = const [],
    required this.elapsedMilliseconds,
    required this.timestamp,
  });

  int get affectedCount => affectedRecipeIds.length;

  /// User-facing notification message compliant with BR-PRC-04.
  String get userNotificationMessage {
    if (affectedCount == 0) {
      return 'Insumo "$ingredientName" actualizado exitosamente.';
    }
    final suffix = affectedCount == 1 ? 'receta fue recalculada' : 'recetas fueron recalculadas';
    return 'Precio de $ingredientName actualizado. $affectedCount $suffix exitosamente.';
  }

  @override
  List<Object?> get props => [
        ingredientId,
        ingredientName,
        oldCost,
        newCost,
        affectedRecipeIds,
        affectedRecipeNames,
        recalculatedRecipes,
        elapsedMilliseconds,
        timestamp,
      ];
}
