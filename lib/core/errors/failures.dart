import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  List<Object?> get props => [message, code];
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, [super.code]);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [super.code]);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, [super.code]);
}

class DependencyConstraintFailure extends Failure {
  final List<String> affectedRecipeNames;

  const DependencyConstraintFailure(
    super.message, {
    this.affectedRecipeNames = const [],
    super.code,
  });

  @override
  List<Object?> get props => [message, code, affectedRecipeNames];
}
