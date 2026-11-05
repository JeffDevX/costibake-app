import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/features/home/presentation/screens/home_screen.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:costibake_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_event.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_event.dart';
import 'package:costibake_app/features/settings/domain/entities/business_config.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:costibake_app/core/theme/app_theme.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/quotes/domain/entities/quote.dart';
import 'package:costibake_app/features/quotes/domain/repositories/quote_repository.dart';
import 'package:costibake_app/features/quotes/presentation/bloc/quotes_bloc.dart';
import 'package:costibake_app/features/quotes/presentation/bloc/quotes_event.dart';

class _FakeSettingsRepo implements SettingsRepository {
  @override
  Future<BusinessConfig> getBusinessConfig() async => BusinessConfig(
        id: 'cfg-test',
        businessName: 'CostiBake Test',
        currencySymbol: '\$',
        laborHourlyRate: PreciseDecimal.fromString('15.00'),
        overheadPercentage: PreciseDecimal.fromString('18.0'),
        updatedAt: DateTime(2026, 1, 1),
      );

  @override
  Future<void> saveBusinessConfig(BusinessConfig config) async {}
}

class _FakeIngredientRepo implements IngredientRepository {
  @override
  Future<List<Ingredient>> getAllIngredients() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePackagingRepo implements PackagingRepository {
  @override
  Future<List<Packaging>> getAllPackaging() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRecipeRepo implements RecipeRepository {
  @override
  Future<List<Recipe>> getAllRecipes() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQuoteRepo implements QuoteRepository {
  @override
  Future<List<Quote>> getAllQuotes() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget buildApp({ThemeMode themeMode = ThemeMode.light}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsBloc>(
          create: (_) => SettingsBloc(settingsRepository: _FakeSettingsRepo())
            ..add(const LoadSettings()),
        ),
        BlocProvider<CatalogBloc>(
          create: (_) => CatalogBloc(
            ingredientRepository: _FakeIngredientRepo(),
            packagingRepository: _FakePackagingRepo(),
          )..add(const LoadCatalog()),
        ),
        BlocProvider<RecipesBloc>(
          create: (_) => RecipesBloc(
            recipeRepository: _FakeRecipeRepo(),
          )..add(const LoadRecipes()),
        ),
        BlocProvider<QuotesBloc>(
          create: (_) => QuotesBloc(
            quoteRepository: _FakeQuoteRepo(),
          )..add(const LoadQuotes()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.vainillaTheme,
        darkTheme: AppTheme.cacaoTheme,
        themeMode: themeMode,
        builder: (context, child) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child,
          );
        },
        home: const HomeScreen(),
      ),
    );
  }

  group('HomeScreen & Global Keyboard UX Navigation (JEF-27)', () {
    testWidgets('Tapping outside an active input unfocuses via global GestureDetector',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Navigate to Settings tab
      final settingsTab = find.byIcon(Icons.settings_outlined);
      await tester.tap(settingsTab);
      await tester.pumpAndSettle();

      // Focus the business name field
      final nameField = find.byKey(const Key('business_name_field'));
      expect(nameField, findsOneWidget);
      await tester.tap(nameField);
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(of: nameField, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);

      // Tap on empty space outside the field (e.g. AppBar title)
      await tester.tap(find.text('Configuración del Taller'));
      await tester.pump();

      expect(editable.focusNode.hasFocus, isFalse);
    });

    testWidgets('Switching tabs in BottomNavigationBar unfocuses keyboard', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Go to Settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Focus field
      final nameField = find.byKey(const Key('business_name_field'));
      await tester.tap(nameField);
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(of: nameField, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);

      // Tap Catálogo tab
      await tester.tap(find.byIcon(Icons.inventory_2_outlined));
      await tester.pumpAndSettle();

      expect(editable.focusNode.hasFocus, isFalse);
    });

    testWidgets('Back button in SettingsScreen navigates to tab 0 (Catálogo)',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Go to Settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Verify back button is visible
      final backBtn = find.byKey(const Key('btn_settings_back'));
      expect(backBtn, findsOneWidget);

      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Should be back at Catálogo
      expect(find.text('Catálogo de Recursos'), findsOneWidget);
    });

    testWidgets('PopScope navigates from secondary tab to tab 0 on back press',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Go to Settings tab (index 3)
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Trigger pop through PopScope
      final popScopeFinder = find.byKey(const Key('home_pop_scope'));
      expect(popScopeFinder, findsOneWidget);

      final popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse);

      // Invoke pop callback
      popScope.onPopInvokedWithResult!(false, null);
      await tester.pumpAndSettle();

      // Should return to Catálogo
      expect(find.text('Catálogo de Recursos'), findsOneWidget);
    });

    testWidgets('Tapping search bar in CatalogScreen with keyboard opening does not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping search bar in RecipesScreen with keyboard opening does not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Go to Recetas tab
      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping search bar in QuotesScreen with keyboard opening does not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Go to Cotizar tab
      await tester.tap(find.byIcon(Icons.request_quote_outlined));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
    testWidgets('Searching without results in CatalogScreen with keyboard open does not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await tester.enterText(searchField, 'InsumoInexistente');
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Searching without results in RecipesScreen with keyboard open does not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await tester.enterText(searchField, 'RecetaInexistente');
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Opening forms from tabs does not throw multiple heroes error', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Tap FAB on catalog screen to open ingredient form
      final addBtn = find.byType(FloatingActionButton);
      expect(addBtn, findsWidgets);
      await tester.tap(addBtn.first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(AppBar, 'Registrar Insumo a Granel'), findsOneWidget);

      // Pop back
      final backBtn = find.byType(BackButton);
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn.first);
        await tester.pumpAndSettle();
      }

      // Switch to Recipes tab
      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();

      // Tap Add Recipe button
      final addRecipeFab = find.byKey(const Key('btn_add_recipe'));
      expect(addRecipeFab, findsOneWidget);
      await tester.tap(addRecipeFab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Formular Nueva Receta'), findsOneWidget);
    });

    testWidgets('Search bars and RecipeFormScreen bottom bar respect Modo Cacao theme', (tester) async {
      await tester.pumpWidget(buildApp(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      // Check search TextField hint style in Catalog tab in dark mode
      final textFieldFinder = find.byType(TextField).first;
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.decoration?.hintStyle?.color, equals(const Color(0xFFD4C3B3)));
      expect(textField.decoration?.fillColor, equals(const Color(0xFF241E1C)));

      // Navigate to Recipes tab
      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();

      // Tap Add Recipe button
      final addRecipeFab = find.byKey(const Key('btn_add_recipe'));
      await tester.tap(addRecipeFab);
      await tester.pumpAndSettle();

      expect(find.text('Formular Nueva Receta'), findsOneWidget);

      // Verify bottom bar Container has cacao surfaceCard color
      final bottomBarFinder = find.byKey(const Key('recipe_form_bottom_bar'));
      expect(bottomBarFinder, findsOneWidget);
      final bottomBarContainer = tester.widget<Container>(bottomBarFinder);
      final decoration = bottomBarContainer.decoration as BoxDecoration?;
      expect(decoration?.color, equals(const Color(0xFF241E1C)));
    });
  });
}
