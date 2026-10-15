import '../../../../core/utils/precise_decimal.dart';
import '../../../recipes/domain/entities/recipe.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../entities/cost_breakdown.dart';
import 'costing_calculation_engine.dart';

/// Pure domain algorithm engine for resolving Directed Acyclic Graph (DAG) dependencies
/// and computing topological cascade recalculation across recipes (JEF-9, RF-SYS-04, RNF-04, RNF-02).
class CascadeRecalculationEngine {
  const CascadeRecalculationEngine._();

  /// Identifies all recipes directly or transitively affected by an ingredient modification (BR-PRC-02).
  ///
  /// [changedIngredientId]: ID of the modified catalog ingredient.
  /// [recipeToIngredientMap]: Map from recipeId to the list of ingredient IDs it contains.
  /// [parentToChildSubRecipeMap]: Map from parentRecipeId to list of childRecipeIds.
  static Set<String> findAffectedRecipeIds({
    required String changedIngredientId,
    required Map<String, List<String>> recipeToIngredientMap,
    required Map<String, List<String>> parentToChildSubRecipeMap,
  }) {
    // 1. Direct dependencies: recipes containing the changed ingredient
    final direct = <String>{};
    recipeToIngredientMap.forEach((recipeId, ingredients) {
      if (ingredients.contains(changedIngredientId)) {
        direct.add(recipeId);
      }
    });

    if (direct.isEmpty) {
      return const {};
    }

    // 2. Invert sub-recipe graph (child -> parents that consume it)
    final childToParentMap = <String, List<String>>{};
    parentToChildSubRecipeMap.forEach((parentId, children) {
      for (final childId in children) {
        childToParentMap.putIfAbsent(childId, () => []).add(parentId);
      }
    });

    // 3. Upward transitive closure (DAG traversal) to collect all affected ancestor recipes
    final affected = Set<String>.from(direct);
    final queue = List<String>.from(direct);

    while (queue.isNotEmpty) {
      final currentChild = queue.removeAt(0);
      final parents = childToParentMap[currentChild] ?? const [];
      for (final parent in parents) {
        if (affected.add(parent)) {
          queue.add(parent);
        }
      }
    }

    return affected;
  }

  /// Identifies all recipes directly or transitively affected by a packaging modification.
  static Set<String> findAffectedRecipeIdsForPackaging({
    required String changedPackagingId,
    required Map<String, List<String>> recipeToPackagingMap,
    required Map<String, List<String>> parentToChildSubRecipeMap,
  }) {
    final direct = <String>{};
    recipeToPackagingMap.forEach((recipeId, packagings) {
      if (packagings.contains(changedPackagingId)) {
        direct.add(recipeId);
      }
    });

    if (direct.isEmpty) return const {};

    final childToParentMap = <String, List<String>>{};
    parentToChildSubRecipeMap.forEach((parentId, children) {
      for (final childId in children) {
        childToParentMap.putIfAbsent(childId, () => []).add(parentId);
      }
    });

    final affected = Set<String>.from(direct);
    final queue = List<String>.from(direct);

    while (queue.isNotEmpty) {
      final currentChild = queue.removeAt(0);
      final parents = childToParentMap[currentChild] ?? const [];
      for (final parent in parents) {
        if (affected.add(parent)) {
          queue.add(parent);
        }
      }
    }

    return affected;
  }

  /// Computes a Topological Sort of the [affectedRecipeIds] subgraph using Kahn's algorithm.
  /// Guarantees that any child sub-recipe is ordered BEFORE the parent recipe that depends on it.
  static List<String> topologicalSort({
    required Set<String> affectedRecipeIds,
    required Map<String, List<String>> parentToChildSubRecipeMap,
  }) {
    if (affectedRecipeIds.isEmpty) return const [];
    if (affectedRecipeIds.length == 1) return affectedRecipeIds.toList();

    // Map child -> parents in the affected set
    final childToParent = <String, List<String>>{};
    final inDegree = <String, int>{};

    for (final id in affectedRecipeIds) {
      inDegree[id] = 0;
    }

    for (final parentId in affectedRecipeIds) {
      final children = parentToChildSubRecipeMap[parentId] ?? const [];
      for (final childId in children) {
        if (affectedRecipeIds.contains(childId)) {
          childToParent.putIfAbsent(childId, () => []).add(parentId);
          inDegree[parentId] = (inDegree[parentId] ?? 0) + 1;
        }
      }
    }

    // Nodes with in-degree 0 (recipes that do not depend on any OTHER affected recipe)
    final queue = <String>[];
    for (final id in affectedRecipeIds) {
      if (inDegree[id] == 0) {
        queue.add(id);
      }
    }

    final sorted = <String>[];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      sorted.add(current);

      final parents = childToParent[current] ?? const [];
      for (final parent in parents) {
        inDegree[parent] = (inDegree[parent] ?? 1) - 1;
        if (inDegree[parent] == 0) {
          queue.add(parent);
        }
      }
    }

    // Fallback: If there are any unvisited nodes due to edge cases, append them safely
    if (sorted.length < affectedRecipeIds.length) {
      for (final id in affectedRecipeIds) {
        if (!sorted.contains(id)) {
          sorted.add(id);
        }
      }
    }

    return sorted;
  }

  /// Recalculates a single recipe's full cost breakdown, injecting updated costs
  /// for any sub-recipes evaluated earlier in the topological cascade.
  static ({Recipe updatedRecipe, CostBreakdown breakdown}) recalculateRecipe({
    required Recipe recipe,
    required BusinessConfig config,
    Map<String, PreciseDecimal> updatedChildRecipeCosts = const {},
    DateTime? updatedTimestamp,
  }) {
    // 1. Update sub-recipe item unit costs if child was recalculated in cascade
    var updatedSubRecipes = recipe.subRecipes;
    if (updatedChildRecipeCosts.isNotEmpty && recipe.subRecipes.isNotEmpty) {
      updatedSubRecipes = recipe.subRecipes.map((sub) {
        final newChildCost = updatedChildRecipeCosts[sub.childRecipeId];
        if (newChildCost != null) {
          return sub.copyWith(unitCost: newChildCost);
        }
        return sub;
      }).toList();
    }

    final updatedRecipe = recipe.copyWith(
      subRecipes: updatedSubRecipes,
      updatedAt: updatedTimestamp ?? DateTime.now(),
    );

    // 2. Compute full integral quad-component cost breakdown
    final breakdown = CostingCalculationEngine.calculate(
      recipe: updatedRecipe,
      config: config,
    );

    return (updatedRecipe: updatedRecipe, breakdown: breakdown);
  }
}
