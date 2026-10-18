import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/recipes/domain/entities/ai_recipe_extraction.dart';
import 'package:costibake_app/features/recipes/presentation/widgets/missing_ingredients_wizard_dialog.dart';

class MockIngredientRepository implements IngredientRepository {
  final List<Ingredient> savedIngredients = [];

  @override
  Future<List<Ingredient>> getAllIngredients() async => savedIngredients;

  @override
  Future<Ingredient?> getIngredientById(String id) async =>
      savedIngredients.where((i) => i.id == id).firstOrNull;

  @override
  Future<List<Ingredient>> searchIngredients(String query, {String? category}) async =>
      savedIngredients;

  @override
  Future<void> saveIngredient(Ingredient ingredient) async {
    savedIngredients.add(ingredient);
  }

  @override
  Future<void> deleteIngredient(String id, {bool force = false}) async {}

  @override
  Future<List<String>> getRecipesUsingIngredient(String ingredientId) async => [];
}

void main() {
  group('MissingIngredientsWizardDialog Widget Tests', () {
    late MockIngredientRepository mockRepo;
    late List<Ingredient> existingCatalog;

    setUp(() {
      mockRepo = MockIngredientRepository();
      existingCatalog = [
        Ingredient(
          id: 'cat-ing-1',
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
          id: 'cat-ing-2',
          name: 'Azúcar Blanca Refinada',
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
    });

    Widget createTestWidget({
      required AiRecipeExtraction extraction,
      required Function(AiRecipeExtraction?) onResult,
    }) {
      return MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_wizard'),
                  onPressed: () async {
                    final res = await MissingIngredientsWizardDialog.show(
                      context: context,
                      extraction: extraction,
                      catalog: existingCatalog,
                      ingredientRepository: mockRepo,
                    );
                    onResult(res);
                  },
                  child: const Text('Abrir Wizard'),
                ),
              ),
            );
          },
        ),
      );
    }

    testWidgets('renders properly on compact 360x640 mobile without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final extraction = AiRecipeExtraction(
        title: 'Tarta de Frambuesas',
        ingredients: [
          AiExtractedIngredient(
            name: 'Frambuesas Frescas',
            quantity: PreciseDecimal.fromString('300'),
            unit: 'g',
            section: 'Decoración',
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          extraction: extraction,
          onResult: (_) {},
        ),
      );

      await tester.tap(find.byKey(const Key('open_wizard')));
      await tester.pumpAndSettle();

      expect(find.text('Conciliar Insumos Faltantes'), findsOneWidget);
      expect(find.text('Frambuesas Frescas'), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('btn_confirm_reconciliation')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bottom CTA is disabled when unresolved items remain', (tester) async {
      final extraction = AiRecipeExtraction(
        title: 'Tarta de Frambuesas',
        ingredients: [
          AiExtractedIngredient(
            name: 'Frambuesas Frescas',
            quantity: PreciseDecimal.fromString('300'),
            unit: 'g',
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          extraction: extraction,
          onResult: (_) {},
        ),
      );

      await tester.tap(find.byKey(const Key('open_wizard')));
      await tester.pumpAndSettle();

      final confirmBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('btn_confirm_reconciliation')),
      );
      expect(confirmBtn.onPressed, isNull);
      expect(find.text('Faltan 1 insumos'), findsOneWidget);
    });

    testWidgets('Alta Express registers ingredient in repository and enables completion', (tester) async {
      AiRecipeExtraction? returnedResult;

      final extraction = AiRecipeExtraction(
        title: 'Tarta de Frambuesas',
        ingredients: [
          AiExtractedIngredient(
            name: 'Frambuesas Frescas',
            quantity: PreciseDecimal.fromString('300'),
            unit: 'g',
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          extraction: extraction,
          onResult: (res) => returnedResult = res,
        ),
      );

      await tester.tap(find.byKey(const Key('open_wizard')));
      await tester.pumpAndSettle();

      // Enter price of purchase in Alta Express Form
      final priceField = find.widgetWithText(TextFormField, 'Precio de Compra (\$) *');
      await tester.enterText(priceField, '4.50');
      await tester.pumpAndSettle();

      // Tap Guardar en Catálogo y Vincular
      final saveBtn = find.byKey(const Key('btn_save_express_ingredient'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify ingredient was saved in repo
      expect(mockRepo.savedIngredients.length, equals(1));
      expect(mockRepo.savedIngredients.first.name, equals('Frambuesas Frescas'));
      expect(mockRepo.savedIngredients.first.purchaseCost, equals(PreciseDecimal.fromString('4.50')));

      // Now all items are resolved
      expect(find.text('¡Todos los insumos están conciliados!'), findsOneWidget);

      // Tap Continuar a Previsualización
      await tester.tap(find.byKey(const Key('btn_confirm_reconciliation_center')));
      await tester.pumpAndSettle();

      expect(returnedResult, isNotNull);
      expect(returnedResult!.isFullyResolved, isTrue);
      expect(returnedResult!.ingredients.first.matchedCatalogIngredientId, isNotNull);
      expect(returnedResult!.ingredients.first.isNewIngredient, isTrue);
    });

    testWidgets('Vincular tab links to an existing catalog ingredient', (tester) async {
      AiRecipeExtraction? returnedResult;

      final extraction = AiRecipeExtraction(
        title: 'Bizcocho Dulce',
        ingredients: [
          AiExtractedIngredient(
            name: 'Azúcar Blanca',
            quantity: PreciseDecimal.fromString('200'),
            unit: 'g',
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          extraction: extraction,
          onResult: (res) => returnedResult = res,
        ),
      );

      await tester.tap(find.byKey(const Key('open_wizard')));
      await tester.pumpAndSettle();

      // Switch to Vincular tab
      await tester.tap(find.text('Vincular Existente'));
      await tester.pumpAndSettle();

      // Select 'Azúcar Blanca Refinada' from suggestions or list
      final sugarItem = find.text('Azúcar Blanca Refinada').first;
      await tester.tap(sugarItem);
      await tester.pumpAndSettle();

      // Tap Vincular a este Insumo
      final linkBtn = find.byKey(const Key('btn_link_existing_ingredient'));
      await tester.ensureVisible(linkBtn);
      await tester.tap(linkBtn);
      await tester.pumpAndSettle();

      // Verify all items are resolved
      expect(find.text('¡Todos los insumos están conciliados!'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_confirm_reconciliation_center')));
      await tester.pumpAndSettle();

      expect(returnedResult, isNotNull);
      expect(returnedResult!.isFullyResolved, isTrue);
      expect(returnedResult!.ingredients.first.matchedCatalogIngredientId, equals('cat-ing-2'));
      expect(returnedResult!.ingredients.first.isNewIngredient, isFalse);
    });
  });
}
