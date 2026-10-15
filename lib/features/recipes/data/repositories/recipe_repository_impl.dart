import '../../domain/entities/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../datasources/recipe_local_datasource.dart';
import '../models/recipe_model.dart';

class RecipeRepositoryImpl implements RecipeRepository {
  final RecipeLocalDataSource localDataSource;

  RecipeRepositoryImpl({RecipeLocalDataSource? localDataSource})
      : localDataSource = localDataSource ?? RecipeLocalDataSourceImpl();

  @override
  Future<List<Recipe>> getAllRecipes() async {
    return await localDataSource.getAll();
  }

  @override
  Future<Recipe?> getRecipeById(String id) async {
    return await localDataSource.getById(id);
  }

  @override
  Future<List<Recipe>> searchRecipes(String query, {String? status}) async {
    return await localDataSource.search(query, status: status);
  }

  @override
  Future<void> saveRecipe(Recipe recipe) async {
    final model = recipe is RecipeModel
        ? recipe
        : RecipeModel.fromEntity(recipe);
    await localDataSource.save(model);
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await localDataSource.delete(id);
  }

  @override
  Future<void> updateRecipeStatus(String recipeId, String newStatus) async {
    await localDataSource.updateStatus(recipeId, newStatus);
  }

  @override
  Future<Map<String, List<String>>> getSubRecipeDependencyGraph() async {
    return await localDataSource.getSubRecipeDependencyGraph();
  }

  @override
  Future<Map<String, List<String>>> getRecipeIngredientGraph() async {
    return await localDataSource.getRecipeIngredientGraph();
  }

  @override
  Future<Map<String, List<String>>> getRecipePackagingGraph() async {
    return await localDataSource.getRecipePackagingGraph();
  }

  @override
  Future<void> updateRecipeTimestamps(List<String> recipeIds, DateTime timestamp) async {
    await localDataSource.updateTimestamps(recipeIds, timestamp);
  }
}
