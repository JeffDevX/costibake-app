import '../errors/exceptions.dart';

/// Directed Acyclic Graph (DAG) validator to enforce business rule BR-REC-05:
/// Prevents cyclic dependencies when nesting sub-recipes.
class RecipeCycleDetector {
  const RecipeCycleDetector._();

  /// Validates whether adding [childRecipeId] as a sub-recipe into [parentRecipeId]
  /// would introduce a circular dependency (BR-REC-05).
  ///
  /// [dependencyGraph] maps each recipe ID to the list of its child sub-recipe IDs.
  /// Throws [CircularRecipeDependencyException] if a cycle would be created.
  static void validateNoCycle({
    required String parentRecipeId,
    required String childRecipeId,
    required Map<String, List<String>> dependencyGraph,
  }) {
    if (parentRecipeId == childRecipeId) {
      throw CircularRecipeDependencyException(
        parentRecipeId: parentRecipeId,
        childRecipeId: childRecipeId,
        message:
            'Una receta no puede incluirse a sí misma como sub-receta directa.',
      );
    }

    // Check if parentRecipeId is reachable starting from childRecipeId
    final visited = <String>{};
    final queue = <String>[childRecipeId];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (current == parentRecipeId) {
        throw CircularRecipeDependencyException(
          parentRecipeId: parentRecipeId,
          childRecipeId: childRecipeId,
          message:
              'Referencia circular detectada: la receta "$childRecipeId" ya depende (directa o indirectamente) de "$parentRecipeId".',
        );
      }
      if (visited.add(current)) {
        final children = dependencyGraph[current] ?? const [];
        for (final child in children) {
          if (!visited.contains(child)) {
            queue.add(child);
          }
        }
      }
    }
  }

  /// Returns true if [candidateChildId] can be added to [parentRecipeId] without cycles.
  static bool canAddSubRecipe({
    required String parentRecipeId,
    required String candidateChildId,
    required Map<String, List<String>> dependencyGraph,
  }) {
    try {
      validateNoCycle(
        parentRecipeId: parentRecipeId,
        childRecipeId: candidateChildId,
        dependencyGraph: dependencyGraph,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
