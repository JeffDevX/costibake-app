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
}
