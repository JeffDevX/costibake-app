import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/recipes/domain/entities/ai_recipe_extraction.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:costibake_app/features/recipes/presentation/screens/ai_recipe_preview_screen.dart';

class MockRecipeRepository implements RecipeRepository {
  final List<Recipe> savedRecipes = [];

  @override
  Future<List<Recipe>> getAllRecipes() async => savedRecipes;

  @override
  Future<Recipe?> getRecipeById(String id) async =>
      savedRecipes.where((r) => r.id == id).firstOrNull;

  @override
  Future<void> saveRecipe(Recipe recipe) async {
    savedRecipes.add(recipe);
  }

  @override
  Future<void> deleteRecipe(String id) async {
    savedRecipes.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<Recipe>> searchRecipes(String query, {String? status}) async =>
      savedRecipes;

  @override
  Future<void> updateRecipeStatus(String recipeId, String newStatus) async {}

  @override
  Future<void> updateRecipeTimestamps(List<String> recipeIds, DateTime timestamp) async {}

  @override
  Future<Map<String, List<String>>> getSubRecipeDependencyGraph() async => {};

  @override
  Future<Map<String, List<String>>> getRecipeIngredientGraph() async => {};

  @override
  Future<Map<String, List<String>>> getRecipePackagingGraph() async => {};
}

void main() {
  group('AiRecipePreviewScreen Widget Tests', () {
    late MockRecipeRepository mockRecipeRepo;
    late List<Ingredient> catalog;
    late AiRecipeExtraction extraction;

    setUp(() {
      mockRecipeRepo = MockRecipeRepository();
      catalog = [
        Ingredient(
          id: 'cat-harina',
          name: 'Harina de Trigo Todo Uso',
          category: 'Harinas y Secos',
          purchaseCost: PreciseDecimal.fromString('2.50'),
          purchaseQuantity: PreciseDecimal.fromString('1000'),
          purchaseUnit: 'g',
          wastePercentage: PreciseDecimal.zero,
          minimumUnitCost: PreciseDecimal.fromString('0.0025'),
          minimumUnit: 'g',
          updatedAt: DateTime.now(),
        ),
        Ingredient(
          id: 'cat-azucar',
          name: 'Azúcar Refinada',
          category: 'Azúcares y Endulzantes',
          purchaseCost: PreciseDecimal.fromString('1.80'),
          purchaseQuantity: PreciseDecimal.fromString('1000'),
          purchaseUnit: 'g',
          wastePercentage: PreciseDecimal.zero,
          minimumUnitCost: PreciseDecimal.fromString('0.0018'),
          minimumUnit: 'g',
          updatedAt: DateTime.now(),
        ),
      ];

      extraction = AiRecipeExtraction(
        title: 'Bizcocho Genovés',
        yieldPortions: 8,
        prepTimeMinutes: 20,
        bakeTimeMinutes: 35,
        moldType: 'Redondo',
        moldDimension: '20 cm / 8 in',
        ingredients: [
          AiExtractedIngredient(
            name: 'Harina de Trigo Todo Uso',
            quantity: PreciseDecimal.fromString('200'),
            unit: 'g',
            section: 'Bizcocho',
            matchedCatalogIngredientId: 'cat-harina',
            matchedCatalogIngredientName: 'Harina de Trigo Todo Uso',
          ),
          AiExtractedIngredient(
            name: 'Azúcar Refinada',
            quantity: PreciseDecimal.fromString('150'),
            unit: 'g',
            section: 'Bizcocho',
            matchedCatalogIngredientId: 'cat-azucar',
            matchedCatalogIngredientName: 'Azúcar Refinada',
          ),
        ],
        steps: const ['Batir huevos con azúcar', 'Incorporar harina tamizada'],
        notes: 'Precalentar el horno a 180°C',
      );
    });

    Widget createTestWidget() {
      return RepositoryProvider<RecipeRepository>.value(
        value: mockRecipeRepo,
        child: BlocProvider<RecipesBloc>(
          create: (_) => RecipesBloc(recipeRepository: mockRecipeRepo),
          child: MaterialApp(
            home: AiRecipePreviewScreen(
              extraction: extraction,
              catalog: catalog,
            ),
          ),
        ),
      );
    }

    testWidgets('renders all recipe details and costs without overflow on 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Previsualización de Receta (IA)'), findsOneWidget);
      expect(find.text('Bizcocho Genovés'), findsOneWidget);
      expect(find.text('Costeo Preliminar de Insumos'), findsOneWidget);

      // Cost calculation check:
      // 200g * $0.0025 = $0.50
      // 150g * $0.0018 = $0.27
      // Total = $0.77
      expect(find.text(r'$0.77'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('allows editing ingredient quantity and updates cost reactively', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text(r'$0.77'), findsOneWidget);

      // Tap edit on the first ingredient
      final editButton = find.byIcon(Icons.edit_rounded).first;
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Enter 400g instead of 200g
      final qtyInput = find.widgetWithText(TextField, 'Nueva Cantidad (g)');
      await tester.enterText(qtyInput, '400');
      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();

      // New cost:
      // 400g * $0.0025 = $1.00
      // 150g * $0.0018 = $0.27
      // Total = $1.27
      expect(find.text(r'$1.27'), findsOneWidget);
    });

    testWidgets('allows removing an ingredient', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Ingredientes (2)'), findsOneWidget);

      final deleteButton = find.byIcon(Icons.delete_outline_rounded).first;
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Ingredientes (1)'), findsOneWidget);
    });

    testWidgets('saves recipe with full ingredient linking into RecipeRepository', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Guardar y Costear Receta
      final saveBtn = find.byKey(const Key('btn_save_and_cost_recipe'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify recipe was saved in repository
      expect(mockRecipeRepo.savedRecipes.length, equals(1));
      final saved = mockRecipeRepo.savedRecipes.first;
      expect(saved.name, equals('Bizcocho Genovés'));
      expect(saved.yieldPortions, equals(8));
      expect(saved.ingredients.length, equals(2));
      expect(saved.ingredients[0].ingredientId, equals('cat-harina'));
      expect(saved.ingredients[1].ingredientId, equals('cat-azucar'));
    });
  });
}
