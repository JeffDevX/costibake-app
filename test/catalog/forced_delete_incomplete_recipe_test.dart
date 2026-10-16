import 'package:costibake_app/core/constants/app_constants.dart';
import 'package:costibake_app/core/database/app_database.dart';
import 'package:costibake_app/core/errors/exceptions.dart';
import 'package:costibake_app/core/theme/app_theme.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/data/models/ingredient_model.dart';
import 'package:costibake_app/features/catalog/data/repositories/ingredient_repository_impl.dart';
import 'package:costibake_app/features/catalog/domain/entities/dependency_block_info.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:costibake_app/features/catalog/presentation/widgets/dependency_protection_dialog.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InMemoryIngredientRepo implements IngredientRepository {
  final List<Ingredient> items = [];
  final Map<String, List<String>> usageByIngredientId = {};
  final List<String> forceDeletedIds = [];

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
    if (force) {
      forceDeletedIds.add(id);
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
    items.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<String>> getRecipesUsingPackaging(String packagingId) async =>
      const [];
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group(
    'JEF-18: Forced Catalog Deletion & Incomplete Recipe Lifecycle (RF-SYS-23, RNF-08, BR-FRC-01..04)',
    () {
      test(
        'BR-FRC-02 & RNF-08: Force-deleting "Harina XXX" in SQLite removes it from active catalog, preserves historical line as "[ELIMINADO]" with 0 cost, and transitions dependent recipes to INCOMPLETA_REQUIERE_REVISION',
        () async {
          await AppDatabase.openInMemoryTestDatabase();

          final ingredientRepo = IngredientRepositoryImpl();
          final recipeRepo = RecipeRepositoryImpl();

          final now = DateTime(2026, 10, 16);
          final harinaXxx = IngredientModel(
            id: 'ing-harina-xxx',
            name: 'Harina XXX',
            category: 'Harinas',
            purchaseCost: PreciseDecimal.fromString('15.00'),
            purchaseQuantity: PreciseDecimal.fromInt(1000),
            purchaseUnit: 'g',
            minimumUnit: 'g',
            minimumUnitCost: PreciseDecimal.fromString('0.0150'),
            wastePercentage: PreciseDecimal.zero,
            updatedAt: now,
          );
          final azucar = IngredientModel(
            id: 'ing-azucar',
            name: 'Azúcar Blanca',
            category: 'Azúcares',
            purchaseCost: PreciseDecimal.fromString('10.00'),
            purchaseQuantity: PreciseDecimal.fromInt(1000),
            purchaseUnit: 'g',
            minimumUnit: 'g',
            minimumUnitCost: PreciseDecimal.fromString('0.0100'),
            wastePercentage: PreciseDecimal.zero,
            updatedAt: now,
          );
          await ingredientRepo.saveIngredient(harinaXxx);
          await ingredientRepo.saveIngredient(azucar);

          final pastel = RecipeModel(
            id: 'rec-pastel',
            name: 'Pastel de Chocolate',
            yieldPortions: 10,
            prepTimeMinutes: 30,
            bakeTimeMinutes: 35,
            targetProfitMargin: PreciseDecimal.fromInt(40),
            status: AppConstants.recipeStatusActive,
            createdAt: now,
            updatedAt: now,
            ingredients: [
              RecipeIngredientItem(
                id: 'ri-1',
                recipeId: 'rec-pastel',
                ingredientId: 'ing-harina-xxx',
                ingredientName: 'Harina XXX',
                quantity: PreciseDecimal.fromInt(500),
                unit: 'g',
                baseUnit: 'g',
                section: 'Base / Bizcocho',
                unitCost: PreciseDecimal.fromString('0.0150'),
              ),
              RecipeIngredientItem(
                id: 'ri-2',
                recipeId: 'rec-pastel',
                ingredientId: 'ing-azucar',
                ingredientName: 'Azúcar Blanca',
                quantity: PreciseDecimal.fromInt(200),
                unit: 'g',
                baseUnit: 'g',
                section: 'Base / Bizcocho',
                unitCost: PreciseDecimal.fromString('0.0100'),
              ),
            ],
          );

          final cupcakes = RecipeModel(
            id: 'rec-cupcakes',
            name: 'Cupcakes de Vainilla',
            yieldPortions: 12,
            prepTimeMinutes: 25,
            bakeTimeMinutes: 20,
            targetProfitMargin: PreciseDecimal.fromInt(45),
            status: AppConstants.recipeStatusActive,
            createdAt: now,
            updatedAt: now,
            ingredients: [
              RecipeIngredientItem(
                id: 'ri-3',
                recipeId: 'rec-cupcakes',
                ingredientId: 'ing-harina-xxx',
                ingredientName: 'Harina XXX',
                quantity: PreciseDecimal.fromInt(250),
                unit: 'g',
                baseUnit: 'g',
                section: 'Base / Bizcocho',
                unitCost: PreciseDecimal.fromString('0.0150'),
              ),
            ],
          );

          await recipeRepo.saveRecipe(pastel);
          await recipeRepo.saveRecipe(cupcakes);

          // Execute forced deletion (force: true)
          await ingredientRepo.deleteIngredient('ing-harina-xxx', force: true);

          // 1. Active catalog no longer contains "Harina XXX"
          final activeIngredients = await ingredientRepo.getAllIngredients();
          expect(activeIngredients.map((i) => i.id), ['ing-azucar']);
          expect(await ingredientRepo.getIngredientById('ing-harina-xxx'), isNull);

          // 2. Both dependent recipes transitioned to INCOMPLETA_REQUIERE_REVISION
          final updatedPastel = await recipeRepo.getRecipeById('rec-pastel');
          final updatedCupcakes = await recipeRepo.getRecipeById('rec-cupcakes');
          expect(updatedPastel, isNotNull);
          expect(
            updatedPastel!.status,
            AppConstants.recipeStatusIncomplete,
          );
          expect(
            updatedCupcakes!.status,
            AppConstants.recipeStatusIncomplete,
          );

          // 3. Historical ingredient line is preserved with "[ELIMINADO]" and 0 cost
          expect(updatedPastel.hasOrphanedItems, isTrue);
          final orphanItem = updatedPastel.orphanedIngredients.single;
          expect(orphanItem.ingredientName, contains('[ELIMINADO]'));
          expect(orphanItem.cleanHistoricalName, 'Harina XXX');
          expect(orphanItem.isDeleted, isTrue);
          expect(orphanItem.calculateItemCost(), PreciseDecimal.zero);

          // Only Azúcar Blanca (200g * $0.01 = $2.00) contributes to direct cost
          expect(
            updatedPastel.totalIngredientsCost,
            PreciseDecimal.fromString('2.00'),
          );
        },
      );

      testWidgets(
        'BR-FRC-01: Second-level confirmation modal requires typing "ELIMINAR" before enabling forced deletion on 360x640 screen',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 640));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final ingRepo = _InMemoryIngredientRepo();
          final packRepo = _InMemoryPackagingRepo();
          final now = DateTime(2026, 10, 16);

          ingRepo.items.add(
            Ingredient(
              id: 'ing-harina-xxx',
              name: 'Harina XXX',
              category: 'Harinas',
              purchaseCost: PreciseDecimal.fromInt(15),
              purchaseQuantity: PreciseDecimal.fromInt(1000),
              purchaseUnit: 'g',
              minimumUnit: 'g',
              minimumUnitCost: PreciseDecimal.fromString('0.015'),
              wastePercentage: PreciseDecimal.zero,
              updatedAt: now,
            ),
          );
          ingRepo.usageByIngredientId['ing-harina-xxx'] = [
            'Pastel de Chocolate',
            'Cupcakes de Vainilla',
          ];

          final catalogBloc = CatalogBloc(
            ingredientRepository: ingRepo,
            packagingRepository: packRepo,
          )..add(const LoadCatalog());

          const blockInfo = DependencyBlockInfo(
            itemId: 'ing-harina-xxx',
            itemName: 'Harina XXX',
            isPackaging: false,
            affectedRecipeNames: [
              'Pastel de Chocolate',
              'Cupcakes de Vainilla',
            ],
          );

          await tester.pumpWidget(
            BlocProvider<CatalogBloc>.value(
              value: catalogBloc,
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: ElevatedButton(
                        key: const Key('btn_open_protection_dialog'),
                        onPressed: () => DependencyProtectionDialog.show(
                          context,
                          blockInfo: blockInfo,
                        ),
                        child: const Text('Intentar Borrar'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Open first-level protective modal
          await tester.tap(find.byKey(const Key('btn_open_protection_dialog')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('dependency_protection_dialog')),
            findsOneWidget,
          );

          // Tap "Forzar Eliminación..." to open second-level modal
          await tester.tap(
            find.byKey(const Key('btn_open_force_delete_dialog')),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('forced_delete_confirmation_dialog')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('forced_delete_warning_text')),
            findsOneWidget,
          );

          // Confirm button is initially disabled until "ELIMINAR" is typed
          final confirmBtnFinder =
              find.byKey(const Key('btn_confirm_force_delete'));
          expect(
            tester.widget<ElevatedButton>(confirmBtnFinder).onPressed,
            isNull,
          );

          // Typing wrong word keeps button disabled
          await tester.enterText(
            find.byKey(const Key('input_confirm_force_delete')),
            'BORRAR',
          );
          await tester.pump();
          expect(
            tester.widget<ElevatedButton>(confirmBtnFinder).onPressed,
            isNull,
          );

          // Typing "ELIMINAR" enables the button
          await tester.enterText(
            find.byKey(const Key('input_confirm_force_delete')),
            'ELIMINAR',
          );
          await tester.pump();
          expect(
            tester.widget<ElevatedButton>(confirmBtnFinder).onPressed,
            isNotNull,
          );

          // Verify touch target >= 48px
          expect(
            tester.getSize(confirmBtnFinder).height,
            greaterThanOrEqualTo(48),
          );

          // Confirm forced deletion
          await tester.tap(confirmBtnFinder);
          await tester.pumpAndSettle();

          expect(ingRepo.forceDeletedIds, contains('ing-harina-xxx'));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'BR-FRC-03: RecipesScreen visually highlights incomplete recipes with warning icon, badge, and disabled suggested price notice',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 640));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final recipeRepo = _InMemoryRecipeRepo();
          final now = DateTime(2026, 10, 16);

          recipeRepo.items.add(
            Recipe(
              id: 'rec-incomplete-1',
              name: 'Pastel de Chocolate',
              yieldPortions: 10,
              prepTimeMinutes: 30,
              bakeTimeMinutes: 30,
              targetProfitMargin: PreciseDecimal.fromInt(40),
              status: AppConstants.recipeStatusIncomplete,
              createdAt: now,
              updatedAt: now,
              ingredients: [
                RecipeIngredientItem(
                  id: 'ri-orphan',
                  recipeId: 'rec-incomplete-1',
                  ingredientId: 'ing-harina-xxx',
                  ingredientName: 'Harina XXX [ELIMINADO]',
                  quantity: PreciseDecimal.fromInt(500),
                  unit: 'g',
                  section: 'Base / Bizcocho',
                  unitCost: PreciseDecimal.zero,
                  isDeleted: true,
                ),
              ],
            ),
          );

          final recipesBloc = RecipesBloc(recipeRepository: recipeRepo)
            ..add(const LoadRecipes());

          await tester.pumpWidget(
            MultiRepositoryProvider(
              providers: [
                RepositoryProvider<RecipeRepository>.value(value: recipeRepo),
              ],
              child: BlocProvider<RecipesBloc>.value(
                value: recipesBloc,
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: const RecipesScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('badge_incomplete_recipe_rec-incomplete-1')),
            findsOneWidget,
          );
          expect(
            find.byKey(
              const Key('incomplete_price_warning_rec-incomplete-1'),
            ),
            findsOneWidget,
          );
          expect(find.text('Precio sugerido deshabilitado'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'BR-FRC-03 & BR-FRC-04: Opening incomplete recipe shows warning banner and disabled pricing; assigning substitute ingredient restores ACTIVA status and recalculates costs',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 640));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final ingRepo = _InMemoryIngredientRepo();
          final packRepo = _InMemoryPackagingRepo();
          final recipeRepo = _InMemoryRecipeRepo();
          final now = DateTime(2026, 10, 16);

          // Active substitute ingredient in catalog
          final substituteHarina = Ingredient(
            id: 'ing-harina-sustituta',
            name: 'Harina Pastelera Premium',
            category: 'Harinas',
            purchaseCost: PreciseDecimal.fromInt(20),
            purchaseQuantity: PreciseDecimal.fromInt(1000),
            purchaseUnit: 'g',
            minimumUnit: 'g',
            minimumUnitCost: PreciseDecimal.fromString('0.0200'),
            wastePercentage: PreciseDecimal.zero,
            updatedAt: now,
          );
          ingRepo.items.add(substituteHarina);

          final incompleteRecipe = Recipe(
            id: 'rec-pastel',
            name: 'Pastel de Chocolate',
            yieldPortions: 10,
            prepTimeMinutes: 30,
            bakeTimeMinutes: 30,
            targetProfitMargin: PreciseDecimal.fromInt(40),
            status: AppConstants.recipeStatusIncomplete,
            createdAt: now,
            updatedAt: now,
            ingredients: [
              RecipeIngredientItem(
                id: 'ri-orphan-1',
                recipeId: 'rec-pastel',
                ingredientId: 'ing-harina-xxx',
                ingredientName: 'Harina XXX [ELIMINADO]',
                quantity: PreciseDecimal.fromInt(500),
                unit: 'g',
                section: 'Base / Bizcocho',
                unitCost: PreciseDecimal.zero,
                isDeleted: true,
              ),
            ],
          );
          recipeRepo.items.add(incompleteRecipe);

          final recipesBloc = RecipesBloc(recipeRepository: recipeRepo)
            ..add(const LoadRecipes());

          await tester.pumpWidget(
            MultiRepositoryProvider(
              providers: [
                RepositoryProvider<IngredientRepository>.value(value: ingRepo),
                RepositoryProvider<PackagingRepository>.value(value: packRepo),
                RepositoryProvider<RecipeRepository>.value(value: recipeRepo),
              ],
              child: BlocProvider<RecipesBloc>.value(
                value: recipesBloc,
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: RecipeFormScreen(recipeToEdit: incompleteRecipe),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Prominent warning banner is visible at top of RecipeFormScreen (BR-FRC-03)
          expect(
            find.byKey(const Key('incomplete_recipe_warning_banner')),
            findsOneWidget,
          );
          final bannerText = tester
              .widget<Text>(
                find.byKey(const Key('incomplete_recipe_warning_text')),
              )
              .data!;
          expect(
            bannerText,
            'Receta incompleta: 1 ingrediente ha sido eliminado del catálogo (Harina XXX). Asigne un sustituto para reactivar el costeo.',
          );

          // 2. Navigate to Costeo tab and verify DualPricingCard is disabled (BR-FRC-03)
          await tester.tap(find.text('Costeo'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('incomplete_pricing_disabled_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('recipe_form_dual_pricing_card')),
            findsNothing,
          );

          // 3. Navigate to Ingredientes tab and click "Asignar Sustituto" (BR-FRC-04)
          await tester.tap(find.text('Ingredientes'));
          await tester.pumpAndSettle();

          final replaceBtn = find.byKey(
            const Key('btn_replace_orphan_ingredient_ri-orphan-1'),
          );
          expect(replaceBtn, findsOneWidget);
          await tester.ensureVisible(replaceBtn);
          await tester.pumpAndSettle();
          await tester.tap(replaceBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('replace_orphan_ingredient_dialog')),
            findsOneWidget,
          );

          // Confirm substitute assignment
          await tester.tap(
            find.byKey(const Key('btn_confirm_replace_orphan_ingredient')),
          );
          await tester.pumpAndSettle();

          // 4. Warning banner disappears immediately, cost recalculates (500g * $0.02 = $10.00)
          expect(
            find.byKey(const Key('incomplete_recipe_warning_banner')),
            findsNothing,
          );
          expect(find.text('Harina Pastelera Premium'), findsOneWidget);
          expect(find.text('\$10.0000'), findsWidgets);

          // 5. Save the recipe and verify status transitioned back to ACTIVA in RecipesBloc
          await tester.tap(find.byKey(const Key('btn_save_recipe')));
          await tester.pumpAndSettle();

          final savedRecipe = recipeRepo.items.single;
          expect(savedRecipe.status, AppConstants.recipeStatusActive);
          expect(savedRecipe.hasOrphanedItems, isFalse);
          expect(
            savedRecipe.totalIngredientsCost,
            PreciseDecimal.fromString('10.00'),
          );
          final blocState = recipesBloc.state as RecipesLoaded;
          expect(
            blocState.recipes.single.status,
            AppConstants.recipeStatusActive,
          );
          expect(tester.takeException(), isNull);
        },
      );
    },
  );
}
