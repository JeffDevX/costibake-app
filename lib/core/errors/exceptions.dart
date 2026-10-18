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

/// Thrown when attempting to nest a sub-recipe into another recipe that would cause a cyclic dependency (BR-REC-05).
class CircularRecipeDependencyException implements Exception {
  final String parentRecipeId;
  final String childRecipeId;
  final String message;

  const CircularRecipeDependencyException({
    required this.parentRecipeId,
    required this.childRecipeId,
    this.message =
        'Referencia circular detectada: una receta no puede incluirse a sí misma directa o indirectamente como sub-receta.',
  });

  @override
  String toString() =>
      'CircularRecipeDependencyException: $message ($parentRecipeId -> $childRecipeId)';
}

/// Thrown when any cost component is negative (BR-CST-01).
class NegativeCostComponentException implements Exception {
  final String componentName;
  final String message;

  const NegativeCostComponentException(
    this.componentName, [
    this.message = 'Ningún componente de costo puede ser negativo (BR-CST-01).',
  ]);

  @override
  String toString() =>
      'NegativeCostComponentException: $message ($componentName)';
}

/// Thrown when AI service configuration (e.g., API key) is missing or invalid.
class AiConfigException implements Exception {
  final String message;

  const AiConfigException(this.message);

  @override
  String toString() => 'AiConfigException: $message';
}

/// Thrown when AI extraction fails due to network, model, or parsing errors.
class AiExtractionException implements Exception {
  final String message;
  final dynamic originalError;

  const AiExtractionException(this.message, [this.originalError]);

  @override
  String toString() =>
      'AiExtractionException: $message${originalError != null ? ' ($originalError)' : ''}';
}

