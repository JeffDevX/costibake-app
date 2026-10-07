import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PreciseDecimal Arithmetic & Precision Tests', () {
    test('Addition exact precision without floating point errors', () {
      final a = PreciseDecimal.fromString('0.1');
      final b = PreciseDecimal.fromString('0.2');
      final result = a + b;
      expect(result.toStringAsFixed(2), '0.30');
      expect(result.toStringAsFixed(1), '0.3');
    });

    test('Subtraction exact precision', () {
      final a = PreciseDecimal.fromString('10.5000');
      final b = PreciseDecimal.fromString('3.2500');
      final result = a - b;
      expect(result.toStringAsFixed(4), '7.2500');
    });

    test('Multiplication exact scaling', () {
      final price = PreciseDecimal.fromString('45.0000');
      final quantity = PreciseDecimal.fromString('2.5000');
      final total = price * quantity;
      expect(total.toStringAsFixed(2), '112.50');
    });

    test('Division exact scaling', () {
      final total = PreciseDecimal.fromString('100.0000');
      final parts = PreciseDecimal.fromString('3.0000');
      final result = total / parts;
      expect(result.toStringAsFixed(4), '33.3333');
      expect(result.toStringAsFixed(2), '33.33');
    });

    test('Division by zero throws FormatException', () {
      final a = PreciseDecimal.fromString('10.0');
      expect(
        () => a / PreciseDecimal.zero,
        throwsA(isA<FormatException>()),
      );
    });

    test('Comparison operators', () {
      final a = PreciseDecimal.fromString('10.0');
      final b = PreciseDecimal.fromString('20.0');
      final c = PreciseDecimal.fromString('10.0');

      expect(a < b, isTrue);
      expect(b > a, isTrue);
      expect(a <= c, isTrue);
      expect(a >= c, isTrue);
      expect(a == c, isTrue);
      expect(a == b, isFalse);
    });

    test('Currency formatting', () {
      final amount = PreciseDecimal.fromString('125.50');
      expect(amount.toCurrencyString(), r'$125.50');
      expect(amount.toCurrencyString(symbol: '€'), '€125.50');
    });

    test('Negative numbers and abs', () {
      final neg = PreciseDecimal.fromString('-15.75');
      expect(neg.isNegative, isTrue);
      expect(neg.abs().toStringAsFixed(2), '15.75');
    });
  });
}
