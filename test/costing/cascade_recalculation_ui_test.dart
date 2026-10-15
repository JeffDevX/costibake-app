import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/theme/app_theme.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_state.dart';
import 'package:costibake_app/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:costibake_app/features/costing/domain/entities/cascade_recalculation_result.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_bloc.dart';

class _FakeIngredientRepo implements IngredientRepository {
  final List<Ingredient> ingredients = [];
  @override
  Future<List<Ingredient>> getAllIngredients() async => ingredients;
  @override
  Future<Ingredient?> getIngredientById(String id) async => null;
  @override
  Future<List<Ingredient>> searchIngredients(String query, {String? category}) async => ingredients;
  @override
  Future<void> saveIngredient(Ingredient ingredient) async => ingredients.add(ingredient);
  @override
  Future<void> deleteIngredient(String id, {bool force = false}) async {}
  @override
  Future<List<String>> getRecipesUsingIngredient(String ingredientId) async => [];
}

class _FakePackagingRepo implements PackagingRepository {
  final List<Packaging> packagings = [];
  @override
  Future<List<Packaging>> getAllPackaging() async => packagings;
  @override
  Future<Packaging?> getPackagingById(String id) async => null;
  @override
  Future<List<Packaging>> searchPackaging(String query, {String? category}) async => packagings;
  @override
  Future<void> savePackaging(Packaging packaging) async => packagings.add(packaging);
  @override
  Future<void> deletePackaging(String id, {bool force = false}) async {}
  @override
  Future<List<String>> getRecipesUsingPackaging(String packagingId) async => [];
}

class _FakeRecipeRepo implements RecipeRepository {
  @override
  Future<List<Recipe>> getAllRecipes() async => [];
  @override
  Future<Recipe?> getRecipeById(String id) async => null;
  @override
  Future<List<Recipe>> searchRecipes(String query, {String? status}) async => [];
  @override
  Future<void> saveRecipe(Recipe recipe) async {}
  @override
  Future<void> deleteRecipe(String id) async {}
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

void main() {
  group('Cascade Recalculation UI Tests (JEF-9, BR-PRC-04)', () {
    testWidgets('CatalogScreen displays SnackBar notification when cascade recalculation finishes', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final ingRepo = _FakeIngredientRepo();
      final packRepo = _FakePackagingRepo();
      final recipeRepo = _FakeRecipeRepo();

      final catalogBloc = CatalogBloc(
        ingredientRepository: ingRepo,
        packagingRepository: packRepo,
      );

      final recipesBloc = RecipesBloc(recipeRepository: recipeRepo);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<CatalogBloc>.value(value: catalogBloc),
            BlocProvider<RecipesBloc>.value(value: recipesBloc),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CatalogScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Emit a state with lastCascadeResult (simulating cascade completion of 3 recipes)
      final cascadeResult = CascadeRecalculationResult(
        ingredientId: 'ing_butter',
        ingredientName: 'Mantequilla sin sal',
        oldCost: PreciseDecimal.fromString('3.00'),
        newCost: PreciseDecimal.fromString('4.50'),
        affectedRecipeIds: const ['r1', 'r2', 'r3'],
        affectedRecipeNames: const ['Bizcocho', 'Pastel Fiesta', 'Milhojas'],
        elapsedMilliseconds: 18,
        timestamp: DateTime.now(),
      );

      catalogBloc.emit(CatalogLoaded(
        ingredients: const [],
        packagings: const [],
        lastCascadeResult: cascadeResult,
      ));

      await tester.pump(); // Start SnackBar animation
      await tester.pump(const Duration(milliseconds: 300)); // Allow animation to settle

      // Verify BR-PRC-04 message rendered in SnackBar
      expect(
        find.text('Precio de Mantequilla sin sal actualizado. 3 recetas fueron recalculadas exitosamente.'),
        findsOneWidget,
      );

      // Verify no RenderFlex overflow on compact 360x640 mobile screen
      expect(tester.takeException(), isNull);
    });
  });
}
