import 'package:costibake_app/core/constants/culinary_units.dart';
import 'package:costibake_app/core/errors/exceptions.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/core/utils/unit_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JEF-11: Motor de Conversión Culinaria Bidireccional de Unidades', () {
    group('Criterios de Aceptación Verificables (SRS)', () {
      test('CA-1 & BR-CNV-02: Conversión de 2.5 tazas a ml resulta en 600.00 ml', () {
        // 2.5 * 240.0 ml = 600.0 ml
        final result = UnitConverter.convertUnit(2.5, 'tazas', 'ml');
        expect(result.toStringAsFixed(2), '600.00');
        expect(result.toDouble(), 600.0);
      });

      test('CA-2 & BR-CNV-02: Conversión de 3 cucharadas a cucharaditas resulta en 9 cucharaditas', () {
        // 1 tbsp = 15 ml, 1 tsp = 5 ml -> 3 tbsp = 45 ml / 5 = 9 tsp
        final result = UnitConverter.convertUnit(3, 'cucharadas', 'cucharaditas');
        expect(result.toStringAsFixed(0), '9');
        expect(result.toDouble(), 9.0);
      });

      test('CA-3 & BR-CNV-01: Conversión de 1.5 libras de azúcar a gramos resulta en 680.39 g', () {
        // 1.5 * 453.59237 = 680.388555 g -> rounded to 2 decimals = 680.39
        final result = UnitConverter.convertUnit(1.5, 'libras', 'gramos');
        expect(result.toStringAsFixed(2), '680.39');
      });

      test('CA-4 & BR-CNV-03: Conversión de tazas a gramos sin densidad arroja CrossDimensionConversionException', () {
        expect(
          () => UnitConverter.convertUnit(1.0, 'taza', 'gramo'),
          throwsA(isA<CrossDimensionConversionException>()),
        );

        expect(
          () => UnitConverter.convertUnit(2.0, CulinaryUnit.cup, CulinaryUnit.gram),
          throwsA(isA<CrossDimensionConversionException>()),
        );
      });

      test('CA-5: Precisión matemática estricta sin margen de redondeo prematuro (RNF-02)', () {
        // 1 libra a gramos y de regreso a libras con tolerancia < 0.0001
        final grams = UnitConverter.convertUnit(1.0, CulinaryUnit.pound, CulinaryUnit.gram);
        final backToPounds = UnitConverter.convertUnit(grams, CulinaryUnit.gram, CulinaryUnit.pound);

        final diff = (backToPounds.toDouble() - 1.0).abs();
        expect(diff < 0.0001, isTrue);

        // 1000 g round-trip con error relativo menor a 0.0001%
        final pounds = UnitConverter.convertUnit(1000, CulinaryUnit.gram, CulinaryUnit.pound);
        final backToGrams = UnitConverter.convertUnit(pounds, CulinaryUnit.pound, CulinaryUnit.gram);
        final relativeError = (backToGrams.toDouble() - 1000.0).abs() / 1000.0;
        expect(relativeError < 0.0001, isTrue);
      });

    });

    group('BR-CNV-01: Conversiones Intra-Peso (Masa a Masa)', () {
      test('1 kilogramo = 1,000 gramos exactos', () {
        final g = UnitConverter.convertUnit(1, 'kg', 'g');
        expect(g.toStringAsFixed(0), '1000');

        final kg = UnitConverter.convertUnit(2500, 'g', 'kg');
        expect(kg.toStringAsFixed(2), '2.50');
      });

      test('1 libra = 453.59237 gramos', () {
        final g = UnitConverter.convertUnit(1, 'lb', 'g');
        expect(g.toStringAsFixed(5), '453.59237');

        final lb = UnitConverter.convertUnit(907.18474, 'g', 'lb');
        expect(lb.toStringAsFixed(2), '2.00');
      });

      test('1 onza = 28.349523125 gramos', () {
        final g = UnitConverter.convertUnit(1, 'oz', 'g');
        expect(g.toStringAsFixed(4), '28.3495');

        // 16 onzas = 1 libra
        final ozInPound = UnitConverter.convertUnit(1, 'lb', 'oz');
        expect(ozInPound.toStringAsFixed(2), '16.00');
      });
    });

    group('BR-CNV-02: Conversiones Intra-Volumen (Volumen a Volumen)', () {
      test('1 litro = 1,000 ml exactos', () {
        final ml = UnitConverter.convertUnit(1.5, 'l', 'ml');
        expect(ml.toStringAsFixed(0), '1500');

        final l = UnitConverter.convertUnit(750, 'ml', 'l');
        expect(l.toStringAsFixed(2), '0.75');
      });

      test('1 galón (US) = 3,785.41 ml', () {
        final ml = UnitConverter.convertUnit(1, 'gal', 'ml');
        expect(ml.toStringAsFixed(2), '3785.41');
      });

      test('1 onza líquida (fl oz) = 29.5735 ml', () {
        final ml = UnitConverter.convertUnit(2, 'fl_oz', 'ml');
        expect(ml.toStringAsFixed(4), '59.1470');
      });

      test('1 taza = 16 cucharadas = 48 cucharaditas', () {
        // 240 ml / 15 ml = 16 tbsp
        final tbsp = UnitConverter.convertUnit(1, 'taza', 'cda');
        expect(tbsp.toStringAsFixed(0), '16');

        // 240 ml / 5 ml = 48 tsp
        final tsp = UnitConverter.convertUnit(1, 'taza', 'cdta');
        expect(tsp.toStringAsFixed(0), '48');
      });
    });

    group('BR-CNV-03: Conversiones Cruzadas Masa <-> Volumen con Densidad', () {
      test('Conversión de taza de harina a gramos usando matriz de densidades', () {
        // Harina de trigo: ~0.5072 g/ml. 1 taza (240 ml) * 0.5072 = 121.728 g
        final density = CulinaryDensityMatrix.getDensity('harina_trigo');
        final grams = UnitConverter.convertUnit(1.0, 'taza', 'g', density: density);
        expect(grams.toStringAsFixed(2), '121.73');
      });

      test('Conversión bidireccional gramos de leche a mililitros', () {
        // Leche entera: 1.0300 g/ml. 500 g / 1.03 = 485.4368 ml
        final density = CulinaryDensityMatrix.getDensity('leche_entera');
        final ml = UnitConverter.convertUnit(500, 'g', 'ml', density: density);
        expect(ml.toStringAsFixed(2), '485.44');

        // De regreso a gramos
        final backGrams = UnitConverter.convertUnit(ml, 'ml', 'g', density: density);
        expect(backGrams.toStringAsFixed(2), '500.00');
      });

      test('Densidad cero o negativa arroja CrossDimensionConversionException', () {
        expect(
          () => UnitConverter.convertUnit(1, 'ml', 'g', density: 0),
          throwsA(isA<CrossDimensionConversionException>()),
        );
        expect(
          () => UnitConverter.convertUnit(1, 'ml', 'g', density: -1.2),
          throwsA(isA<CrossDimensionConversionException>()),
        );
      });
    });

    group('BR-CNV-04: Conversiones con Conteo (Piezas, Huevos, Docenas)', () {
      test('Conversión intra-conteo: Docenas <-> Unidades', () {
        final units = UnitConverter.convertUnit(2.5, 'docena', 'unidad');
        expect(units.toStringAsFixed(0), '30');

        final dozens = UnitConverter.convertUnit(18, 'unidad', 'docena');
        expect(dozens.toStringAsFixed(1), '1.5');
      });

      test('Conversión de unidades a gramos sin peso estándar arroja IncompatibleUnitDimensionException', () {
        expect(
          () => UnitConverter.convertUnit(4, 'unidad', 'g'),
          throwsA(isA<IncompatibleUnitDimensionException>()),
        );
      });

      test('Conversión de huevos a gramos con peso estándar (50g por huevo)', () {
        // 4 huevos * 50 g/huevo = 200 g
        final grams = UnitConverter.convertUnit(4, 'unidad', 'g', standardWeight: 50);
        expect(grams.toStringAsFixed(0), '200');

        // 350 g / 50 g = 7 huevos
        final eggs = UnitConverter.convertUnit(350, 'g', 'unidad', standardWeight: 50);
        expect(eggs.toStringAsFixed(0), '7');
      });

      test('Conversión de huevos a ml con peso estándar y densidad', () {
        // 2 huevos * 50 g/huevo = 100 g. Densidad huevo ~1.03 g/ml -> 100 / 1.03 = 97.087 ml
        final ml = UnitConverter.convertUnit(
          2,
          'unidad',
          'ml',
          standardWeight: 50,
          density: 1.03,
        );
        expect(ml.toStringAsFixed(2), '97.09');
      });

      test('Conversión de conteo a volumen sin densidad arroja CrossDimensionConversionException', () {
        expect(
          () => UnitConverter.convertUnit(2, 'unidad', 'ml', standardWeight: 50),
          throwsA(isA<CrossDimensionConversionException>()),
        );
      });
    });

    group('Casos Límite y Manejo de Errores', () {
      test('Cantidad 0 retorna 0 sin excepciones', () {
        final result = UnitConverter.convertUnit(0, 'taza', 'ml');
        expect(result.isZero, isTrue);
      });

      test('Misma unidad origen y destino retorna el mismo valor exacto', () {
        final val = PreciseDecimal.fromString('123.4567');
        final result = UnitConverter.convertUnit(val, 'kg', 'kg');
        expect(result, equals(val));
      });

      test('Unidad no reconocida arroja InvalidUnitException', () {
        expect(
          () => UnitConverter.convertUnit(10, 'unidad_fantasma', 'g'),
          throwsA(isA<InvalidUnitException>()),
        );
      });

      test('CulinaryUnit.fromString y tryParse resuelven alias y case-insensitivity', () {
        expect(CulinaryUnit.fromString('KG'), CulinaryUnit.kilogram);
        expect(CulinaryUnit.fromString('tbsp'), CulinaryUnit.tablespoon);
        expect(CulinaryUnit.fromString('cucharadas'), CulinaryUnit.tablespoon);
        expect(CulinaryUnit.fromString('tazas'), CulinaryUnit.cup);
        expect(CulinaryUnit.tryParse('inexistente'), isNull);
      });
    });

    group('Compatibilidad con Métodos Históricos', () {
      test('toMilliliters, toGrams, toUnits, determineBaseUnit', () {
        expect(UnitConverter.toMilliliters(PreciseDecimal.fromInt(1), 'taza').toStringAsFixed(0), '240');
        expect(UnitConverter.toGrams(PreciseDecimal.fromInt(1), 'kg').toStringAsFixed(0), '1000');
        expect(UnitConverter.toUnits(PreciseDecimal.fromInt(2), 'docena').toStringAsFixed(0), '24');
        expect(UnitConverter.determineBaseUnit('taza'), 'ml');
        expect(UnitConverter.determineBaseUnit('lb'), 'g');
        expect(UnitConverter.determineBaseUnit('docena'), 'unidad');
      });

      test('SRS CA-01: Verificación de Prorrateo de Harina (5 lb saco a \$3.00)', () {
        // 5 lb = 5 * 453.59237 = 2267.96185 g
        final bagGrams = UnitConverter.toGrams(PreciseDecimal.fromInt(5), 'lb');
        final bagPrice = PreciseDecimal.fromString('3.00');
        final costPerGram = bagPrice / bagGrams;

        final recipeFlourGrams = PreciseDecimal.fromString('200.00');
        final costUsed = recipeFlourGrams * costPerGram;

        expect(costUsed.toStringAsFixed(2), '0.26');
        expect(costUsed.toCurrencyString(), r'$0.26');
      });
    });
  });
}
