class DatabaseException implements Exception {
  final String message;
  final String? code;

  const DatabaseException(this.message, [this.code]);

  @override
  String toString() => 'DatabaseException: $message (code: $code)';
}

class ValidationException implements Exception {
  final String message;

  const ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

class NotFoundException implements Exception {
  final String message;

  const NotFoundException(this.message);

  @override
  String toString() => 'NotFoundException: $message';
}

class DependencyConstraintException implements Exception {
  final String message;
  final List<String> affectedRecipeNames;

  const DependencyConstraintException(
    this.message, {
    this.affectedRecipeNames = const [],
  });

  @override
  String toString() =>
      'DependencyConstraintException: $message (affected: $affectedRecipeNames)';
}

/// Thrown when attempting to convert between mass and volume without providing a valid density factor (BR-CNV-03).
class CrossDimensionConversionException implements Exception {
  final String fromUnit;
  final String toUnit;
  final String message;

  const CrossDimensionConversionException({
    required this.fromUnit,
    required this.toUnit,
    this.message =
        'No se puede convertir entre masa y volumen sin especificar la densidad del ingrediente (g/ml).',
  });

  @override
  String toString() =>
      'CrossDimensionConversionException: $message ($fromUnit -> $toUnit)';
}

/// Thrown when attempting to convert between count items and mass/volume without unit weight factor (BR-CNV-04).
class IncompatibleUnitDimensionException implements Exception {
  final String fromUnit;
  final String toUnit;
  final String message;

  const IncompatibleUnitDimensionException({
    required this.fromUnit,
    required this.toUnit,
    this.message =
        'No se pueden convertir unidades de conteo a masa o volumen sin el peso unitario estándar de la pieza.',
  });

  @override
  String toString() =>
      'IncompatibleUnitDimensionException: $message ($fromUnit -> $toUnit)';
}

/// Thrown when an unknown or unparsable unit string is provided.
class InvalidUnitException implements Exception {
  final String rawUnit;
  final String message;

  const InvalidUnitException(this.rawUnit, this.message);

  @override
  String toString() => 'InvalidUnitException: $message (input: $rawUnit)';
}

