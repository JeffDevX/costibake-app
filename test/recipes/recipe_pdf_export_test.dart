import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:costibake_app/core/constants/app_constants.dart';
import 'package:costibake_app/core/theme/app_theme.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/costing/domain/entities/pricing_strategy.dart';
import 'package:costibake_app/features/costing/domain/services/costing_calculation_engine.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe_item.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe_pdf_document_type.dart';
import 'package:costibake_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:costibake_app/features/recipes/domain/services/recipe_pdf_generator.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_event.dart';
import 'package:costibake_app/features/recipes/presentation/screens/recipe_form_screen.dart';
import 'package:costibake_app/features/recipes/presentation/screens/recipes_screen.dart';
import 'package:costibake_app/features/recipes/presentation/widgets/recipe_pdf_export_dialog.dart';
import 'package:costibake_app/features/settings/domain/entities/business_config.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';

class _TestRecipeRepo implements RecipeRepository {
  final List<Recipe> items = [];

  _TestRecipeRepo([List<Recipe>? initial]) {
    if (initial != null) items.addAll(initial);
  }

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
    final idx = items.indexWhere((r) => r.id == recipe.id);
    if (idx != -1) {
      items[idx] = recipe;
    } else {
      items.add(recipe);
    }
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

class _TestIngredientRepo implements IngredientRepository {
  final List<Ingredient> items = [];
  _TestIngredientRepo([List<Ingredient>? initial]) {
    if (initial != null) items.addAll(initial);
  }

  @override
  Future<List<Ingredient>> getAllIngredients() async => List.of(items);

  @override
  Future<Ingredient?> getIngredientById(String id) async =>
      items.where((i) => i.id == id).firstOrNull;

  @override
  Future<List<Ingredient>> searchIngredients(String query, {String? category}) async =>
      items;

  @override
  Future<void> saveIngredient(Ingredient ingredient) async {
    items.removeWhere((i) => i.id == ingredient.id);
    items.add(ingredient);
  }

  @override
  Future<void> deleteIngredient(String id, {bool force = false}) async {
    items.removeWhere((i) => i.id == id);
  }

  @override
  Future<List<String>> getRecipesUsingIngredient(String ingredientId) async =>
      const [];
}

class _TestPackagingRepo implements PackagingRepository {
  final List<Packaging> items = [];
  _TestPackagingRepo([List<Packaging>? initial]) {
    if (initial != null) items.addAll(initial);
  }

  @override
  Future<List<Packaging>> getAllPackaging() async => List.of(items);

  @override
  Future<Packaging?> getPackagingById(String id) async =>
      items.where((p) => p.id == id).firstOrNull;

  @override
  Future<List<Packaging>> searchPackaging(String query, {String? category}) async =>
      items;

  @override
  Future<void> savePackaging(Packaging packaging) async {
    items.removeWhere((p) => p.id == packaging.id);
    items.add(packaging);
  }

