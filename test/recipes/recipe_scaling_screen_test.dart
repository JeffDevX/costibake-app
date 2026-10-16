import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:costibake_app/core/constants/app_constants.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/costing/domain/entities/pricing_strategy.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe_item.dart';
import 'package:costibake_app/features/recipes/presentation/screens/recipe_scaling_screen.dart';

void main() {
  Recipe createSampleBaseRecipe() {
    return Recipe(
      id: 'rec-base-6in',
      name: 'Torta de Chocolate',
      description: 'Receta base 6 pulgadas',
      yieldPortions: 8,
      prepTimeMinutes: 60,
      bakeTimeMinutes: 45,
      moldType: 'Redondo',
      moldDimension: '6" (15 cm)',
      targetProfitMargin: PreciseDecimal.fromInt(50),
      pricingMode: PricingMode.markupOnCost,
      roundingRule: RoundingRule.none,
      status: AppConstants.recipeStatusActive,
      createdAt: DateTime(2026, 10, 16),
      updatedAt: DateTime(2026, 10, 16),
      ingredients: [
        RecipeIngredientItem(
          id: 'item-flour',
          recipeId: 'rec-base-6in',
          ingredientId: 'ing-flour',
          ingredientName: 'Harina Pastelera',
          quantity: PreciseDecimal.fromInt(180),
          unit: 'g',
          baseUnit: 'g',
          section: 'Base / Bizcocho',
          unitCost: PreciseDecimal.fromString('0.005'),
        ),
        RecipeIngredientItem(
          id: 'item-eggs',
          recipeId: 'rec-base-6in',
          ingredientId: 'ing-eggs',
          ingredientName: 'Huevos Frescos',
          quantity: PreciseDecimal.fromInt(1),
          unit: 'u',
          baseUnit: 'unidad',
          section: 'Base / Bizcocho',
          unitCost: PreciseDecimal.fromString('0.36'),
        ),
      ],
    );
  }

  Widget buildTestApp(
    Recipe recipe, {
    Size screenSize = const Size(360, 640),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: RecipeScalingScreen(recipe: recipe),
      ),
    );
  }

  group('RecipeScalingScreen Widget Tests (JEF-14)', () {
    testWidgets(
      'Renders without overflow on compact 360x640 mobile screen and calculates 6" -> 10" (2.7778x)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final recipe = createSampleBaseRecipe();
        await tester.pumpWidget(buildTestApp(recipe));
        await tester.pumpAndSettle();

        // Verify exact 6" -> 10" geometric factor is displayed
        expect(find.byKey(const Key('text_exact_scale_factor')), findsOneWidget);
        expect(find.text('2.7778x (2.78×)'), findsOneWidget);

        // Verify scaled flour (180g * 2.7778 = 500.00g) and indivisible egg badge
        expect(
          find.text('Base: 180.00 g → Escalado: 500.00 g'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('indivisible_badge_item-eggs')),
          findsOneWidget,
        );
        expect(
          find.textContaining('3 u ó 138.9 g de huevo batido'),
          findsOneWidget,
        );

        // Verify zero RenderFlex overflow
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Switches between Rectangular Mold, Direct Multiplier, and Target Portions modes reactively',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final recipe = createSampleBaseRecipe();
        await tester.pumpWidget(buildTestApp(recipe, screenSize: const Size(400, 800)));
        await tester.pumpAndSettle();

        // 1. Switch to Rectangular Mold mode (20x20 -> 20x30 = 1.5000x)
        await tester.tap(
          find.byKey(const Key('scaling_mode_chip_rectangularMold')),
        );
        await tester.pumpAndSettle();
        expect(find.text('1.5000x (1.50×)'), findsOneWidget);

        // 2. Switch to Direct Multiplier mode and tap 3x chip
        await tester.tap(
          find.byKey(const Key('scaling_mode_chip_directMultiplier')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('multiplier_chip_3')));
        await tester.pumpAndSettle();
        expect(find.text('3.0000x (3.00×)'), findsOneWidget);
        expect(
          find.text('Base: 180.00 g → Escalado: 540.00 g'),
          findsOneWidget,
        );

        // 3. Switch to Target Portions mode and tap 16 portions (16 / 8 = 2.0000x)
        await tester.tap(
          find.byKey(const Key('scaling_mode_chip_targetPortions')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('portions_chip_16')));
        await tester.pumpAndSettle();
        expect(find.text('2.0000x (2.00×)'), findsOneWidget);
      },
    );

    testWidgets(
      'Saves scaled recipe as a new variant recipe with pre-filled name',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final recipe = createSampleBaseRecipe();
        Recipe? savedVariant;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('btn_launch_scaling'),
                      onPressed: () async {
                        final res = await Navigator.push<Recipe>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeScalingScreen(recipe: recipe),
                          ),
                        );
                        savedVariant = res;
                      },
                      child: const Text('Open'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_launch_scaling')));
        await tester.pumpAndSettle();

        // Tap "Guardar Variante"
        await tester.tap(find.byKey(const Key('btn_save_as_variant')));
        await tester.pumpAndSettle();

        // Dialog should open with suggested name "Torta de Chocolate (10" (25 cm))"
        expect(find.byKey(const Key('field_variant_recipe_name')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('field_variant_recipe_name')),
          'Torta de Chocolate 10 pulgadas',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_confirm_save_variant')));
        await tester.pumpAndSettle();

        expect(savedVariant, isNotNull);
        expect(savedVariant!.name, equals('Torta de Chocolate 10 pulgadas'));
        expect(savedVariant!.moldDimension, equals('10" (25 cm)'));
        expect(
          savedVariant!.ingredients.first.quantity.toStringAsFixed(2),
          equals('500.00'),
        );
      },
    );
  });
}
