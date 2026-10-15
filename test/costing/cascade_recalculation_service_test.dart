import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:costibake_app/core/database/app_database.dart';
import 'package:costibake_app/core/database/database_tables.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/data/models/ingredient_model.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/costing/data/services/cascade_recalculation_service.dart';
import 'package:costibake_app/features/costing/domain/services/costing_calculation_engine.dart';
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

  group('CascadeRecalculationService Integration Tests (JEF-9, RF-SYS-04, BR-PRC-01..04)', () {
    late Database db;
    late CascadeRecalculationService cascadeService;
    late RecipeLocalDataSourceImpl recipeDataSource;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      AppDatabase.setMockDatabase(db);

      // Initialize DB schema
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

      // Business config: $10/h labor, 15% overhead
      final settingsDataSource = SettingsLocalDataSourceImpl(database: AppDatabase.instance);
      await settingsDataSource.saveBusinessConfig(
        BusinessConfigModel(
          id: 'cfg_1',
          businessName: 'Pastelería CostiBake',
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

    test('Modifying butter price from \$3.00 to \$4.50 updates its unit cost and cascades to all direct & nested recipes', () async {
      final initialTimestamp = DateTime(2026, 1, 1, 10, 0, 0);

      // 1. Seed initial Butter at $3.00 for 250g (minimum unit cost = 3.00 / 250 = $0.0120 / g)
      final butterMinCost = Ingredient.calculateMinimumUnitCost(
        purchaseCost: PreciseDecimal.fromString('3.0000'),
        purchaseQuantity: PreciseDecimal.fromString('250.0000'),
        purchaseUnit: 'g',
        wastePercentage: PreciseDecimal.zero,
      );
      expect(butterMinCost, equals(PreciseDecimal.fromString('0.0120')));

      final initialButter = IngredientModel(
        id: 'ins_butter',
        name: 'Mantequilla sin sal',
        category: 'Grasas y Mantequillas',
        purchaseCost: PreciseDecimal.fromString('3.0000'),
        purchaseQuantity: PreciseDecimal.fromString('250.0000'),
        purchaseUnit: 'g',
        wastePercentage: PreciseDecimal.zero,
        minimumUnitCost: butterMinCost,
        minimumUnit: 'g',
        updatedAt: initialTimestamp,
      );
      await db.insert(DatabaseTables.tableInsumo, initialButter.toMap());

      // 2. Seed Flour at $1.00 for 1000g ($0.0010 / g)
      final flour = IngredientModel(
        id: 'ins_flour',
        name: 'Harina de Trigo',
        category: 'Harinas y Secos',
        purchaseCost: PreciseDecimal.fromString('1.0000'),
        purchaseQuantity: PreciseDecimal.fromString('1000.0000'),
        purchaseUnit: 'g',
        wastePercentage: PreciseDecimal.zero,
        minimumUnitCost: PreciseDecimal.fromString('0.0010'),
        minimumUnit: 'g',
        updatedAt: initialTimestamp,
      );
      await db.insert(DatabaseTables.tableInsumo, flour.toMap());

      // 3. Create Recipe 1: "Bizcocho Clásico" (Directly uses 100g Butter + 200g Flour)
      // Initial: Butter 100g * $0.012 = $1.20, Flour 200g * $0.001 = $0.20 -> CI = $1.40
      // Yield = 4 portions, prep = 30 min (0.5h * $10 = $5.00), overhead = 15% of $1.40 = $0.21
      // Initial CTP = $1.40 + $5.00 + $0.21 = $6.61
      final recipe1 = RecipeModel(
        id: 'rec_bizcocho',
        name: 'Bizcocho Clásico',
        yieldPortions: 4,
        prepTimeMinutes: 30,
        bakeTimeMinutes: 25,
        targetProfitMargin: PreciseDecimal.fromString('40.0000'),
        status: 'ACTIVA',
        createdAt: initialTimestamp,
        updatedAt: initialTimestamp,
        ingredients: [
          RecipeIngredientItemModel(
            id: 'item_1',
            recipeId: 'rec_bizcocho',
            ingredientId: 'ins_butter',
            ingredientName: 'Mantequilla sin sal',
            quantity: PreciseDecimal.fromString('100.0000'),
            unit: 'g',
            baseUnit: 'g',
            unitCost: butterMinCost,
          ),
          RecipeIngredientItemModel(
            id: 'item_2',
            recipeId: 'rec_bizcocho',
            ingredientId: 'ins_flour',
            ingredientName: 'Harina de Trigo',
            quantity: PreciseDecimal.fromString('200.0000'),
            unit: 'g',
            baseUnit: 'g',
            unitCost: PreciseDecimal.fromString('0.0010'),
          ),
        ],
      );
      await recipeDataSource.save(recipe1);

      // 4. Create Recipe 2: "Pastel Cumpleaños" (Uses Recipe 1 as sub-recipe with factor 1.0)
      // Yield = 10 portions, prep = 60 min (1.0h * $10 = $10.00)
      final recipe2 = RecipeModel(
        id: 'rec_pastel',
        name: 'Pastel Cumpleaños',
        yieldPortions: 10,
        prepTimeMinutes: 60,
        bakeTimeMinutes: 0,
        targetProfitMargin: PreciseDecimal.fromString('50.0000'),
        status: 'ACTIVA',
        createdAt: initialTimestamp,
        updatedAt: initialTimestamp,
        subRecipes: [
          RecipeSubRecipeItemModel(
            id: 'sub_1',
            parentRecipeId: 'rec_pastel',
            childRecipeId: 'rec_bizcocho',
            childRecipeName: 'Bizcocho Clásico',
            quantityFactor: PreciseDecimal.fromString('1.0000'),
            unitCost: PreciseDecimal.fromString('1.4000'), // will be updated
          ),
        ],
      );
      await recipeDataSource.save(recipe2);

      // 5. Create Recipe 3: "Pan de Molde" (Uses only Flour, unaffected by Butter)
      final recipe3 = RecipeModel(
        id: 'rec_pan',
        name: 'Pan de Molde',
        yieldPortions: 2,
        prepTimeMinutes: 20,
        bakeTimeMinutes: 30,
        targetProfitMargin: PreciseDecimal.fromString('30.0000'),
        status: 'ACTIVA',
        createdAt: initialTimestamp,
        updatedAt: initialTimestamp,
        ingredients: [
          RecipeIngredientItemModel(
            id: 'item_3',
            recipeId: 'rec_pan',
            ingredientId: 'ins_flour',
            ingredientName: 'Harina de Trigo',
            quantity: PreciseDecimal.fromString('500.0000'),
            unit: 'g',
            baseUnit: 'g',
            unitCost: PreciseDecimal.fromString('0.0010'),
          ),
        ],
      );
      await recipeDataSource.save(recipe3);

      // --- EXECUTE CASCADE RECALCULATION ---
      // User modifies Butter price: $3.00 -> $4.50 for 250g
      // New unit cost = 4.50 / 250 = $0.0180 / g (BR-PRC-01)
      final updatedButterMinCost = Ingredient.calculateMinimumUnitCost(
        purchaseCost: PreciseDecimal.fromString('4.5000'),
        purchaseQuantity: PreciseDecimal.fromString('250.0000'),
        purchaseUnit: 'g',
        wastePercentage: PreciseDecimal.zero,
      );
      expect(updatedButterMinCost, equals(PreciseDecimal.fromString('0.0180')));

      final updatedButter = initialButter.copyWith(
        purchaseCost: PreciseDecimal.fromString('4.5000'),
        minimumUnitCost: updatedButterMinCost,
        updatedAt: DateTime.now(),
      );

      final result = await cascadeService.recalculateForIngredient(
        ingredient: updatedButter,
        previousUnitCost: butterMinCost,
      );

      // --- VERIFY ACCEPTANCE CRITERIA ---
      // 1. Result summary & notification message (BR-PRC-04)
      expect(result.affectedCount, equals(2));
      expect(result.affectedRecipeIds, containsAll(['rec_bizcocho', 'rec_pastel']));
      expect(result.affectedRecipeIds.contains('rec_pan'), isFalse);
      expect(
        result.userNotificationMessage,
        equals('Precio de Mantequilla sin sal actualizado. 2 recetas fueron recalculadas exitosamente.'),
      );

      // 2. Verify Recipe 1 "Bizcocho Clásico" recalculated cost in DB
      final reloadedRecipe1 = await recipeDataSource.getById('rec_bizcocho');
      expect(reloadedRecipe1, isNotNull);
      // New ingredients cost: Butter 100g * 0.0180 = $1.80, Flour 200g * 0.0010 = $0.20 -> CI = $2.00
      expect(reloadedRecipe1!.totalIngredientsCost, equals(PreciseDecimal.fromString('2.0000')));

      // Direct material cost = $2.00
      // Labor = 30 min / 60 * 10 = $5.00
      // Overhead = 15% of $2.00 = $0.30
      // CTP = $2.00 + $5.00 + $0.30 = $7.30
      // CUP = $7.30 / 4 portions = $1.8250
      final configModel = await SettingsLocalDataSourceImpl().getBusinessConfig();
      final bd1 = CostingCalculationEngine.calculate(
        recipe: reloadedRecipe1,
        config: configModel,
      );
      expect(bd1.rawMaterialsCost, equals(PreciseDecimal.fromString('2.0000')));
      expect(bd1.laborCost, equals(PreciseDecimal.fromString('5.0000')));
      expect(bd1.overheadCost, equals(PreciseDecimal.fromString('0.3000')));
      expect(bd1.totalProductionCost, equals(PreciseDecimal.fromString('7.3000')));
      expect(bd1.costPerPortion, equals(PreciseDecimal.fromString('1.8250')));

      // Suggested price = 7.30 * 1.40 = 10.2200
      expect(bd1.suggestedBatchPrice, equals(PreciseDecimal.fromString('10.2200')));

      // 3. Verify Recipe 2 "Pastel Cumpleaños" propagated sub-recipe cost
      final reloadedRecipe2 = await recipeDataSource.getById('rec_pastel');
      expect(reloadedRecipe2, isNotNull);
      // Sub-recipe cost in Recipe 2 must now equal Recipe 1 direct cost = $2.00
      expect(reloadedRecipe2!.totalSubRecipesCost, equals(PreciseDecimal.fromString('2.0000')));

      // 4. Verify updated_at timestamps were registered for affected recipes
      expect(reloadedRecipe1.updatedAt.isAfter(initialTimestamp), isTrue);
      expect(reloadedRecipe2.updatedAt.isAfter(initialTimestamp), isTrue);

      // Recipe 3 "Pan de Molde" must have unchanged timestamp
      final reloadedRecipe3 = await recipeDataSource.getById('rec_pan');
      expect(reloadedRecipe3!.updatedAt, equals(initialTimestamp));
    });

    test('Returns 0 affected recipes and clean message when modified ingredient is not used', () async {
      final unusedIngredient = Ingredient(
        id: 'ins_unlinked',
        name: 'Colorante Azul',
        category: 'Esencias y Colorantes',
        purchaseCost: PreciseDecimal.fromString('5.0000'),
        purchaseQuantity: PreciseDecimal.fromString('1.0000'),
        purchaseUnit: 'unidad',
        wastePercentage: PreciseDecimal.zero,
        minimumUnitCost: PreciseDecimal.fromString('5.0000'),
        minimumUnit: 'unidad',
        updatedAt: DateTime.now(),
      );

      final result = await cascadeService.recalculateForIngredient(
        ingredient: unusedIngredient,
      );

      expect(result.affectedCount, equals(0));
      expect(result.affectedRecipeIds, isEmpty);
      expect(result.userNotificationMessage, equals('Insumo "Colorante Azul" actualizado exitosamente.'));
    });
  });
}
