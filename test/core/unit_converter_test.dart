import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/core/utils/unit_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnitConverter & Density Matrix Tests', () {
    test('Volume to milliliters conversions', () {
      final oneCup = UnitConverter.toMilliliters(PreciseDecimal.fromInt(1), 'taza');
      expect(oneCup.toStringAsFixed(3), '236.588');

      final oneTbsp = UnitConverter.toMilliliters(PreciseDecimal.fromInt(1), 'cda');
      expect(oneTbsp.toStringAsFixed(3), '14.787');

      final oneTsp = UnitConverter.toMilliliters(PreciseDecimal.fromInt(1), 'cdta');
      expect(oneTsp.toStringAsFixed(3), '4.929');
    });

    test('Mass to grams conversions', () {
      final oneKg = UnitConverter.toGrams(PreciseDecimal.fromInt(1), 'kg');
      expect(oneKg.toStringAsFixed(0), '1000');

      final oneLb = UnitConverter.toGrams(PreciseDecimal.fromInt(1), 'lb');
      expect(oneLb.toStringAsFixed(2), '453.59');
    });

    test('Volume to mass with density for Flour', () {
      // 1 cup of flour ~ 120 g
      final cupVolume = UnitConverter.mlPerCup;
      final flourDensity = CulinaryDensityMatrix.getDensity('harina');
      final flourMass = UnitConverter.volumeToMass(cupVolume, flourDensity);
      expect(flourMass.toStringAsFixed(0), '120');
    });

    test('SRS CA-01: Verificación de Conversión y Prorrateo de Harina (5 lb saco a \$3.00)', () {
      // 5 lb = 5 * 453.59237 = 2267.96185 g
      final bagGrams = UnitConverter.toGrams(PreciseDecimal.fromInt(5), 'lb');
      final bagPrice = PreciseDecimal.fromString('3.00');

      // Cost per gram = bagPrice / bagGrams
      final costPerGram = bagPrice / bagGrams;

      // 200 g used in cake recipe
      final recipeFlourGrams = PreciseDecimal.fromString('200.00');
      final costUsed = recipeFlourGrams * costPerGram;

      // Expect $0.2645 -> $0.26 rounded to 2 decimal places
      expect(costUsed.toStringAsFixed(2), '0.26');
      expect(costUsed.toCurrencyString(), r'$0.26');
    });
  });
}
