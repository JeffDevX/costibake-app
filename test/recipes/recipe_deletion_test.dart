import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:costibake_app/core/constants/app_constants.dart';
import 'package:costibake_app/core/theme/app_theme.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_event.dart';
import 'package:costibake_app/features/recipes/presentation/screens/recipe_form_screen.dart';
import 'package:costibake_app/features/recipes/presentation/screens/recipes_screen.dart';

class _FakeRecipeRepo implements RecipeRepository {
  final List<Recipe> recipes = [];
  Map<String, List<String>> dependencyGraph = {};

  @override
  Future<List<Recipe>> getAllRecipes() async => List.of(recipes);

  @override
  Future<Recipe?> getRecipeById(String id) async =>
      recipes.where((r) => r.id == id).firstOrNull;

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
  Future<List<Recipe>> searchRecipes(String query, {String? status}) async =>
      recipes;

  @override
  Future<void> updateRecipeStatus(String recipeId, String newStatus) async {}

  @override
  Future<void> updateRecipeTimestamps(
      List<String> recipeIds, DateTime timestamp) async {}

  @override
  Future<Map<String, List<String>>> getSubRecipeDependencyGraph() async =>
      dependencyGraph;

  @override
  Future<Map<String, List<String>>> getRecipeIngredientGraph() async => {};

  @override
  Future<Map<String, List<String>>> getRecipePackagingGraph() async => {};
}

class _FakeIngredientRepo implements IngredientRepository {
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

class _FakePackagingRepo implements PackagingRepository {
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Recipe Deletion Unit & Widget Tests', () {
    late _FakeRecipeRepo fakeRepo;

    setUp(() {
      fakeRepo = _FakeRecipeRepo();
    });

    Recipe createTestRecipe({required String id, required String name}) {
      return Recipe(
        id: id,
        name: name,
        yieldPortions: 1,
        prepTimeMinutes: 10,
        bakeTimeMinutes: 10,
        moldType: 'Redondo',
        targetProfitMargin: PreciseDecimal.fromString('40.0'),
        status: AppConstants.recipeStatusActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    Widget createTestApp(Widget child, RecipesBloc bloc) {
      return MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RecipeRepository>.value(value: fakeRepo),
          RepositoryProvider<IngredientRepository>.value(value: _FakeIngredientRepo()),
          RepositoryProvider<PackagingRepository>.value(value: _FakePackagingRepo()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<RecipesBloc>.value(value: bloc),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: child,
          ),
        ),
      );
    }

    testWidgets('Tapping delete button on recipe card in RecipesScreen opens confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final r1 = createTestRecipe(id: 'rec-1', name: 'Flan de Vainilla');
      fakeRepo.recipes.add(r1);

      final bloc = RecipesBloc(recipeRepository: fakeRepo);
      bloc.add(const LoadRecipes());

      await tester.pumpWidget(createTestApp(const RecipesScreen(), bloc));
      await tester.pumpAndSettle();

      expect(find.text('Flan de Vainilla'), findsOneWidget);
      final deleteBtn = find.byKey(const Key('btn_delete_recipe_rec-1'));
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog_confirm_delete_recipe')), findsOneWidget);
      expect(find.textContaining('¿Estás seguro de que deseas eliminar permanentemente la receta "Flan de Vainilla"?'), findsOneWidget);
    });

    testWidgets('Canceling delete confirmation keeps recipe in list', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final r1 = createTestRecipe(id: 'rec-1', name: 'Flan de Vainilla');
      fakeRepo.recipes.add(r1);

      final bloc = RecipesBloc(recipeRepository: fakeRepo);
      bloc.add(const LoadRecipes());

      await tester.pumpWidget(createTestApp(const RecipesScreen(), bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_delete_recipe_rec-1')));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.byKey(const Key('btn_cancel_delete_recipe')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog_confirm_delete_recipe')), findsNothing);
      expect(find.text('Flan de Vainilla'), findsOneWidget);
      expect(fakeRepo.recipes.length, equals(1));
    });

    testWidgets('Confirming delete removes recipe from repository and updates UI', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final r1 = createTestRecipe(id: 'rec-1', name: 'Flan de Vainilla');
      fakeRepo.recipes.add(r1);

      final bloc = RecipesBloc(recipeRepository: fakeRepo);
      bloc.add(const LoadRecipes());

      await tester.pumpWidget(createTestApp(const RecipesScreen(), bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_delete_recipe_rec-1')));
      await tester.pumpAndSettle();

      // Tap Confirm Delete
      await tester.tap(find.byKey(const Key('btn_confirm_delete_recipe')));
      await tester.pumpAndSettle();

      expect(fakeRepo.recipes, isEmpty);
      expect(find.text('Flan de Vainilla'), findsNothing);
      expect(find.textContaining('eliminada'), findsOneWidget);
    });

    testWidgets('Attempting to delete a recipe in use as subrecipe blocks deletion with warning', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sub = createTestRecipe(id: 'sub-crema', name: 'Crema Pastelera');
      final master = createTestRecipe(id: 'master-torta', name: 'Torta Selva Negra');
      fakeRepo.recipes.addAll([sub, master]);
      fakeRepo.dependencyGraph = {
        'master-torta': ['sub-crema'],
      };

      final bloc = RecipesBloc(recipeRepository: fakeRepo);
      bloc.add(const LoadRecipes());

      await tester.pumpWidget(createTestApp(const RecipesScreen(), bloc));
      await tester.pumpAndSettle();

      // Tap delete on sub-crema
      await tester.tap(find.byKey(const Key('btn_delete_recipe_sub-crema')));
      await tester.pumpAndSettle();

      // Protection dialog must appear
      expect(find.byKey(const Key('dialog_subrecipe_protection')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('dialog_subrecipe_protection')),
          matching: find.textContaining('Torta Selva Negra'),
        ),
        findsOneWidget,
      );
      expect(fakeRepo.recipes.length, equals(2));

      // Dismiss dialog
      await tester.tap(find.byKey(const Key('btn_close_subrecipe_protection_dialog')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog_subrecipe_protection')), findsNothing);
      expect(fakeRepo.recipes.length, equals(2));
    });

    testWidgets('RecipeFormScreen AppBar has delete button that pops and deletes recipe', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final r1 = createTestRecipe(id: 'rec-1', name: 'Galletas de Canela');
      fakeRepo.recipes.add(r1);

      final bloc = RecipesBloc(recipeRepository: fakeRepo);

      await tester.pumpWidget(createTestApp(RecipeFormScreen(recipeToEdit: r1), bloc));
      await tester.pumpAndSettle();

      final deleteAppBarBtn = find.byKey(const Key('btn_delete_recipe_form'));
      expect(deleteAppBarBtn, findsOneWidget);

      await tester.tap(deleteAppBarBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dialog_confirm_delete_recipe')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_confirm_delete_recipe')));
      await tester.pumpAndSettle();

      expect(fakeRepo.recipes, isEmpty);
    });
  });
}
