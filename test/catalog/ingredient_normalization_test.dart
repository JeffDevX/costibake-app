import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/core/utils/unit_converter.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JEF-7: Normalización Automática de Insumos a Granel', () {
    test('Criterio Aceptación 1: Bulto de harina de 50 kg a \$45.00 -> \$0.0009 / g', () {
      final purchaseCost = PreciseDecimal.fromString('45.00');
      final purchaseQty = PreciseDecimal.fromString('50.00');
      const purchaseUnit = 'kg';
      final waste = PreciseDecimal.zero;

      final minUnit = Ingredient.determineMinimumUnit(purchaseUnit);
      final minCost = Ingredient.calculateMinimumUnitCost(
        purchaseCost: purchaseCost,
        purchaseQuantity: purchaseQty,
        purchaseUnit: purchaseUnit,
        wastePercentage: waste,
      );

      expect(minUnit, equals('g'));
      expect(minCost.toStringAsFixed(4), equals('0.0009'));
      expect(minCost.toStringAsFixed(6), equals('0.000900'));
    });

    test('Criterio Aceptación 2: Cubeta de 30 huevos a \$6.00 -> \$0.20 / unidad', () {
      final purchaseCost = PreciseDecimal.fromString('6.00');
      final purchaseQty = PreciseDecimal.fromString('30.00');
      const purchaseUnit = 'unidad';
      final waste = PreciseDecimal.zero;

      final minUnit = Ingredient.determineMinimumUnit(purchaseUnit);
      final minCost = Ingredient.calculateMinimumUnitCost(
        purchaseCost: purchaseCost,
        purchaseQuantity: purchaseQty,
        purchaseUnit: purchaseUnit,
        wastePercentage: waste,
      );

      expect(minUnit, equals('unidad'));
      expect(minCost.toStringAsFixed(2), equals('0.20'));
      expect(minCost.toCurrencyString(), equals(r'$0.20'));
    });

    test('Criterio Aceptación 3: 1 litro de leche a \$1.50 -> \$0.0015 / ml', () {
      final purchaseCost = PreciseDecimal.fromString('1.50');
      final purchaseQty = PreciseDecimal.fromString('1.00');
      const purchaseUnit = 'l';
      final waste = PreciseDecimal.zero;

      final minUnit = Ingredient.determineMinimumUnit(purchaseUnit);
      final minCost = Ingredient.calculateMinimumUnitCost(
        purchaseCost: purchaseCost,
        purchaseQuantity: purchaseQty,
        purchaseUnit: purchaseUnit,
        wastePercentage: waste,
      );

      expect(minUnit, equals('ml'));
      expect(minCost.toStringAsFixed(4), equals('0.0015'));
      expect(minCost.toStringAsFixed(6), equals('0.001500'));
    });

    test('BR-INS-03: 1 Galón de leche a \$12.00 (3785.41 ml)', () {
      final purchaseCost = PreciseDecimal.fromString('12.00');
      final purchaseQty = PreciseDecimal.fromString('1.00');
      const purchaseUnit = 'gal';
      final waste = PreciseDecimal.zero;

      final minUnit = Ingredient.determineMinimumUnit(purchaseUnit);
      final minCost = Ingredient.calculateMinimumUnitCost(
        purchaseCost: purchaseCost,
        purchaseQuantity: purchaseQty,
        purchaseUnit: purchaseUnit,
        wastePercentage: waste,
      );

      expect(minUnit, equals('ml'));
      // 12.00 / 3785.41 = 0.003170
      expect(minCost.toStringAsFixed(6), equals('0.003170'));
    });

    test('BR-INS-03: 1 Libra de mantequilla a \$4.50 (453.59237 g)', () {
      final purchaseCost = PreciseDecimal.fromString('4.50');
      final purchaseQty = PreciseDecimal.fromString('1.00');
      const purchaseUnit = 'lb';
      final waste = PreciseDecimal.zero;

      final minUnit = Ingredient.determineMinimumUnit(purchaseUnit);
      final minCost = Ingredient.calculateMinimumUnitCost(
        purchaseCost: purchaseCost,
        purchaseQuantity: purchaseQty,
        purchaseUnit: purchaseUnit,
        wastePercentage: waste,
      );

      expect(minUnit, equals('g'));
      // 4.50 / 453.59237 = 0.009921
      expect(minCost.toStringAsFixed(6), equals('0.009921'));
    });

    test('BR-INS-03: 1 Docena de huevos a \$3.60 (12 unidades)', () {
      final purchaseCost = PreciseDecimal.fromString('3.60');
      final purchaseQty = PreciseDecimal.fromString('1.00');
      const purchaseUnit = 'docena';
      final waste = PreciseDecimal.zero;

      final minUnit = Ingredient.determineMinimumUnit(purchaseUnit);
      final minCost = Ingredient.calculateMinimumUnitCost(
        purchaseCost: purchaseCost,
        purchaseQuantity: purchaseQty,
        purchaseUnit: purchaseUnit,
        wastePercentage: waste,
      );

      expect(minUnit, equals('unidad'));
      // 3.60 / 12 = 0.30
      expect(minCost.toStringAsFixed(2), equals('0.30'));
    });

    test('Cálculo de merma (5% en 1 kg a \$2.00)', () {
      final purchaseCost = PreciseDecimal.fromString('2.00');
      final purchaseQty = PreciseDecimal.fromString('1.00');
      const purchaseUnit = 'kg';
      final waste = PreciseDecimal.fromString('5.00');

      final minCost = Ingredient.calculateMinimumUnitCost(
        purchaseCost: purchaseCost,
        purchaseQuantity: purchaseQty,
        purchaseUnit: purchaseUnit,
        wastePercentage: waste,
      );

      // Usable: 1000g * 0.95 = 950g. Cost: 2.00 / 950 = 0.002105
      expect(minCost.toStringAsFixed(6), equals('0.002105'));
    });
  });
}
