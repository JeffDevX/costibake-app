import '../entities/ingredient.dart';

abstract class IngredientRepository {
  Future<List<Ingredient>> getAllIngredients();
  Future<Ingredient?> getIngredientById(String id);
  Future<List<Ingredient>> searchIngredients(String query, {String? category});
  Future<void> saveIngredient(Ingredient ingredient);
  Future<void> deleteIngredient(String id, {bool force = false});
  Future<List<String>> getRecipesUsingIngredient(String ingredientId);
}
