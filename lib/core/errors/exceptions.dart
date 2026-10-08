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
