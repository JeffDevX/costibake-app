import 'package:costibake_app/core/constants/app_constants.dart';
import 'package:costibake_app/core/database/app_database.dart';
import 'package:costibake_app/core/errors/exceptions.dart';
import 'package:costibake_app/core/theme/app_theme.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/data/models/ingredient_model.dart';
import 'package:costibake_app/features/catalog/data/models/packaging_model.dart';
import 'package:costibake_app/features/catalog/data/repositories/ingredient_repository_impl.dart';
import 'package:costibake_app/features/catalog/data/repositories/packaging_repository_impl.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_state.dart';
import 'package:costibake_app/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:costibake_app/features/recipes/data/models/recipe_model.dart';
import 'package:costibake_app/features/recipes/data/repositories/recipe_repository_impl.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe_item.dart';
import 'package:costibake_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_event.dart';
import 'package:costibake_app/features/recipes/presentation/screens/recipe_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InMemoryIngredientRepo implements IngredientRepository {
  final List<Ingredient> items = [];
  final Map<String, List<String>> usageByIngredientId = {};

  @override
  Future<List<Ingredient>> getAllIngredients() async => List.of(items);

  @override
  Future<Ingredient?> getIngredientById(String id) async =>
      items.where((e) => e.id == id).firstOrNull;

  @override
  Future<List<Ingredient>> searchIngredients(
    String query, {
    String? category,
  }) async =>
      items;

  @override
  Future<void> saveIngredient(Ingredient ingredient) async {
    items.removeWhere((e) => e.id == ingredient.id);
    items.add(ingredient);
  }

  @override
  Future<void> deleteIngredient(String id, {bool force = false}) async {
    final usedIn = usageByIngredientId[id] ?? const [];
    if (usedIn.isNotEmpty && !force) {
      throw DependencyConstraintException(
        'No se puede eliminar este insumo porque está en uso en ${usedIn.length} receta(s).',
        affectedRecipeNames: usedIn,
      );
    }
    items.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<String>> getRecipesUsingIngredient(String ingredientId) async {
    return List.of(usageByIngredientId[ingredientId] ?? const []);
  }
}

class _InMemoryPackagingRepo implements PackagingRepository {
  final List<Packaging> items = [];
  final Map<String, List<String>> usageByPackagingId = {};

  @override
  Future<List<Packaging>> getAllPackaging() async => List.of(items);

  @override
  Future<Packaging?> getPackagingById(String id) async =>
      items.where((p) => p.id == id).firstOrNull;

  @override
  Future<List<Packaging>> searchPackaging(
    String query, {
    String? category,
  }) async =>
      items;

  @override
  Future<void> savePackaging(Packaging packaging) async {
    items.removeWhere((p) => p.id == packaging.id);
    items.add(packaging);
  }

  @override
  Future<void> deletePackaging(String id, {bool force = false}) async {
    final usedIn = usageByPackagingId[id] ?? const [];
    if (usedIn.isNotEmpty && !force) {
      throw DependencyConstraintException(
        'No se puede eliminar este empaque porque está en uso en ${usedIn.length} receta(s).',
        affectedRecipeNames: usedIn,
      );
    }
    items.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<String>> getRecipesUsingPackaging(String packagingId) async {
    return List.of(usageByPackagingId[packagingId] ?? const []);
  }
}

class _InMemoryRecipeRepo implements RecipeRepository {
  final List<Recipe> items = [];

  @override
  Future<List<Recipe>> getAllRecipes() async => List.of(items);

  @override
  Future<Recipe?> getRecipeById(String id) async =>
      items.where((r) => r.id == id).firstOrNull;

  @override
  Future<List<Recipe>> searchRecipes(String query, {String? status}) async =>
      items;

  @override
  Future<void> saveRecipe(Recipe recipe) async {
    items.removeWhere((r) => r.id == recipe.id);
    items.add(recipe);
  }

