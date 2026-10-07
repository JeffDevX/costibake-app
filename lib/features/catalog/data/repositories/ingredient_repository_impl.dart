import '../../domain/entities/ingredient.dart';
import '../../domain/repositories/ingredient_repository.dart';
import '../datasources/ingredient_local_datasource.dart';
import '../models/ingredient_model.dart';

class IngredientRepositoryImpl implements IngredientRepository {
  final IngredientLocalDataSource localDataSource;

  IngredientRepositoryImpl({IngredientLocalDataSource? localDataSource})
      : localDataSource = localDataSource ?? IngredientLocalDataSourceImpl();

  @override
  Future<List<Ingredient>> getAllIngredients() async {
    return await localDataSource.getAll();
  }

  @override
  Future<Ingredient?> getIngredientById(String id) async {
    return await localDataSource.getById(id);
  }

  @override
  Future<List<Ingredient>> searchIngredients(String query,
      {String? category}) async {
    return await localDataSource.search(query, category: category);
  }

  @override
  Future<void> saveIngredient(Ingredient ingredient) async {
    final model = ingredient is IngredientModel
        ? ingredient
        : IngredientModel.fromEntity(ingredient);
    await localDataSource.save(model);
  }

  @override
  Future<void> deleteIngredient(String id, {bool force = false}) async {
    await localDataSource.delete(id, force: force);
  }

  @override
  Future<List<String>> getRecipesUsingIngredient(String ingredientId) async {
    return await localDataSource.getUsageInRecipes(ingredientId);
  }
}
