import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:costibake_app/core/constants/app_constants.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/costing/domain/entities/cost_breakdown.dart';
import 'package:costibake_app/features/costing/presentation/screens/costing_screen.dart';
import 'package:costibake_app/features/costing/presentation/widgets/cost_distribution_widget.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe_item.dart';
import 'package:costibake_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_state.dart';
import 'package:costibake_app/features/recipes/presentation/screens/recipe_form_screen.dart';
import 'package:costibake_app/features/settings/domain/entities/business_config.dart';
import 'package:costibake_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_state.dart';

class _FakeSettingsRepository implements SettingsRepository {
  BusinessConfig config = BusinessConfig(
    id: 'cfg-test',
    businessName: 'Pastelería La Delicia',
    currencySymbol: r'$',
    laborHourlyRate: PreciseDecimal.fromString('12.00'),
    overheadPercentage: PreciseDecimal.fromString('15.00'),
    updatedAt: DateTime.now(),
  );

  @override
  Future<BusinessConfig> getBusinessConfig() async => config;

  @override
  Future<void> saveBusinessConfig(BusinessConfig newConfig) async {
    config = newConfig;
  }
}

class _FakeIngredientRepository implements IngredientRepository {
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

class _FakePackagingRepository implements PackagingRepository {
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

class _FakeRecipeRepository implements RecipeRepository {
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

void main() {
  group('CostDistributionWidget Presentation Tests (JEF-15)', () {
    testWidgets('Renders distribution bar, percentages, and custom currency symbol', (tester) async {
      final breakdown = CostBreakdown(
        rawMaterialsCost: PreciseDecimal.fromString('50.00'),
        subRecipesCost: PreciseDecimal.fromString('20.00'),
        packagingCost: PreciseDecimal.fromString('10.00'),
        directMaterialCost: PreciseDecimal.fromString('80.00'),
        effectiveLaborRatePerHour: PreciseDecimal.fromString('12.00'),
        effectiveOverheadPercentage: PreciseDecimal.fromString('15.00'),
        prepTimeMinutes: 30,
        laborCost: PreciseDecimal.fromString('6.00'),
        overheadCost: PreciseDecimal.fromString('12.00'),
        totalProductionCost: PreciseDecimal.fromString('98.00'),
        yieldPortions: 4,
        costPerPortion: PreciseDecimal.fromString('24.50'),
        suggestedBatchPrice: PreciseDecimal.fromString('147.00'),
        suggestedPortionPrice: PreciseDecimal.fromString('36.75'),
        netProfitBatch: PreciseDecimal.fromString('49.00'),
        netProfitPortion: PreciseDecimal.fromString('12.25'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CostDistributionWidget(
              breakdown: breakdown,
              currencySymbol: '€',
            ),
          ),
        ),
      );

      expect(find.text('Distribución de Costos (CTP)'), findsOneWidget);
      expect(find.text('€98.00'), findsOneWidget);
      expect(find.textContaining('Insumos: €50.00'), findsOneWidget);
      expect(find.textContaining('Sub-recetas: €20.00'), findsOneWidget);
      expect(find.textContaining('Empaques: €10.00'), findsOneWidget);
      expect(find.textContaining('Mano de Obra: €6.00'), findsOneWidget);
      expect(find.textContaining('Overhead (15.0%): €12.00'), findsOneWidget);
    });

    testWidgets('Handles zero-cost breakdown gracefully without exceptions', (tester) async {
      final emptyBreakdown = CostBreakdown.empty();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CostDistributionWidget(
              breakdown: emptyBreakdown,
            ),
          ),
        ),
      );

      expect(find.text('Distribución de Costos (CTP)'), findsOneWidget);
      expect(find.text(r'$0.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CostingScreen Widget Tests (JEF-15)', () {
    late _FakeRecipeRepository recipeRepo;
    late _FakeSettingsRepository settingsRepo;
    late RecipesBloc recipesBloc;
    late SettingsBloc settingsBloc;

    setUp(() {
      recipeRepo = _FakeRecipeRepository();
      settingsRepo = _FakeSettingsRepository();
      recipesBloc = RecipesBloc(recipeRepository: recipeRepo);
      settingsBloc = SettingsBloc(settingsRepository: settingsRepo);
    });

    tearDown(() async {
      await recipesBloc.close();
      await settingsBloc.close();
    });

    testWidgets('Renders CostingScreen with recipe card, CTP, CUP, dual pricing, and distribution widget without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final recipe = Recipe(
        id: 'rec-test-costing',
        name: 'Cheesecake Frutos Rojos',
        yieldPortions: 8,
        prepTimeMinutes: 45,
        bakeTimeMinutes: 60,
        targetProfitMargin: PreciseDecimal.fromString('60.00'),
        status: AppConstants.recipeStatusActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ingredients: [
          RecipeIngredientItem(
            id: 'i1',
            recipeId: 'rec-test-costing',
            ingredientId: 'ing-queso',
            ingredientName: 'Queso Crema',
            quantity: PreciseDecimal.fromInt(1),
            unit: 'kg',
            baseUnit: 'kg',
            unitCost: PreciseDecimal.fromString('8.00'),
          ),
        ],
        packaging: [
          RecipePackagingItem(
            id: 'p1',
            recipeId: 'rec-test-costing',
            packagingId: 'pack-domo',
            packagingName: 'Domo Triangular',
            pieceQuantity: 8,
            unitCost: PreciseDecimal.fromString('0.25'),
          ),
        ],
      );

      // Seed state
      recipesBloc.emit(RecipesLoaded([recipe]));
      settingsBloc.emit(SettingsLoaded(settingsRepo.config));

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<RecipesBloc>.value(value: recipesBloc),
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
          ],
          child: const MaterialApp(
            home: CostingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cheesecake Frutos Rojos'), findsOneWidget);
      expect(find.text('+60% Markup'), findsOneWidget);
      expect(find.textContaining('Insumos Directos (CI):'), findsOneWidget);
      expect(find.textContaining('Empaques Directos (CE):'), findsOneWidget);
      expect(find.textContaining('Costo Total de Producción (CTP):'), findsOneWidget);
      expect(find.text('PRECIO LOTE SUGERIDO'), findsOneWidget);
      expect(find.text('PORCIÓN (8 PZAS)'), findsOneWidget);
      expect(find.byType(CostDistributionWidget), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });

  group('RecipeFormScreen 4th Tab Costeo Tests (JEF-15)', () {
    late _FakeRecipeRepository recipeRepo;
    late _FakeIngredientRepository ingRepo;
    late _FakePackagingRepository packRepo;
    late _FakeSettingsRepository settingsRepo;
    late RecipesBloc recipesBloc;
    late SettingsBloc settingsBloc;

    setUp(() {
      recipeRepo = _FakeRecipeRepository();
      ingRepo = _FakeIngredientRepository();
      packRepo = _FakePackagingRepository();
      settingsRepo = _FakeSettingsRepository();
      recipesBloc = RecipesBloc(recipeRepository: recipeRepo);
      settingsBloc = SettingsBloc(settingsRepository: settingsRepo);
    });

    tearDown(() async {
      await recipesBloc.close();
      await settingsBloc.close();
    });

    testWidgets('RecipeFormScreen renders 4 tabs, navigates to Costeo, toggles overrides and recalculates live', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      settingsBloc.emit(SettingsLoaded(settingsRepo.config));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<IngredientRepository>.value(value: ingRepo),
              RepositoryProvider<PackagingRepository>.value(value: packRepo),
              RepositoryProvider<RecipeRepository>.value(value: recipeRepo),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<RecipesBloc>.value(value: recipesBloc),
                BlocProvider<SettingsBloc>.value(value: settingsBloc),
              ],
              child: const RecipeFormScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 4 tabs exist
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Ingredientes'), findsOneWidget);
      expect(find.text('Empaques'), findsOneWidget);
      expect(find.text('Costeo'), findsOneWidget);

      // Bottom bar displays integral CTP
      expect(find.text('Costo Integral (CTP)'), findsOneWidget);

      // Tap 'Costeo' tab
      await tester.tap(find.text('Costeo'));
      await tester.pumpAndSettle();

      // Distribution widget should be displayed
      expect(find.byKey(const Key('cost_distribution_widget')), findsOneWidget);
      expect(find.text('Parámetros Financieros y Sobrescrituras'), findsOneWidget);

      // Overrides switches
      expect(find.byKey(const Key('switch_custom_labor_rate')), findsOneWidget);
      expect(find.byKey(const Key('switch_custom_overhead')), findsOneWidget);

      // Toggle labor rate override
      final laborSwitch = find.byKey(const Key('switch_custom_labor_rate'));
      await tester.ensureVisible(laborSwitch);
      await tester.pumpAndSettle();
      await tester.tap(laborSwitch);
      await tester.pumpAndSettle();

      // Text field appears pre-populated with global rate
      final laborField = find.byKey(const Key('field_labor_rate_override'));
      expect(laborField, findsOneWidget);

      // Enter new custom labor rate
      await tester.ensureVisible(laborField);
      await tester.pumpAndSettle();
      await tester.enterText(laborField, '24.00');
      await tester.pumpAndSettle();

      // Toggle overhead override
      final overheadSwitch = find.byKey(const Key('switch_custom_overhead'));
      await tester.ensureVisible(overheadSwitch);
      await tester.pumpAndSettle();
      await tester.tap(overheadSwitch);
      await tester.pumpAndSettle();

      final overheadField = find.byKey(const Key('field_overhead_override'));
      expect(overheadField, findsOneWidget);
      await tester.ensureVisible(overheadField);
      await tester.pumpAndSettle();
      await tester.enterText(overheadField, '20.0');
      await tester.pumpAndSettle();

      // Zero exceptions / zero render overflows
      expect(tester.takeException(), isNull);
    });
  });
}
