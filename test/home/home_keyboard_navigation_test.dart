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

import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';

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

void main() {
  Widget buildApp() {
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
      ],
      child: MaterialApp(
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
  });
}
