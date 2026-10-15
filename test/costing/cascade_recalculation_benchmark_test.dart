import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:costibake_app/core/database/app_database.dart';
import 'package:costibake_app/core/database/database_tables.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/data/models/ingredient_model.dart';
import 'package:costibake_app/features/costing/data/services/cascade_recalculation_service.dart';
import 'package:costibake_app/features/recipes/data/datasources/recipe_local_datasource.dart';
import 'package:costibake_app/features/recipes/data/models/recipe_item_model.dart';
import 'package:costibake_app/features/recipes/data/models/recipe_model.dart';
import 'package:costibake_app/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:costibake_app/features/settings/data/models/business_config_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('RNF-04 Performance Benchmark: Cascade Recalculation under 150 ms', () {
    late Database db;
    late CascadeRecalculationService cascadeService;
    late RecipeLocalDataSourceImpl recipeDataSource;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      AppDatabase.setMockDatabase(db);

      // Create schema and indexes
      await db.execute(DatabaseTables.createTableInsumo);
      await db.execute(DatabaseTables.createTableEmpaque);
      await db.execute(DatabaseTables.createTableReceta);
      await db.execute(DatabaseTables.createTableRecetaInsumo);
      await db.execute(DatabaseTables.createTableRecetaSubreceta);
      await db.execute(DatabaseTables.createTableRecetaEmpaque);
      await db.execute(DatabaseTables.createTableConfiguracionNegocio);
      await db.execute(DatabaseTables.createTableMatrizDensidad);
      for (final idx in DatabaseTables.createIndexes) {
        await db.execute(idx);
      }

      final settingsDataSource = SettingsLocalDataSourceImpl(database: AppDatabase.instance);
      await settingsDataSource.saveBusinessConfig(
        BusinessConfigModel(
          id: 'cfg_1',
          businessName: 'Pastelería Benchmark',
          currencySymbol: '\$',
          laborHourlyRate: PreciseDecimal.fromString('10.0000'),
          overheadPercentage: PreciseDecimal.fromString('15.0000'),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      recipeDataSource = RecipeLocalDataSourceImpl(database: AppDatabase.instance);
      cascadeService = CascadeRecalculationService(
        database: AppDatabase.instance,
        recipeLocalDataSource: recipeDataSource,
        settingsLocalDataSource: settingsDataSource,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Recalculating 100 dependent recipes executes in strictly less than 150 ms (RNF-04)', () async {
      const targetIngredientId = 'ins_butter_bench';
      final now = DateTime(2026, 1, 1);

      // 1. Seed base ingredient
      final butter = IngredientModel(
        id: targetIngredientId,
        name: 'Mantequilla Premium',
        category: 'Grasas y Mantequillas',
        purchaseCost: PreciseDecimal.fromString('4.0000'),
        purchaseQuantity: PreciseDecimal.fromString('200.0000'),
        purchaseUnit: 'g',
        wastePercentage: PreciseDecimal.zero,
        minimumUnitCost: PreciseDecimal.fromString('0.0200'),
        minimumUnit: 'g',
        updatedAt: now,
      );
      await db.insert(DatabaseTables.tableInsumo, butter.toMap());

      // 2. Batch-seed 50 base recipes directly using the ingredient
      // and 50 composite recipes using the base recipes as sub-recipes (total 100 recipes)
      const baseCount = 50;
      const compositeCount = 50;

      await db.transaction((txn) async {
        for (int i = 0; i < baseCount; i++) {
          final recipeId = 'base_rec_$i';
          final recipe = RecipeModel(
            id: recipeId,
            name: 'Base Recipe $i',
            yieldPortions: 6,
            prepTimeMinutes: 20,
            bakeTimeMinutes: 20,
            targetProfitMargin: PreciseDecimal.fromString('40.0000'),
            status: 'ACTIVA',
            createdAt: now,
            updatedAt: now,
          );
          await txn.insert(DatabaseTables.tableReceta, recipe.toMap());
          await txn.insert(
            DatabaseTables.tableRecetaInsumo,
            RecipeIngredientItemModel(
              id: 'ing_item_$i',
              recipeId: recipeId,
              ingredientId: targetIngredientId,
              ingredientName: 'Mantequilla Premium',
              quantity: PreciseDecimal.fromString('50.0000'),
              unit: 'g',
              baseUnit: 'g',
              unitCost: PreciseDecimal.fromString('0.0200'),
            ).toMap(),
          );
        }

        for (int j = 0; j < compositeCount; j++) {
          final recipeId = 'composite_rec_$j';
          final childId = 'base_rec_$j';
          final recipe = RecipeModel(
            id: recipeId,
            name: 'Composite Recipe $j',
            yieldPortions: 12,
            prepTimeMinutes: 45,
            bakeTimeMinutes: 10,
            targetProfitMargin: PreciseDecimal.fromString('45.0000'),
            status: 'ACTIVA',
            createdAt: now,
            updatedAt: now,
          );
          await txn.insert(DatabaseTables.tableReceta, recipe.toMap());
          await txn.insert(
            DatabaseTables.tableRecetaSubreceta,
            RecipeSubRecipeItemModel(
              id: 'sub_item_$j',
              parentRecipeId: recipeId,
              childRecipeId: childId,
              childRecipeName: 'Base Recipe $j',
              quantityFactor: PreciseDecimal.fromString('1.0000'),
              unitCost: PreciseDecimal.fromString('1.0000'),
            ).toMap(),
          );
        }
      });

      // 3. Update the ingredient price: $4.00 -> $6.00 (unit cost 0.0200 -> 0.0300)
      final updatedButter = butter.copyWith(
        purchaseCost: PreciseDecimal.fromString('6.0000'),
        minimumUnitCost: PreciseDecimal.fromString('0.0300'),
        updatedAt: DateTime.now(),
      );

      // Warm-up run or direct benchmark measurement
      final stopwatch = Stopwatch()..start();
      final result = await cascadeService.recalculateForIngredient(
        ingredient: updatedButter,
        previousUnitCost: PreciseDecimal.fromString('0.0200'),
      );
      stopwatch.stop();

      // Verify all 100 recipes were identified and recalculated
      expect(result.affectedCount, equals(100));
      expect(result.recalculatedRecipes.length, equals(100));

      // Verify latency threshold of RNF-04 (< 150 ms)
      // Note: On desktop/mac this typically executes in 15-40 ms.
      // ignore: avoid_print
      print('RNF-04 Benchmark result: ${result.elapsedMilliseconds} ms (wall-clock: ${stopwatch.elapsedMilliseconds} ms) for 100 recipes');

      expect(
        result.elapsedMilliseconds,
        lessThan(150),
        reason: 'Cascade recalculation for 100 recipes must take strictly less than 150 ms (RNF-04). Actual: ${result.elapsedMilliseconds} ms',
      );
    });
  });
}