  @override
  Future<void> deleteRecipe(String id) async {
    items.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> updateRecipeStatus(String recipeId, String newStatus) async {}

  @override
  Future<Map<String, List<String>>> getSubRecipeDependencyGraph() async =>
      const {};

  @override
  Future<Map<String, List<String>>> getRecipeIngredientGraph() async =>
      const {};

  @override
  Future<Map<String, List<String>>> getRecipePackagingGraph() async =>
      const {};

  @override
  Future<void> updateRecipeTimestamps(
    List<String> recipeIds,
    DateTime timestamp,
  ) async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final now = DateTime(2026, 10, 16, 10, 0);

  Ingredient createButterIngredient() {
    return IngredientModel(
      id: 'ing-mantequilla-gloria',
      name: 'Mantequilla Gloria',
      category: 'Grasas y Mantequillas',
      purchaseCost: PreciseDecimal.fromString('12.00'),
      purchaseQuantity: PreciseDecimal.fromInt(1),
      purchaseUnit: 'kg',
      wastePercentage: PreciseDecimal.zero,
      minimumUnitCost: PreciseDecimal.fromString('0.012'),
      minimumUnit: 'g',
      updatedAt: now,
    );
  }

  Ingredient createUnusedIngredient() {
    return IngredientModel(
      id: 'ing-esencia-almendra',
      name: 'Esencia de Almendra',
      category: 'Esencias y Colorantes',
      purchaseCost: PreciseDecimal.fromString('5.00'),
      purchaseQuantity: PreciseDecimal.fromInt(100),
      purchaseUnit: 'ml',
      wastePercentage: PreciseDecimal.zero,
      minimumUnitCost: PreciseDecimal.fromString('0.05'),
      minimumUnit: 'ml',
      updatedAt: now,
    );
  }

  Packaging createBoxPackaging() {
    return PackagingModel(
      id: 'pkg-caja-dorada',
      name: 'Caja Dorada 10 pulgadas',
      category: 'Cajas para Pastel',
      packageCost: PreciseDecimal.fromString('25.00'),
      unitsPerPackage: 10,
      unitCost: PreciseDecimal.fromString('2.50'),
      updatedAt: now,
    );
  }

  RecipeModel createRecipeUsingButter({
    required String id,
    required String name,
    bool includeBox = false,
  }) {
    return RecipeModel(
      id: id,
      name: name,
      yieldPortions: 10,
      prepTimeMinutes: 30,
      bakeTimeMinutes: 35,
      targetProfitMargin: PreciseDecimal.fromInt(40),
      status: AppConstants.recipeStatusActive,
      createdAt: now,
      updatedAt: now,
      ingredients: [
        RecipeIngredientItem(
          id: 'ri-$id',
          recipeId: id,
          ingredientId: 'ing-mantequilla-gloria',
          ingredientName: 'Mantequilla Gloria',
          quantity: PreciseDecimal.fromInt(200),
          unit: 'g',
          baseUnit: 'g',
          unitCost: PreciseDecimal.fromString('0.012'),
        ),
      ],
      packaging: includeBox
          ? [
              RecipePackagingItem(
                id: 'rp-$id',
                recipeId: id,
                packagingId: 'pkg-caja-dorada',
                packagingName: 'Caja Dorada 10 pulgadas',
                pieceQuantity: 1,
                unitCost: PreciseDecimal.fromString('2.50'),
              ),
            ]
          : const [],
    );
  }

  group('JEF-17: SQLite & Repository Dependency Protection (RF-SYS-21, BR-INT-01..03)', () {
    late IngredientRepositoryImpl ingredientRepo;
    late PackagingRepositoryImpl packagingRepo;
    late RecipeRepositoryImpl recipeRepo;

    setUp(() async {
      final db = await AppDatabase.instance.database;
      await db.delete('receta_insumo');
      await db.delete('receta_empaque');
      await db.delete('receta_subreceta');
      await db.delete('receta');
      await db.delete('insumo');
      await db.delete('empaque');

      ingredientRepo = IngredientRepositoryImpl();
      packagingRepo = PackagingRepositoryImpl();
      recipeRepo = RecipeRepositoryImpl();
    });

    test('Blocks physical deletion of ingredient used in 3 recipes and lists all 3 recipe names', () async {
      final butter = createButterIngredient();
      await ingredientRepo.saveIngredient(butter);

      await recipeRepo.saveRecipe(
        createRecipeUsingButter(id: 'r1', name: 'Pastel de Zanahoria'),
      );
      await recipeRepo.saveRecipe(
        createRecipeUsingButter(id: 'r2', name: 'Torta Red Velvet'),
      );
      await recipeRepo.saveRecipe(
        createRecipeUsingButter(id: 'r3', name: 'Ganache de Chocolate'),
      );

      final affected = await ingredientRepo.getRecipesUsingIngredient(butter.id);
      expect(
        affected,
        containsAll([
          'Pastel de Zanahoria',
          'Torta Red Velvet',
          'Ganache de Chocolate',
        ]),
      );
      expect(affected.length, 3);

      // Attempting hard delete must throw DependencyConstraintException
      expect(
        () => ingredientRepo.deleteIngredient(butter.id),
        throwsA(
          isA<DependencyConstraintException>().having(
            (e) => e.affectedRecipeNames.length,
            'affectedRecipeNames length',
            3,
          ),
        ),
      );

      // Verify ingredient still exists in SQLite
      final stillExists = await ingredientRepo.getIngredientById(butter.id);
      expect(stillExists, isNotNull);
    });

    test('Blocks physical deletion of packaging used in recipes (RF-SYS-21, BR-INT-01)', () async {
      final butter = createButterIngredient();
      final box = createBoxPackaging();
      await ingredientRepo.saveIngredient(butter);
      await packagingRepo.savePackaging(box);

      await recipeRepo.saveRecipe(
        createRecipeUsingButter(
          id: 'r1',
          name: 'Pastel de Zanahoria',
          includeBox: true,
        ),
      );

      expect(
        () => packagingRepo.deletePackaging(box.id),
        throwsA(
          isA<DependencyConstraintException>().having(
            (e) => e.affectedRecipeNames,
            'affectedRecipeNames',
            ['Pastel de Zanahoria'],
          ),
        ),
      );

      final stillExists = await packagingRepo.getPackagingById(box.id);
      expect(stillExists, isNotNull);
    });

    test('Allows deletion when ingredient has 0 active dependencies (BR-INT-03)', () async {
      final unused = createUnusedIngredient();
      await ingredientRepo.saveIngredient(unused);

      final affected = await ingredientRepo.getRecipesUsingIngredient(unused.id);
      expect(affected, isEmpty);

      await ingredientRepo.deleteIngredient(unused.id);
      final afterDelete = await ingredientRepo.getIngredientById(unused.id);
      expect(afterDelete, isNull);
    });
  });

  group('JEF-17: CatalogBloc & Protective Modal Dialog UI Tests (RF-SYS-22, BR-INT-02)', () {
    late _InMemoryIngredientRepo memIngredientRepo;
    late _InMemoryPackagingRepo memPackagingRepo;
    late _InMemoryRecipeRepo memRecipeRepo;

    setUp(() {
      memIngredientRepo = _InMemoryIngredientRepo();
      memPackagingRepo = _InMemoryPackagingRepo();
      memRecipeRepo = _InMemoryRecipeRepo();
    });

    test('CatalogBloc preserves CatalogLoaded and populates lastDependencyBlock when DeleteIngredient is blocked', () async {
      final butter = createButterIngredient();
      await memIngredientRepo.saveIngredient(butter);
      memIngredientRepo.usageByIngredientId[butter.id] = [
        'Pastel de Zanahoria',
        'Torta Red Velvet',
        'Ganache de Chocolate',
      ];

      final catalogBloc = CatalogBloc(
        ingredientRepository: memIngredientRepo,
        packagingRepository: memPackagingRepo,
      )..add(const LoadCatalog());

      await expectLater(
        catalogBloc.stream,
        emitsThrough(isA<CatalogLoaded>()),
      );

      catalogBloc.add(DeleteIngredient(id: butter.id));

      await expectLater(
        catalogBloc.stream,
        emitsThrough(
          isA<CatalogLoaded>().having(
            (s) => s.lastDependencyBlock?.formattedBlockMessage,
            'formattedBlockMessage',
            "No se puede eliminar 'Mantequilla Gloria'. Está en uso en 3 recetas: [Pastel de Zanahoria, Torta Red Velvet, Ganache de Chocolate]",
          ),
        ),
      );
    });

    testWidgets(
      'Attempting to delete ingredient in use in 3 recipes blocks action, shows protective modal with exact BR-INT-02 message, and navigates to RecipeFormScreen on recipe tap',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final butter = createButterIngredient();
        final unused = createUnusedIngredient();
        await memIngredientRepo.saveIngredient(butter);
        await memIngredientRepo.saveIngredient(unused);
        memIngredientRepo.usageByIngredientId[butter.id] = [
          'Pastel de Zanahoria',
          'Torta Red Velvet',
          'Ganache de Chocolate',
        ];

        final r1 = createRecipeUsingButter(id: 'r1', name: 'Pastel de Zanahoria');
        final r2 = createRecipeUsingButter(id: 'r2', name: 'Torta Red Velvet');
        final r3 = createRecipeUsingButter(id: 'r3', name: 'Ganache de Chocolate');
        await memRecipeRepo.saveRecipe(r1);
        await memRecipeRepo.saveRecipe(r2);
        await memRecipeRepo.saveRecipe(r3);

        final catalogBloc = CatalogBloc(
          ingredientRepository: memIngredientRepo,
          packagingRepository: memPackagingRepo,
        )..add(const LoadCatalog());

        final recipesBloc = RecipesBloc(recipeRepository: memRecipeRepo)
          ..add(const LoadRecipes());

        await tester.pumpWidget(
          MultiRepositoryProvider(
            providers: [
              RepositoryProvider<IngredientRepository>.value(
                value: memIngredientRepo,
              ),
              RepositoryProvider<PackagingRepository>.value(
                value: memPackagingRepo,
              ),
              RepositoryProvider<RecipeRepository>.value(
                value: memRecipeRepo,
              ),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<CatalogBloc>.value(value: catalogBloc),
                BlocProvider<RecipesBloc>.value(value: recipesBloc),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const CatalogScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Both ingredients should be visible in CatalogScreen
        expect(find.text('Mantequilla Gloria'), findsOneWidget);
        expect(find.text('Esencia de Almendra'), findsOneWidget);

        // Tap delete button on 'Mantequilla Gloria' (used in 3 recipes)
        await tester.tap(
          find.byKey(const Key('btn_delete_ingredient_ing-mantequilla-gloria')),
        );
        await tester.pumpAndSettle();

        // Protective modal dialog must appear (RF-SYS-22, BR-INT-02)
        expect(
          find.byKey(const Key('dependency_protection_dialog')),
          findsOneWidget,
        );

        final msgWidget = tester.widget<Text>(
          find.byKey(const Key('dependency_block_message')),
        );
        expect(
          msgWidget.data,
          equals(
            "No se puede eliminar 'Mantequilla Gloria'. Está en uso en 3 recetas: [Pastel de Zanahoria, Torta Red Velvet, Ganache de Chocolate]",
          ),
        );

        // Verify CatalogBloc state remained CatalogLoaded (not CatalogError)
        expect(catalogBloc.state, isA<CatalogLoaded>());

        // Tap 'Pastel de Zanahoria' in the dialog to navigate directly to RecipeFormScreen (Acceptance Criterion 3)
        await tester.tap(
          find.byKey(const Key('affected_recipe_tile_Pastel de Zanahoria')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecipeFormScreen), findsOneWidget);
        expect(find.text('Editar Receta'), findsOneWidget);
      },
    );

    testWidgets(
      'Attempting to delete unused ingredient shows simple confirmation and deletes it cleanly (BR-INT-03)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final unused = createUnusedIngredient();
        await memIngredientRepo.saveIngredient(unused);

        final catalogBloc = CatalogBloc(
          ingredientRepository: memIngredientRepo,
          packagingRepository: memPackagingRepo,
        )..add(const LoadCatalog());

        await tester.pumpWidget(
          BlocProvider<CatalogBloc>.value(
            value: catalogBloc,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const CatalogScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Esencia de Almendra'), findsOneWidget);

        // Tap delete button on unused ingredient
        await tester.tap(
          find.byKey(const Key('btn_delete_ingredient_ing-esencia-almendra')),
        );
        await tester.pumpAndSettle();

        // Simple confirmation dialog must appear (BR-INT-03)
        expect(
          find.byKey(const Key('simple_delete_confirm_dialog')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('btn_confirm_simple_delete')));
        await tester.pumpAndSettle();

        // Ingredient must be deleted from UI and repository
        expect(find.text('Esencia de Almendra'), findsNothing);
        final inRepo = await memIngredientRepo.getIngredientById(unused.id);
        expect(inRepo, isNull);
      },
    );
  });
}
