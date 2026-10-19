import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:costibake_app/core/constants/app_constants.dart';
import 'package:costibake_app/core/database/app_database.dart';
import 'package:costibake_app/core/database/database_tables.dart';
import 'package:costibake_app/core/errors/exceptions.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/core/utils/recipe_cycle_detector.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/recipes/data/datasources/recipe_local_datasource.dart';
import 'package:costibake_app/features/recipes/data/models/recipe_item_model.dart';
import 'package:costibake_app/features/recipes/data/models/recipe_model.dart';
import 'package:costibake_app/features/recipes/data/repositories/recipe_repository_impl.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe_item.dart';
import 'package:costibake_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_event.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_state.dart';
import 'package:costibake_app/features/recipes/presentation/screens/recipe_form_screen.dart';
import 'package:costibake_app/features/recipes/presentation/screens/recipes_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('JEF-13: Gestión y Formulación de Recetas Modulares (Bases y Decoraciones)', () {
    late Database db;
    late RecipeLocalDataSourceImpl localDataSource;
    late RecipeRepositoryImpl recipeRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      AppDatabase.setMockDatabase(db);

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

      // Seed catalog items for recipe items linking
      await db.insert(DatabaseTables.tableInsumo, {
        'id': 'ing_harina',
        'nombre': 'Harina de Trigo',
        'categoria': 'Harinas',
        'costo_compra': '45.0000',
        'cantidad_compra': '50.0000',
        'unidad_compra': 'kg',
        'merma_porcentaje': '0.0000',
        'costo_unitario_minimo': '0.0009', // $0.0009/g
        'unidad_minima': 'g',
        'densidad_g_ml': '0.520833',
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      });

      await db.insert(DatabaseTables.tableInsumo, {
        'id': 'ing_azucar',
        'nombre': 'Azúcar Blanca',
        'categoria': 'Azúcares',
        'costo_compra': '25.0000',
        'cantidad_compra': '25.0000',
        'unidad_compra': 'kg',
        'merma_porcentaje': '0.0000',
        'costo_unitario_minimo': '0.0010', // $0.0010/g
        'unidad_minima': 'g',
        'densidad_g_ml': '0.833333',
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      });

      await db.insert(DatabaseTables.tableEmpaque, {
        'id': 'pack_caja',
        'nombre': 'Caja para Pastel 25x25',
        'categoria': 'Cajas',
        'costo_paquete': '50.0000',
        'unidades_por_paquete': 50,
        'costo_unitario': '1.0000',
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      });

      localDataSource = RecipeLocalDataSourceImpl(database: AppDatabase.instance);
      recipeRepo = RecipeRepositoryImpl(localDataSource: localDataSource);
    });

    tearDown(() async {
      await db.close();
      AppDatabase.setMockDatabase(null);
    });

    group('BR-REC-03 & RF-SYS-11: Prorrateo Directo de Ingredientes con Conversión de Densidad', () {
      test('1 taza de harina (125g) prorrateada a \$0.0009/g resulta en \$0.1125', () {
        final item = RecipeIngredientItem(
          id: 'item_1',
          recipeId: 'rec_1',
          ingredientId: 'ing_harina',
          ingredientName: 'Harina de Trigo',
          quantity: PreciseDecimal.fromString('1.0000'),
          unit: 'taza',
          section: 'Bizcocho',
          unitCost: PreciseDecimal.fromString('0.0009'),
          densityGPerMl: PreciseDecimal.fromString('0.520833'),
          baseUnit: 'g',
        );

        final cost = item.calculateItemCost();
        // 1 taza * 240 ml/taza * 0.520833 g/ml = 125.0 g. 125 * 0.0009 = 0.1125
        expect(cost.toStringAsFixed(4), '0.1125');
      });

      test('2 tazas de azúcar común (400g) prorrateada a \$0.0010/g resulta en \$0.4000', () {
        final item = RecipeIngredientItem(
          id: 'item_2',
          recipeId: 'rec_1',
          ingredientId: 'ing_azucar',
          ingredientName: 'Azúcar Blanca',
          quantity: PreciseDecimal.fromString('2.0000'),
          unit: 'taza',
          section: 'Bizcocho',
          unitCost: PreciseDecimal.fromString('0.0010'),
          densityGPerMl: PreciseDecimal.fromString('0.833333'),
          baseUnit: 'g',
        );

        final cost = item.calculateItemCost();
        // 2 tazas * 240 ml * 0.833333 = 400.0 g. 400 * 0.0010 = 0.4000
        expect(cost.toStringAsFixed(4), '0.4000');
      });
    });

    group('BR-REC-04 & RF-SYS-10: Costo de Receta Modular con Sub-recetas Anidadas', () {
      test('Costo total consolida ingredientes propios, empaques y sub-receta prorrateada', () {
        // Child sub-recipe: Ganache de Chocolate con costo de lote $5.00
        final subRecipe = RecipeSubRecipeItem(
          id: 'sub_1',
          parentRecipeId: 'rec_master',
          childRecipeId: 'rec_ganache',
          childRecipeName: 'Ganache de Chocolate Belga',
          quantityFactor: PreciseDecimal.fromString('0.5000'), // 0.5x de lote
          section: 'Relleno',
          unitCost: PreciseDecimal.fromString('5.0000'),
        );

        // Direct ingredient: Harina ($0.1125)
        final directIngredient = RecipeIngredientItem(
          id: 'item_harina',
          recipeId: 'rec_master',
          ingredientId: 'ing_harina',
          ingredientName: 'Harina de Trigo',
          quantity: PreciseDecimal.fromString('1.0000'),
          unit: 'taza',
          section: 'Bizcocho',
          unitCost: PreciseDecimal.fromString('0.0009'),
          densityGPerMl: PreciseDecimal.fromString('0.520833'),
          baseUnit: 'g',
        );

        // Direct packaging: 1 caja ($1.00)
        final directPackaging = RecipePackagingItem(
          id: 'pack_1',
          recipeId: 'rec_master',
          packagingId: 'pack_caja',
          packagingName: 'Caja para Pastel',
          pieceQuantity: 1,
          unitCost: PreciseDecimal.fromString('1.0000'),
        );

        final masterRecipe = Recipe(
          id: 'rec_master',
          name: 'Torta Modular Premium',
          yieldPortions: 10,
          prepTimeMinutes: 60,
          bakeTimeMinutes: 45,
          targetProfitMargin: PreciseDecimal.fromString('40.0000'),
          status: AppConstants.recipeStatusActive,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          ingredients: [directIngredient],
          subRecipes: [subRecipe],
          packaging: [directPackaging],
        );

        // Subtotal ingredientes = $0.1125
        expect(masterRecipe.totalIngredientsCost.toStringAsFixed(4), '0.1125');
        // Subtotal subrecetas = 0.5 * $5.00 = $2.5000
        expect(masterRecipe.totalSubRecipesCost.toStringAsFixed(4), '2.5000');
        // Subtotal empaque = 1 * $1.00 = $1.0000
        expect(masterRecipe.totalPackagingCost.toStringAsFixed(4), '1.0000');
        // Costo directo total = $0.1125 + $2.5000 + $1.0000 = $3.6125
        expect(masterRecipe.totalDirectCost.toStringAsFixed(4), '3.6125');
        expect(masterRecipe.hasModularComponents, isTrue);
        expect(masterRecipe.sections, containsAll(['Bizcocho', 'Relleno']));
      });
    });

    group('BR-REC-05: Prevención de Ciclos y Referencias Circulares (DAG Validation)', () {
      test('Inclusión de sí misma como sub-receta lanza CircularRecipeDependencyException', () {
        expect(
          () => RecipeCycleDetector.validateNoCycle(
            parentRecipeId: 'rec_A',
            childRecipeId: 'rec_A',
            dependencyGraph: {},
          ),
          throwsA(isA<CircularRecipeDependencyException>()),
        );
      });

      test('Ciclo indirecto A -> B -> A es detectado y bloqueado', () {
        // Graph already has: B includes A
        final graph = {
          'rec_B': ['rec_A'],
        };

        // Attempting to add B as child of A would cause A -> B -> A
        expect(
          () => RecipeCycleDetector.validateNoCycle(
            parentRecipeId: 'rec_A',
            childRecipeId: 'rec_B',
            dependencyGraph: graph,
          ),
          throwsA(isA<CircularRecipeDependencyException>()),
        );
      });

      test('Ciclo multi-nivel A -> B -> C -> A es detectado y bloqueado', () {
        final graph = {
          'rec_B': ['rec_C'],
          'rec_C': ['rec_A'],
        };

        expect(
          () => RecipeCycleDetector.validateNoCycle(
            parentRecipeId: 'rec_A',
            childRecipeId: 'rec_B',
            dependencyGraph: graph,
          ),
          throwsA(isA<CircularRecipeDependencyException>()),
        );
      });

      test('Estructura DAG válida sin ciclos es permitida', () {
        final graph = {
          'rec_B': ['rec_D'],
          'rec_C': ['rec_D'],
        };

        expect(
          RecipeCycleDetector.canAddSubRecipe(
            parentRecipeId: 'rec_A',
            candidateChildId: 'rec_B',
            dependencyGraph: graph,
          ),
          isTrue,
        );
      });
    });

    group('Persistencia Relacional Atómica en SQLite', () {
      test('Guarda y recupera receta modular con ingredientes, sub-recetas y empaques', () async {
        // Create base child recipe first
        final childRecipe = RecipeModel(
          id: 'child_bizcocho',
          name: 'Bizcocho Base de Vainilla',
          yieldPortions: 8,
          prepTimeMinutes: 20,
          bakeTimeMinutes: 30,
          targetProfitMargin: PreciseDecimal.fromString('40.0000'),
          status: AppConstants.recipeStatusActive,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          ingredients: [
            RecipeIngredientItemModel(
              id: 'ing_c1',
              recipeId: 'child_bizcocho',
              ingredientId: 'ing_harina',
              ingredientName: 'Harina de Trigo',
              quantity: PreciseDecimal.fromString('2.0000'),
              unit: 'taza',
              section: 'Base',
              unitCost: PreciseDecimal.fromString('0.0009'),
            ),
          ],
        );
        await recipeRepo.saveRecipe(childRecipe);

        // Create master recipe embedding childRecipe
        final masterRecipe = RecipeModel(
          id: 'master_cake',
          name: 'Torta de Cumpleaños Modular',
          description: 'Bizcocho base con almíbar y caja dorada',
          yieldPortions: 12,
          prepTimeMinutes: 45,
          bakeTimeMinutes: 35,
          moldType: 'Redondo',
          moldDimension: '22 cm / 8.5 in',
          targetProfitMargin: PreciseDecimal.fromString('45.0000'),
          status: AppConstants.recipeStatusActive,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          ingredients: [
            RecipeIngredientItemModel(
              id: 'ing_m1',
              recipeId: 'master_cake',
              ingredientId: 'ing_azucar',
              ingredientName: 'Azúcar Blanca',
              quantity: PreciseDecimal.fromString('1.5000'),
              unit: 'taza',
              section: 'Almíbar',
              unitCost: PreciseDecimal.fromString('0.0010'),
            ),
          ],
          subRecipes: [
            RecipeSubRecipeItemModel(
              id: 'sub_m1',
              parentRecipeId: 'master_cake',
              childRecipeId: 'child_bizcocho',
              childRecipeName: 'Bizcocho Base de Vainilla',
              quantityFactor: PreciseDecimal.fromString('1.0000'),
              section: 'Estructura',
              unitCost: PreciseDecimal.zero, // calculated on retrieval
            ),
          ],
          packaging: [
            RecipePackagingItemModel(
              id: 'pack_m1',
              recipeId: 'master_cake',
              packagingId: 'pack_caja',
              packagingName: 'Caja para Pastel 25x25',
              pieceQuantity: 1,
              unitCost: PreciseDecimal.fromString('1.0000'),
            ),
          ],
        );

        await recipeRepo.saveRecipe(masterRecipe);

        final retrieved = await recipeRepo.getRecipeById('master_cake');
        expect(retrieved, isNotNull);
        expect(retrieved!.name, 'Torta de Cumpleaños Modular');
        expect(retrieved.moldType, 'Redondo');
        expect(retrieved.moldDimension, '22 cm / 8.5 in');
        expect(retrieved.ingredients.length, 1);
        expect(retrieved.ingredients.first.section, 'Almíbar');
        expect(retrieved.subRecipes.length, 1);
        expect(retrieved.subRecipes.first.childRecipeName, 'Bizcocho Base de Vainilla');
        expect(retrieved.packaging.length, 1);
        expect(retrieved.packaging.first.pieceQuantity, 1);

        // Verify dependency graph returns parent -> [child]
        final graph = await recipeRepo.getSubRecipeDependencyGraph();
        expect(graph['master_cake'], contains('child_bizcocho'));
      });
    });

    group('RecipesBloc: Lógica de Estado y Filtrado', () {
      test('LoadRecipes carga las recetas persistidas', () async {
        final bloc = RecipesBloc(recipeRepository: recipeRepo);

        final future = expectLater(
          bloc.stream,
          emitsInOrder([
            isA<RecipesLoading>(),
            isA<RecipesLoaded>(),
          ]),
        );

        bloc.add(const LoadRecipes());
        await future;
        await bloc.close();
      });

      test('FilterRecipes filtra correctamente por texto y estado', () {
        final r1 = Recipe(
          id: '1',
          name: 'Pastel de Chocolate',
          yieldPortions: 8,
          prepTimeMinutes: 30,
          bakeTimeMinutes: 30,
          targetProfitMargin: PreciseDecimal.fromString('40.0'),
          status: AppConstants.recipeStatusActive,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final r2 = Recipe(
          id: '2',
          name: 'Galletas de Vainilla',
          yieldPortions: 24,
          prepTimeMinutes: 15,
          bakeTimeMinutes: 12,
          targetProfitMargin: PreciseDecimal.fromString('40.0'),
          status: AppConstants.recipeStatusDraft,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final loadedState = RecipesLoaded([r1, r2], searchQuery: 'chocolate');
        expect(loadedState.filteredRecipes.length, 1);
        expect(loadedState.filteredRecipes.first.name, 'Pastel de Chocolate');

        final filteredDrafts = RecipesLoaded([r1, r2], statusFilter: AppConstants.recipeStatusDraft);
        expect(filteredDrafts.filteredRecipes.length, 1);
        expect(filteredDrafts.filteredRecipes.first.name, 'Galletas de Vainilla');
      });
    });

    group('Integración en UI (RecipesScreen & RecipeFormScreen)', () {
      testWidgets('RecipesScreen renders without overflow on compact 360x640 mobile', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final bloc = RecipesBloc(recipeRepository: recipeRepo);
        bloc.emit(const RecipesLoaded([]));

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<RecipesBloc>.value(
              value: bloc,
              child: const RecipesScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Recetario Paramétrico'), findsOneWidget);
        expect(find.byKey(const Key('btn_add_recipe')), findsOneWidget);
        expect(find.text('No hay recetas formuladas.'), findsOneWidget);

        // Verify zero RenderFlex overflow
        expect(tester.takeException(), isNull);
      });

      testWidgets('RecipeFormScreen enforces BR-REC-01 and warns if saving empty recipe', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final fakeRecipeRepo = FakeRecipeRepository();
        final bloc = RecipesBloc(recipeRepository: fakeRecipeRepo);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiRepositoryProvider(
              providers: [
                RepositoryProvider<IngredientRepository>.value(value: FakeIngredientRepository()),
                RepositoryProvider<PackagingRepository>.value(value: FakePackagingRepository()),
                RepositoryProvider<RecipeRepository>.value(value: fakeRecipeRepo),
              ],
              child: BlocProvider<RecipesBloc>.value(
                value: bloc,
                child: const RecipeFormScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fill required name
        await tester.enterText(find.widgetWithText(TextFormField, 'Nombre de la Receta *'), 'Bizcocho Prueba');

        // Tap Save without ingredients
        final saveBtn = find.byKey(const Key('btn_save_recipe'));
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // BR-REC-01 warning message must be displayed
        expect(
          find.textContaining('La receta debe contener al menos un ingrediente o un componente modular hijo (BR-REC-01)'),
          findsOneWidget,
        );

        // Verify no RenderFlex overflow
        expect(tester.takeException(), isNull);
      });

      testWidgets("RecipeFormScreen opens recipe with moldType: 'Otro' without Dropdown assertion error", (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final fakeRecipeRepo = FakeRecipeRepository();
        final bloc = RecipesBloc(recipeRepository: fakeRecipeRepo);

        final recipeWithOtroMold = Recipe(
          id: 'recipe-otro-mold',
          name: 'Flan Casero',
          yieldPortions: 1,
          prepTimeMinutes: 120,
          bakeTimeMinutes: 60,
          moldType: 'Otro',
          moldDimension: 'Molde 8" (20 cm)',
          targetProfitMargin: PreciseDecimal.fromString('40.0'),
          status: AppConstants.recipeStatusActive,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MultiRepositoryProvider(
              providers: [
                RepositoryProvider<IngredientRepository>.value(value: FakeIngredientRepository()),
                RepositoryProvider<PackagingRepository>.value(value: FakePackagingRepository()),
                RepositoryProvider<RecipeRepository>.value(value: fakeRecipeRepo),
              ],
              child: BlocProvider<RecipesBloc>.value(
                value: bloc,
                child: RecipeFormScreen(recipeToEdit: recipeWithOtroMold),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The screen must render cleanly without throwing any assertion error
        expect(tester.takeException(), isNull);
        expect(find.byType(RecipeFormScreen), findsOneWidget);
        expect(find.text('Flan Casero'), findsOneWidget);
      });

      testWidgets("RecipeFormScreen opens recipe with custom unknown moldType without Dropdown assertion error", (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final fakeRecipeRepo = FakeRecipeRepository();
        final bloc = RecipesBloc(recipeRepository: fakeRecipeRepo);

        final recipeWithCustomMold = Recipe(
          id: 'recipe-custom-mold',
          name: 'Tarta Especial',
          yieldPortions: 6,
          prepTimeMinutes: 30,
          bakeTimeMinutes: 25,
          moldType: 'Corazón Desmontable',
          moldDimension: '22 cm',
          targetProfitMargin: PreciseDecimal.fromString('40.0'),
          status: AppConstants.recipeStatusActive,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MultiRepositoryProvider(
              providers: [
                RepositoryProvider<IngredientRepository>.value(value: FakeIngredientRepository()),
                RepositoryProvider<PackagingRepository>.value(value: FakePackagingRepository()),
                RepositoryProvider<RecipeRepository>.value(value: fakeRecipeRepo),
              ],
              child: BlocProvider<RecipesBloc>.value(
                value: bloc,
                child: RecipeFormScreen(recipeToEdit: recipeWithCustomMold),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The screen must render cleanly without throwing any assertion error
        expect(tester.takeException(), isNull);
        expect(find.byType(RecipeFormScreen), findsOneWidget);
        expect(find.text('Tarta Especial'), findsOneWidget);
      });
    });
  });
}

class FakeIngredientRepository implements IngredientRepository {
  @override
  Future<List<Ingredient>> getAllIngredients() async => [];

  @override
  Future<Ingredient?> getIngredientById(String id) async => null;

  @override
  Future<List<Ingredient>> searchIngredients(String query, {String? category}) async => [];

  @override
  Future<void> saveIngredient(Ingredient ingredient) async {}

  @override
  Future<void> deleteIngredient(String id, {bool force = false}) async {}

  @override
  Future<List<String>> getRecipesUsingIngredient(String ingredientId) async => [];
}

class FakePackagingRepository implements PackagingRepository {
  @override
  Future<List<Packaging>> getAllPackaging() async => [];

  @override
  Future<Packaging?> getPackagingById(String id) async => null;

  @override
  Future<List<Packaging>> searchPackaging(String query, {String? category}) async => [];

  @override
  Future<void> savePackaging(Packaging packaging) async {}

  @override
  Future<void> deletePackaging(String id, {bool force = false}) async {}

  @override
  Future<List<String>> getRecipesUsingPackaging(String packagingId) async => [];
}

class FakeRecipeRepository implements RecipeRepository {
  final List<Recipe> recipes = [];

  @override
  Future<List<Recipe>> getAllRecipes() async => recipes;

  @override
  Future<Recipe?> getRecipeById(String id) async =>
      recipes.where((r) => r.id == id).firstOrNull;

  @override
  Future<List<Recipe>> searchRecipes(String query, {String? status}) async => recipes;

  @override
  Future<void> saveRecipe(Recipe recipe) async {
    recipes.removeWhere((r) => r.id == recipe.id);
    recipes.add(recipe);
  }

  @override
  Future<void> deleteRecipe(String id) async {
    recipes.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> updateRecipeStatus(String recipeId, String newStatus) async {}

  @override
  Future<Map<String, List<String>>> getSubRecipeDependencyGraph() async => {};

  @override
  Future<Map<String, List<String>>> getRecipeIngredientGraph() async => {};

  @override
  Future<Map<String, List<String>>> getRecipePackagingGraph() async => {};

  @override
  Future<void> updateRecipeTimestamps(List<String> recipeIds, DateTime timestamp) async {}
}
