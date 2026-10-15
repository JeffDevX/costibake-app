import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_tables.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../catalog/data/models/ingredient_model.dart';
import '../../../catalog/data/models/packaging_model.dart';
import '../../../catalog/domain/entities/ingredient.dart';
import '../../../catalog/domain/entities/packaging.dart';
import '../../../recipes/data/datasources/recipe_local_datasource.dart';
import '../../../recipes/domain/entities/recipe.dart';
import '../../../settings/data/datasources/settings_local_datasource.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../../domain/entities/cascade_recalculation_result.dart';
import '../../domain/services/cascade_recalculation_engine.dart';

/// Application service executing transactional cascade recalculations
/// when an ingredient or packaging price changes in the catalog
/// (JEF-9, RF-SYS-04, RNF-04, BR-PRC-01..04).
class CascadeRecalculationService {
  final AppDatabase appDatabase;
  final RecipeLocalDataSource recipeDataSource;
  final SettingsLocalDataSource settingsDataSource;

  CascadeRecalculationService({
    AppDatabase? database,
    RecipeLocalDataSource? recipeLocalDataSource,
    SettingsLocalDataSource? settingsLocalDataSource,
  })  : appDatabase = database ?? AppDatabase.instance,
        recipeDataSource = recipeLocalDataSource ?? RecipeLocalDataSourceImpl(database: database),
        settingsDataSource = settingsLocalDataSource ?? SettingsLocalDataSourceImpl(database: database);

