import 'package:equatable/equatable.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/entities/packaging.dart';

abstract class CatalogEvent extends Equatable {
  const CatalogEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to load both ingredients and packagings from local SQLite storage
class LoadCatalog extends CatalogEvent {
  const LoadCatalog();
}

/// Add a new bulk ingredient
class AddIngredient extends CatalogEvent {
  final Ingredient ingredient;

  const AddIngredient(this.ingredient);

  @override
  List<Object?> get props => [ingredient];
}

/// Update an existing ingredient (triggers cascade update/recalculation)
class UpdateIngredient extends CatalogEvent {
  final Ingredient ingredient;

  const UpdateIngredient(this.ingredient);

  @override
  List<Object?> get props => [ingredient];
}

/// Delete an ingredient with dependency protection check
class DeleteIngredient extends CatalogEvent {
  final String id;
  final bool force;

  const DeleteIngredient({required this.id, this.force = false});

  @override
  List<Object?> get props => [id, force];
}

/// Add new packaging / disposable item
class AddPackaging extends CatalogEvent {
  final Packaging packaging;

  const AddPackaging(this.packaging);

  @override
  List<Object?> get props => [packaging];
}

/// Update existing packaging item
class UpdatePackaging extends CatalogEvent {
  final Packaging packaging;

  const UpdatePackaging(this.packaging);

  @override
  List<Object?> get props => [packaging];
}

/// Delete packaging item
class DeletePackaging extends CatalogEvent {
  final String id;
  final bool force;

  const DeletePackaging(this.id, {this.force = false});

  @override
  List<Object?> get props => [id, force];
}

/// Filter catalog items by search text query and category (JEF-10)
class FilterCatalog extends CatalogEvent {
  final String? query;
  final String? ingredientCategory;
  final String? packagingCategory;
  final bool clearIngredientCategory;
  final bool clearPackagingCategory;

  const FilterCatalog({
    this.query,
    this.ingredientCategory,
    this.packagingCategory,
    this.clearIngredientCategory = false,
    this.clearPackagingCategory = false,
  });

  @override
  List<Object?> get props => [
        query,
        ingredientCategory,
        packagingCategory,
        clearIngredientCategory,
        clearPackagingCategory,
      ];
}

/// Clears the transient dependency block notification state after the modal dialog is dismissed (JEF-17)
class ClearDependencyBlock extends CatalogEvent {
  const ClearDependencyBlock();
}

