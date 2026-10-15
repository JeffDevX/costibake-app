import '../entities/recipe.dart';

abstract class RecipeRepository {
  Future<List<Recipe>> getAllRecipes();
  Future<Recipe?> getRecipeById(String id);
  Future<List<Recipe>> searchRecipes(String query, {String? status});
  Future<void> saveRecipe(Recipe recipe);
  Future<void> deleteRecipe(String id);
  Future<void> updateRecipeStatus(String recipeId, String newStatus);

  /// Returns the current dependency graph (parent recipe ID -> list of child recipe IDs)
  /// used for cycle detection (BR-REC-05).
  Future<Map<String, List<String>>> getSubRecipeDependencyGraph();

  /// Returns map of recipe ID -> list of ingredient IDs (BR-PRC-02).
  Future<Map<String, List<String>>> getRecipeIngredientGraph();

  /// Returns map of recipe ID -> list of packaging IDs.
  Future<Map<String, List<String>>> getRecipePackagingGraph();

  /// Updates the updatedAt timestamp for a list of recipes in batch (BR-PRC-03).
  Future<void> updateRecipeTimestamps(List<String> recipeIds, DateTime timestamp);
}