  /// Executes transactional cascade recalculation for an updated [ingredient] (RF-SYS-04, BR-PRC-01..04).
  Future<CascadeRecalculationResult> recalculateForIngredient({
    required Ingredient ingredient,
    PreciseDecimal? previousUnitCost,
  }) async {
    final stopwatch = Stopwatch()..start();
    final now = DateTime.now();

    return await appDatabase.runTransaction((txn) async {
      // 1. Persist the updated ingredient with its normalized minimum unit cost (BR-PRC-01)
      final model = ingredient is IngredientModel
          ? ingredient
          : IngredientModel.fromEntity(ingredient);
      await txn.insert(
        DatabaseTables.tableInsumo,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Fetch indexed dependency graphs (BR-PRC-02)
      final recipeIngredientMap =
          await recipeDataSource.getRecipeIngredientGraph(executor: txn);
      final subRecipeMap =
          await recipeDataSource.getSubRecipeDependencyGraph(executor: txn);

      // 3. Resolve all direct and transitive affected recipes via DAG traversal
      final affectedIds = CascadeRecalculationEngine.findAffectedRecipeIds(
        changedIngredientId: ingredient.id,
        recipeToIngredientMap: recipeIngredientMap,
        parentToChildSubRecipeMap: subRecipeMap,
      );

      if (affectedIds.isEmpty) {
        stopwatch.stop();
        return CascadeRecalculationResult(
          ingredientId: ingredient.id,
          ingredientName: ingredient.name,
          oldCost: previousUnitCost,
          newCost: ingredient.minimumUnitCost,
          affectedRecipeIds: const [],
          affectedRecipeNames: const [],
          recalculatedRecipes: const [],
          elapsedMilliseconds: stopwatch.elapsedMilliseconds,
          timestamp: now,
        );
      }

      // 4. Sort affected recipes in topological order (children before parents)
      final sortedIds = CascadeRecalculationEngine.topologicalSort(
        affectedRecipeIds: affectedIds,
        parentToChildSubRecipeMap: subRecipeMap,
      );

      // 5. Update timestamp (fecha_actualizacion) in RECETA for all affected recipes in batch
      await recipeDataSource.updateTimestamps(sortedIds, now, executor: txn);

      // 6. Fetch business config for overhead and labor rates
      final configModel =
          await settingsDataSource.getBusinessConfig(executor: txn);
      final businessConfig = BusinessConfig(
        id: configModel.id,
        businessName: configModel.businessName,
        currencySymbol: configModel.currencySymbol,
        laborHourlyRate: configModel.laborHourlyRate,
        overheadPercentage: configModel.overheadPercentage,
        updatedAt: configModel.updatedAt,
      );

      // 7. Load all affected recipes in batch (4 queries total)
      final recipesMap =
          await recipeDataSource.getByIds(sortedIds, executor: txn);

      final updatedChildRecipeCosts = <String, PreciseDecimal>{};
      final recalculatedRecipes = <Recipe>[];
      final affectedNames = <String>[];

      for (final recipeId in sortedIds) {
        final recipe = recipesMap[recipeId];
        if (recipe != null) {
          final result = CascadeRecalculationEngine.recalculateRecipe(
            recipe: recipe,
            config: businessConfig,
            updatedChildRecipeCosts: updatedChildRecipeCosts,
            updatedTimestamp: now,
          );
          recalculatedRecipes.add(result.updatedRecipe);
          affectedNames.add(recipe.name);

          // Store child recipe's total direct material cost for any parent that consumes it
          updatedChildRecipeCosts[recipeId] = result.breakdown.directMaterialCost;
        }
      }

      stopwatch.stop();

      return CascadeRecalculationResult(
        ingredientId: ingredient.id,
        ingredientName: ingredient.name,
        oldCost: previousUnitCost,
        newCost: ingredient.minimumUnitCost,
        affectedRecipeIds: sortedIds,
        affectedRecipeNames: affectedNames,
        recalculatedRecipes: recalculatedRecipes,
        elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        timestamp: now,
      );
    });
  }

  /// Executes transactional cascade recalculation for an updated [packaging].
  Future<CascadeRecalculationResult> recalculateForPackaging({
    required Packaging packaging,
    PreciseDecimal? previousUnitCost,
  }) async {
    final stopwatch = Stopwatch()..start();
    final now = DateTime.now();

    return await appDatabase.runTransaction((txn) async {
      final model = packaging is PackagingModel
          ? packaging
          : PackagingModel.fromEntity(packaging);
      await txn.insert(
        DatabaseTables.tableEmpaque,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final recipePackagingMap =
          await recipeDataSource.getRecipePackagingGraph(executor: txn);
      final subRecipeMap =
          await recipeDataSource.getSubRecipeDependencyGraph(executor: txn);

      final affectedIds = CascadeRecalculationEngine.findAffectedRecipeIdsForPackaging(
        changedPackagingId: packaging.id,
        recipeToPackagingMap: recipePackagingMap,
        parentToChildSubRecipeMap: subRecipeMap,
      );

      if (affectedIds.isEmpty) {
        stopwatch.stop();
        return CascadeRecalculationResult(
          ingredientId: packaging.id,
          ingredientName: packaging.name,
          oldCost: previousUnitCost,
          newCost: packaging.unitCost,
          affectedRecipeIds: const [],
          affectedRecipeNames: const [],
          recalculatedRecipes: const [],
          elapsedMilliseconds: stopwatch.elapsedMilliseconds,
          timestamp: now,
        );
      }

      final sortedIds = CascadeRecalculationEngine.topologicalSort(
        affectedRecipeIds: affectedIds,
        parentToChildSubRecipeMap: subRecipeMap,
      );

      await recipeDataSource.updateTimestamps(sortedIds, now, executor: txn);

      final configModel =
          await settingsDataSource.getBusinessConfig(executor: txn);
      final businessConfig = BusinessConfig(
        id: configModel.id,
        businessName: configModel.businessName,
        currencySymbol: configModel.currencySymbol,
        laborHourlyRate: configModel.laborHourlyRate,
        overheadPercentage: configModel.overheadPercentage,
        updatedAt: configModel.updatedAt,
      );

      final recipesMap =
          await recipeDataSource.getByIds(sortedIds, executor: txn);

      final updatedChildRecipeCosts = <String, PreciseDecimal>{};
      final recalculatedRecipes = <Recipe>[];
      final affectedNames = <String>[];

      for (final recipeId in sortedIds) {
        final recipe = recipesMap[recipeId];
        if (recipe != null) {
          final result = CascadeRecalculationEngine.recalculateRecipe(
            recipe: recipe,
            config: businessConfig,
            updatedChildRecipeCosts: updatedChildRecipeCosts,
            updatedTimestamp: now,
          );
          recalculatedRecipes.add(result.updatedRecipe);
          affectedNames.add(recipe.name);
          updatedChildRecipeCosts[recipeId] = result.breakdown.directMaterialCost;
        }
      }

      stopwatch.stop();

      return CascadeRecalculationResult(
        ingredientId: packaging.id,
        ingredientName: packaging.name,
        oldCost: previousUnitCost,
        newCost: packaging.unitCost,
        affectedRecipeIds: sortedIds,
        affectedRecipeNames: affectedNames,
        recalculatedRecipes: recalculatedRecipes,
        elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        timestamp: now,
      );
    });
  }
}