  @override
  Future<void> deletePackaging(String id, {bool force = false}) async {
    items.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<String>> getRecipesUsingPackaging(String packagingId) async =>
      const [];
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final testConfig = BusinessConfig(
    id: 'cfg-1',
    businessName: 'Pastelería Dulce Arte',
    currencySymbol: '\$',
    laborHourlyRate: PreciseDecimal.fromString('15.00'),
    overheadPercentage: PreciseDecimal.fromString('20.00'),
    updatedAt: DateTime.now(),
  );

  final testRecipe = Recipe(
    id: 'rec-test-1',
    name: 'Pastel Redondo de Vainilla y Frutos Rojos',
    description: 'Batir huevos con azúcar hasta punto de letra. Hornear a 180°C por 35 minutos.',
    yieldPortions: 12,
    prepTimeMinutes: 45,
    bakeTimeMinutes: 35,
    moldType: 'Redondo',
    moldDimension: '20 cm / 8 in',
    targetProfitMargin: PreciseDecimal.fromString('40.0'),
    pricingMode: PricingMode.markupOnCost,
    roundingRule: RoundingRule.ceil0_50,
    status: AppConstants.recipeStatusActive,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    ingredients: [
      RecipeIngredientItem(
        id: 'ri-1',
        recipeId: 'rec-test-1',
        ingredientId: 'ing-1',
        ingredientName: 'Harina de Trigo Especial',
        quantity: PreciseDecimal.fromString('250.00'),
        unit: 'g',
        section: 'Bizcocho',
        unitCost: PreciseDecimal.fromString('0.0018'),
        baseUnit: 'g',
      ),
      RecipeIngredientItem(
        id: 'ri-2',
        recipeId: 'rec-test-1',
        ingredientId: 'ing-2',
        ingredientName: 'Azúcar Refinada',
        quantity: PreciseDecimal.fromString('200.00'),
        unit: 'g',
        section: 'Bizcocho',
        unitCost: PreciseDecimal.fromString('0.0022'),
        baseUnit: 'g',
      ),
      RecipeIngredientItem(
        id: 'ri-3',
        recipeId: 'rec-test-1',
        ingredientId: 'ing-3',
        ingredientName: 'Mantequilla Sin Sal',
        quantity: PreciseDecimal.fromString('150.00'),
        unit: 'g',
        section: 'Relleno',
        unitCost: PreciseDecimal.fromString('0.0085'),
        baseUnit: 'g',
      ),
    ],
    packaging: [
      RecipePackagingItem(
        id: 'rp-1',
        recipeId: 'rec-test-1',
        packagingId: 'pack-1',
        packagingName: 'Caja para Pastel 10 Pulgadas',
        pieceQuantity: 1,
        unitCost: PreciseDecimal.fromString('1.25'),
      ),
      RecipePackagingItem(
        id: 'rp-2',
        recipeId: 'rec-test-1',
        packagingId: 'pack-2',
        packagingName: 'Base Dorada 24 cm',
        pieceQuantity: 1,
        unitCost: PreciseDecimal.fromString('0.60'),
      ),
    ],
  );

  final incompleteRecipe = testRecipe.copyWith(
    id: 'rec-incomplete-1',
    name: 'Pastel con Insumo Huérfano',
    status: AppConstants.recipeStatusIncomplete,
    ingredients: [
      testRecipe.ingredients[0],
      RecipeIngredientItem(
        id: 'ri-orphan',
        recipeId: 'rec-incomplete-1',
        ingredientId: 'ing-deleted',
        ingredientName: 'Cacao Holandés [ELIMINADO]',
        quantity: PreciseDecimal.fromString('80.00'),
        unit: 'g',
        section: 'Cobertura',
        unitCost: PreciseDecimal.zero,
        baseUnit: 'g',
        isDeleted: true,
      ),
    ],
  );

  group('JEF-26 (RF-SYS-27): RecipePdfGenerator Unit Tests', () {
    test('BR-EXP-01 & BR-EXP-02: Generates Production Sheet with privacy of financial costs', () async {
      final breakdown = CostingCalculationEngine.calculate(
        recipe: testRecipe,
        config: testConfig,
      );

      // Verify DOM structure
      final doc = RecipePdfGenerator.buildPdfDocument(
        recipe: testRecipe,
        config: testConfig,
        costBreakdown: breakdown,
        documentType: RecipePdfDocumentType.productionSheet,
      );
      expect(doc.document.pdfPageList.pages, isNotEmpty);

      final pdfBytes = await RecipePdfGenerator.generatePdf(
        recipe: testRecipe,
        config: testConfig,
        costBreakdown: breakdown,
        documentType: RecipePdfDocumentType.productionSheet,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(2000));

      // Verify PDF magic header bytes: %PDF-
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('BR-EXP-03: Generates Financial Technical Sheet with integral quadruple cost breakdown', () async {
      final breakdown = CostingCalculationEngine.calculate(
        recipe: testRecipe,
        config: testConfig,
      );

      final doc = RecipePdfGenerator.buildPdfDocument(
        recipe: testRecipe,
        config: testConfig,
        costBreakdown: breakdown,
        documentType: RecipePdfDocumentType.financialSheet,
      );
      expect(doc.document.pdfPageList.pages, isNotEmpty);

      final pdfBytes = await RecipePdfGenerator.generatePdf(
        recipe: testRecipe,
        config: testConfig,
        costBreakdown: breakdown,
        documentType: RecipePdfDocumentType.financialSheet,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(2000));

      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('BR-EXP-04: Builds both sheets correctly when recipe has orphaned items', () async {
      final breakdown = CostingCalculationEngine.calculate(
        recipe: incompleteRecipe,
        config: testConfig,
      );

      // 1. Production Sheet for incomplete recipe
      final prodDoc = RecipePdfGenerator.buildPdfDocument(
        recipe: incompleteRecipe,
        config: testConfig,
        costBreakdown: breakdown,
        documentType: RecipePdfDocumentType.productionSheet,
      );
      expect(prodDoc.document.pdfPageList.pages, isNotEmpty);

      final prodBytes = await RecipePdfGenerator.generatePdf(
        recipe: incompleteRecipe,
        config: testConfig,
        costBreakdown: breakdown,
        documentType: RecipePdfDocumentType.productionSheet,
      );
      expect(prodBytes.length, greaterThan(2000));

      // 2. Financial Sheet for incomplete recipe
      final finDoc = RecipePdfGenerator.buildPdfDocument(
        recipe: incompleteRecipe,
        config: testConfig,
        costBreakdown: breakdown,
        documentType: RecipePdfDocumentType.financialSheet,
      );
      expect(finDoc.document.pdfPageList.pages, isNotEmpty);

      final finBytes = await RecipePdfGenerator.generatePdf(
        recipe: incompleteRecipe,
        config: testConfig,
        costBreakdown: breakdown,
        documentType: RecipePdfDocumentType.financialSheet,
      );
      expect(finBytes.length, greaterThan(2000));
    });
  });

  group('JEF-26: RecipePdfExportDialog Widget Tests', () {
    testWidgets('Renders modal dialog without overflow on compact 360x640 mobile screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RecipePdfExportDialog(
              recipe: testRecipe,
              businessConfig: testConfig,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recipe_pdf_export_dialog')), findsOneWidget);
      expect(find.text('Exportar Receta en PDF'), findsOneWidget);
      expect(find.byKey(const Key('radio_export_production_sheet')), findsOneWidget);
      expect(find.byKey(const Key('radio_export_financial_sheet')), findsOneWidget);
      expect(find.byKey(const Key('btn_preview_print_pdf')), findsOneWidget);
      expect(find.byKey(const Key('btn_share_pdf')), findsOneWidget);
      expect(find.byKey(const Key('btn_cancel_export_dialog')), findsOneWidget);

      // Ensure no overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Toggles between Production and Financial sheet options', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RecipePdfExportDialog(
              recipe: testRecipe,
              businessConfig: testConfig,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap financial sheet option
      final finOpt = find.byKey(const Key('radio_export_financial_sheet'));
      await tester.ensureVisible(finOpt);
      await tester.pumpAndSettle();
      await tester.tap(finOpt);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Calls onCustomPrint with proper filename when print/preview is tapped', (tester) async {
      Uint8List? printedBytes;
      String? printedFilename;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RecipePdfExportDialog(
              recipe: testRecipe,
              businessConfig: testConfig,
              onCustomPrint: (bytes, filename) async {
                printedBytes = bytes;
                printedFilename = filename;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final printBtn = find.byKey(const Key('btn_preview_print_pdf'));
      await tester.tap(printBtn);
      await tester.pumpAndSettle();

      expect(printedBytes, isNotNull);
      expect(printedBytes!.isNotEmpty, isTrue);
      expect(printedFilename, contains('ficha_produccion_'));
      expect(printedFilename, endsWith('.pdf'));
    });

    testWidgets('Calls onCustomShare with proper filename when share is tapped', (tester) async {
      Uint8List? sharedBytes;
      String? sharedFilename;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RecipePdfExportDialog(
              recipe: testRecipe,
              businessConfig: testConfig,
              onCustomShare: (bytes, filename) async {
                sharedBytes = bytes;
                sharedFilename = filename;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to financial sheet
      await tester.tap(find.byKey(const Key('radio_export_financial_sheet')));
      await tester.pumpAndSettle();

      final shareBtn = find.byKey(const Key('btn_share_pdf'));
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      expect(sharedBytes, isNotNull);
      expect(sharedBytes!.isNotEmpty, isTrue);
      expect(sharedFilename, contains('ficha_financiera_'));
      expect(sharedFilename, endsWith('.pdf'));
    });

    testWidgets('Displays incomplete recipe alert when recipe has orphaned items', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RecipePdfExportDialog(
              recipe: incompleteRecipe,
              businessConfig: testConfig,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Receta Incompleta'), findsOneWidget);
    });
  });

  group('JEF-26: Integration in Recipe Screens', () {
    late _TestRecipeRepo recipeRepo;
    late _TestIngredientRepo ingRepo;
    late _TestPackagingRepo packRepo;

    setUp(() {
      recipeRepo = _TestRecipeRepo([testRecipe]);
      ingRepo = _TestIngredientRepo();
      packRepo = _TestPackagingRepo();
    });

    testWidgets('RecipesScreen displays Exportar PDF button on recipe cards and opens export dialog', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final recipesBloc = RecipesBloc(recipeRepository: recipeRepo);
      recipesBloc.add(const LoadRecipes());

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<RecipeRepository>.value(value: recipeRepo),
            RepositoryProvider<IngredientRepository>.value(value: ingRepo),
            RepositoryProvider<PackagingRepository>.value(value: packRepo),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<RecipesBloc>.value(value: recipesBloc),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const RecipesScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exportCardBtn = find.byKey(Key('btn_export_pdf_${testRecipe.id}'));
      expect(exportCardBtn, findsOneWidget);

      await tester.tap(exportCardBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recipe_pdf_export_dialog')), findsOneWidget);
    });

    testWidgets('RecipeFormScreen AppBar has btn_export_recipe_pdf and opens export dialog', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final recipesBloc = RecipesBloc(recipeRepository: recipeRepo)..add(const LoadRecipes());

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<RecipeRepository>.value(value: recipeRepo),
            RepositoryProvider<IngredientRepository>.value(value: ingRepo),
            RepositoryProvider<PackagingRepository>.value(value: packRepo),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<RecipesBloc>.value(value: recipesBloc),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: RecipeFormScreen(
                recipeToEdit: testRecipe,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exportAppBarBtn = find.byKey(const Key('btn_export_recipe_pdf'));
      expect(exportAppBarBtn, findsOneWidget);

      await tester.tap(exportAppBarBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recipe_pdf_export_dialog')), findsOneWidget);
    });

    testWidgets('RecipeFormScreen Costeo Tab has btn_export_pdf_costing_tab and opens dialog', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final recipesBloc = RecipesBloc(recipeRepository: recipeRepo)..add(const LoadRecipes());

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<RecipeRepository>.value(value: recipeRepo),
            RepositoryProvider<IngredientRepository>.value(value: ingRepo),
            RepositoryProvider<PackagingRepository>.value(value: packRepo),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<RecipesBloc>.value(value: recipesBloc),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: RecipeFormScreen(
                recipeToEdit: testRecipe,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Costeo Tab
      await tester.tap(find.text('Costeo'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('btn_export_pdf_costing_tab')),
        100,
        scrollable: find.descendant(
          of: find.byKey(const Key('recipe_form_costing_tab_list')),
          matching: find.byType(Scrollable),
        ).first,
      );
      await tester.pumpAndSettle();

      final exportCostingBtn = find.byKey(const Key('btn_export_pdf_costing_tab'));
      expect(exportCostingBtn, findsOneWidget);

      await tester.tap(exportCostingBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recipe_pdf_export_dialog')), findsOneWidget);
    });
  });
}
