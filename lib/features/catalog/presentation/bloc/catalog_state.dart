import 'package:equatable/equatable.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/entities/packaging.dart';

abstract class CatalogState extends Equatable {
  const CatalogState();

  @override
  List<Object?> get props => [];
}

class CatalogInitial extends CatalogState {
  const CatalogInitial();
}

class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

class CatalogLoaded extends CatalogState {
  final List<Ingredient> ingredients;
  final List<Packaging> packagings;

  const CatalogLoaded({
    required this.ingredients,
    required this.packagings,
  });

  @override
  List<Object?> get props => [ingredients, packagings];

  CatalogLoaded copyWith({
    List<Ingredient>? ingredients,
    List<Packaging>? packagings,
  }) {
    return CatalogLoaded(
      ingredients: ingredients ?? this.ingredients,
      packagings: packagings ?? this.packagings,
    );
  }
}

class CatalogError extends CatalogState {
  final String message;

  const CatalogError(this.message);

  @override
  List<Object?> get props => [message];
}
