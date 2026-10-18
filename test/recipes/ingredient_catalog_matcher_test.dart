import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/recipes/domain/entities/ai_recipe_extraction.dart';
import 'package:costibake_app/features/recipes/domain/services/ingredient_catalog_matcher.dart';

void main() {
  group('IngredientCatalogMatcher Unit Tests', () {
    final catalog = [
      Ingredient(
        id: 'ing-1',
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
        id: 'ing-2',
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
      Ingredient(
        id: 'ing-3',
        name: 'Mantequilla Sin Sal',
        category: 'Grasas y Mantequillas',
        purchaseCost: PreciseDecimal.fromString('3.00'),
        purchaseQuantity: PreciseDecimal.fromString('250'),
        purchaseUnit: 'g',
        wastePercentage: PreciseDecimal.zero,
        minimumUnitCost: PreciseDecimal.fromString('0.012'),
        minimumUnit: 'g',
        updatedAt: DateTime.now(),
      ),
      Ingredient(
        id: 'ing-4',
        name: 'Huevos',
        category: 'Lácteos y Huevos',
        purchaseCost: PreciseDecimal.fromString('4.00'),
        purchaseQuantity: PreciseDecimal.fromString('12'),
        purchaseUnit: 'unidad',
        wastePercentage: PreciseDecimal.zero,
        minimumUnitCost: PreciseDecimal.fromString('0.333333'),
        minimumUnit: 'unidad',
        updatedAt: DateTime.now(),
      ),
    ];

    test('normalizes strings removing accents, symbols and casing', () {
      expect(
        IngredientCatalogMatcher.normalize('  ¡Azúcar Refinada #1!  '),
        equals('azucar refinada 1'),
      );
      expect(
        IngredientCatalogMatcher.normalize('Chantilly & Dulce de Leche'),
        equals('chantilly dulce de leche'),
      );
    });

    test('finds exact match ignoring case and accents', () {
      final result = IngredientCatalogMatcher.match(
        extractedName: 'azucar refinada',
        catalog: catalog,
      );

      expect(result.hasExactMatch, isTrue);
      expect(result.exactMatch?.id, equals('ing-2'));
      expect(result.exactMatch?.name, equals('Azúcar Refinada'));
    });

    test('suggests relevant candidates for partial match', () {
      final result = IngredientCatalogMatcher.match(
        extractedName: 'Mantequilla con sal',
        catalog: catalog,
      );

      expect(result.hasExactMatch, isFalse);
      expect(result.suggestions.isNotEmpty, isTrue);
      expect(result.suggestions.first.ingredient.id, equals('ing-3'));
      expect(result.suggestions.first.score, greaterThan(0.5));
    });

    test('matches substring properly (e.g. Harina in Harina de Trigo Todo Uso)', () {
      final result = IngredientCatalogMatcher.match(
        extractedName: 'Harina de trigo',
        catalog: catalog,
      );

      expect(result.suggestions.isNotEmpty, isTrue);
      expect(result.suggestions.first.ingredient.id, equals('ing-1'));
    });

    test('matchExtraction auto-links exact matches and flags missing ingredients', () {
      final initialExtraction = AiRecipeExtraction(
        title: 'Bizcochuelo Clásico',
        ingredients: [
          AiExtractedIngredient(
            name: 'Harina de Trigo Todo Uso',
            quantity: PreciseDecimal.one,
            unit: 'g',
          ),
          AiExtractedIngredient(
            name: 'Azúcar Refinada',
            quantity: PreciseDecimal.one,
            unit: 'g',
          ),
          AiExtractedIngredient(
            name: 'Extracto de Almendras Raro',
            quantity: PreciseDecimal.one,
            unit: 'ml',
          ),
        ],
      );

      final reconciled = IngredientCatalogMatcher.matchExtraction(
        extraction: initialExtraction,
        catalog: catalog,
      );

      expect(reconciled.ingredients[0].matchedCatalogIngredientId, equals('ing-1'));
      expect(reconciled.ingredients[0].matchedCatalogIngredientName, equals('Harina de Trigo Todo Uso'));
      expect(reconciled.ingredients[0].isResolved, isTrue);

      expect(reconciled.ingredients[1].matchedCatalogIngredientId, equals('ing-2'));
      expect(reconciled.ingredients[1].isResolved, isTrue);

      // Third ingredient does not exist in catalog
      expect(reconciled.ingredients[2].matchedCatalogIngredientId, isNull);
      expect(reconciled.ingredients[2].isResolved, isFalse);

      expect(reconciled.unresolvedIngredientsCount, equals(1));
      expect(reconciled.isFullyResolved, isFalse);
    });
  });
}
