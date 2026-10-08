import 'package:equatable/equatable.dart';

/// A high-precision decimal class that operates on fixed-point scaled integers (10^6).
/// Prevents IEEE 754 binary floating-point representation errors in commercial bakery costing.
class PreciseDecimal extends Equatable implements Comparable<PreciseDecimal> {
  static const int internalScale = 6;
  static final BigInt _scaleMultiplier = BigInt.from(1000000); // 10^6

  final BigInt _scaledValue;

  const PreciseDecimal._(this._scaledValue);

  static const PreciseDecimal zero = PreciseDecimal._(BigInt.zero);
  static final PreciseDecimal one = PreciseDecimal._(BigInt.from(1000000));

  /// Creates a PreciseDecimal from a string representation (e.g., "12.3456").
  factory PreciseDecimal.fromString(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return PreciseDecimal.zero;

    final isNegative = cleaned.startsWith('-');
    final signAgnostic = isNegative ? cleaned.substring(1) : cleaned;

    final parts = signAgnostic.split('.');
    final integerPart = parts[0].isEmpty ? '0' : parts[0];
    final fractionalPart = parts.length > 1 ? parts[1] : '';

    final paddedFraction = fractionalPart.length >= internalScale
        ? fractionalPart.substring(0, internalScale)
        : fractionalPart.padRight(internalScale, '0');

    final totalString = '$integerPart$paddedFraction';
    var parsedBigInt = BigInt.tryParse(totalString) ?? BigInt.zero;
    if (isNegative) parsedBigInt = -parsedBigInt;

    return PreciseDecimal._(parsedBigInt);
  }

  /// Creates a PreciseDecimal from an integer.
  factory PreciseDecimal.fromInt(int value) {
    return PreciseDecimal._(BigInt.from(value) * _scaleMultiplier);
  }

  /// Creates a PreciseDecimal from a double, converting via string to minimize IEEE 754 precision artifacts.
  factory PreciseDecimal.fromDouble(double value) {
    if (value.isNaN || value.isInfinite) return PreciseDecimal.zero;
    // Format double to 6 decimal places to capture standard representation
    return PreciseDecimal.fromString(value.toStringAsFixed(internalScale));
  }

  /// Raw scaled BigInt accessor
  BigInt get rawScaledValue => _scaledValue;

  PreciseDecimal operator +(PreciseDecimal other) {
    return PreciseDecimal._(_scaledValue + other._scaledValue);
  }

  PreciseDecimal operator -(PreciseDecimal other) {
    return PreciseDecimal._(_scaledValue - other._scaledValue);
  }

  PreciseDecimal operator *(PreciseDecimal other) {
    // (_scaledValue * other._scaledValue) / 10^6 with symmetric rounding
    final product = _scaledValue * other._scaledValue;
    final quotient = product ~/ _scaleMultiplier;
    return PreciseDecimal._(quotient);
  }

  PreciseDecimal operator /(PreciseDecimal other) {
    if (other._scaledValue == BigInt.zero) {
      throw const FormatException('División por cero en cálculo de precisión');
    }
    // (_scaledValue * 10^6) / other._scaledValue
    final scaledNumerator = _scaledValue * _scaleMultiplier;
    final quotient = scaledNumerator ~/ other._scaledValue;
    return PreciseDecimal._(quotient);
  }

  PreciseDecimal operator -() => PreciseDecimal._(-_scaledValue);

  bool get isZero => _scaledValue == BigInt.zero;
  bool get isNegative => _scaledValue < BigInt.zero;
  bool get isPositive => _scaledValue > BigInt.zero;

  PreciseDecimal abs() => PreciseDecimal._(_scaledValue.abs());

  /// Returns the double value (intended only for visualization / charts, not calculations).
  double toDouble() => _scaledValue.toDouble() / 1000000.0;

  /// Formats the number with a specific number of decimal places (e.g., 2 for currency, 4 for unit cost).
  String toStringAsFixed(int fractionDigits) {
    assert(fractionDigits >= 0 && fractionDigits <= internalScale);
    final isNeg = _scaledValue < BigInt.zero;
    final absolute = _scaledValue.abs();

    final integerPart = absolute ~/ _scaleMultiplier;
    final remainder = absolute % _scaleMultiplier;

    final fracString = remainder.toString().padLeft(internalScale, '0');

    if (fractionDigits == 0) {
      // Round to nearest integer
      final half = _scaleMultiplier ~/ BigInt.from(2);
      final roundedInt = remainder >= half ? integerPart + BigInt.one : integerPart;
      return '${isNeg ? '-' : ''}$roundedInt';
    }

    // Determine rounding for the requested fractionDigits
    final cutoff = internalScale - fractionDigits;
    final divisor = BigInt.from(10).pow(cutoff);
    final half = divisor ~/ BigInt.from(2);

    final subRemainder = remainder % divisor;
    var truncatedFrac = remainder ~/ divisor;

    if (subRemainder >= half) {
      truncatedFrac += BigInt.one;
    }

    // If rounding up overflows the requested fractionDigits
    final maxFrac = BigInt.from(10).pow(fractionDigits);
    var finalInteger = integerPart;
    if (truncatedFrac >= maxFrac) {
      truncatedFrac = BigInt.zero;
      finalInteger += BigInt.one;
    }

    final formattedFrac = truncatedFrac.toString().padLeft(fractionDigits, '0');
    return '${isNeg ? '-' : ''}$finalInteger.$formattedFrac';
  }

  /// Formats as currency with 2 decimal places and a currency symbol
  String toCurrencyString({String symbol = r'$'}) {
    return '$symbol${toStringAsFixed(2)}';
  }

  @override
  String toString() => toStringAsFixed(4);

  @override
  int compareTo(PreciseDecimal other) => _scaledValue.compareTo(other._scaledValue);

  bool operator <(PreciseDecimal other) => _scaledValue < other._scaledValue;
  bool operator <=(PreciseDecimal other) => _scaledValue <= other._scaledValue;
  bool operator >(PreciseDecimal other) => _scaledValue > other._scaledValue;
  bool operator >=(PreciseDecimal other) => _scaledValue >= other._scaledValue;

  @override
  List<Object?> get props => [_scaledValue];
}
