import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/data/models/ingredient_model.dart';
import 'package:costibake_app/features/catalog/data/models/packaging_model.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/settings/data/models/business_config_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Models Serialization and Entity Calculations Tests', () {
    test('Ingredient Minimum Unit Cost Calculation with 5% waste', () {
      // Purchase: 1 kg flour for $2.00, 5% waste
      // Base quantity = 1000 g
      // Usable quantity = 1000 * (1 - 0.05) = 950 g
      // Cost per usable gram = 2.00 / 950 = $0.002105
      final purchaseCost = PreciseDecimal.fromString('2.00');
      final purchaseQty = PreciseDecimal.fromString('1.00');
      final waste = PreciseDecimal.fromString('5.00');

      final minCost = Ingredient.calculateMinimumUnitCost(
        purchaseCost: purchaseCost,
        purchaseQuantity: purchaseQty,
        purchaseUnit: 'kg',
        wastePercentage: waste,
      );

      expect(minCost.toStringAsFixed(6), '0.002105');
    });

    test('Packaging Unit Cost Calculation', () {
      // Package of 50 cake boxes for $35.00
      // Unit cost = 35 / 50 = $0.70
      final unitCost = Packaging.calculateUnitCost(
        packageCost: PreciseDecimal.fromString('35.00'),
        unitsPerPackage: 50,
      );

      expect(unitCost.toStringAsFixed(2), '0.70');
      expect(unitCost.toCurrencyString(), r'$0.70');
    });

    test('IngredientModel Map serialization roundtrip', () {
      final now = DateTime.now();
      final model = IngredientModel(
        id: 'ing-1',
        name: 'Mantequilla sin sal',
        category: 'Lácteos',
        purchaseCost: PreciseDecimal.fromString('8.50'),
        purchaseQuantity: PreciseDecimal.fromString('1.00'),
        purchaseUnit: 'kg',
        wastePercentage: PreciseDecimal.zero,
        minimumUnitCost: PreciseDecimal.fromString('0.008500'),
        minimumUnit: 'g',
        densityGPerMl: PreciseDecimal.fromString('0.9595'),
        notes: 'Marca premium repostera',
        updatedAt: now,
      );

      final map = model.toMap();
      final reconstituted = IngredientModel.fromMap(map);

      expect(reconstituted.id, model.id);
      expect(reconstituted.name, model.name);
      expect(reconstituted.category, model.category);
      expect(reconstituted.purchaseCost.toStringAsFixed(2), '8.50');
      expect(reconstituted.minimumUnitCost.toStringAsFixed(6), '0.008500');
      expect(reconstituted.densityGPerMl?.toStringAsFixed(4), '0.9595');
    });

    test('PackagingModel Map serialization roundtrip', () {
      final now = DateTime.now();
      final model = PackagingModel(
        id: 'pack-1',
        name: 'Domo Alto 24cm',
        category: 'Domos',
        packageCost: PreciseDecimal.fromString('25.00'),
        unitsPerPackage: 20,
        unitCost: PreciseDecimal.fromString('1.2500'),
        notes: 'Para pasteles de 2 pisos',
        updatedAt: now,
      );

      final map = model.toMap();
      final reconstituted = PackagingModel.fromMap(map);

      expect(reconstituted.id, model.id);
      expect(reconstituted.name, model.name);
      expect(reconstituted.unitsPerPackage, 20);
      expect(reconstituted.unitCost.toStringAsFixed(2), '1.25');
    });

    test('BusinessConfigModel Map serialization roundtrip', () {
      final now = DateTime.now();
      final model = BusinessConfigModel(
        id: 'cfg-test',
        businessName: 'Pastelería La Delicia',
        currencySymbol: r'$',
        laborHourlyRate: PreciseDecimal.fromString('15.50'),
        overheadPercentage: PreciseDecimal.fromString('18.00'),
        updatedAt: now,
      );

      final map = model.toMap();
      final reconstituted = BusinessConfigModel.fromMap(map);

      expect(reconstituted.businessName, 'Pastelería La Delicia');
      expect(reconstituted.currencySymbol, r'$');
      expect(reconstituted.laborHourlyRate.toStringAsFixed(2), '15.50');
      expect(reconstituted.overheadPercentage.toStringAsFixed(2), '18.00');
    });
  });
}
