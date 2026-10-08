import '../entities/recipe.dart';

abstract class RecipeRepository {
  Future<List<Recipe>> getAllRecipes();
  Future<Recipe?> getRecipeById(String id);
  Future<List<Recipe>> searchRecipes(String query, {String? status});
  Future<void> saveRecipe(Recipe recipe);
  Future<void> deleteRecipe(String id);
  Future<void> updateRecipeStatus(String recipeId, String newStatus);
}
