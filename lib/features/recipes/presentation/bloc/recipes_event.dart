import 'package:equatable/equatable.dart';
import '../../domain/entities/recipe.dart';

abstract class RecipesEvent extends Equatable {
  const RecipesEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to load all recipes with their relational ingredients, sub-recipes, and packaging
class LoadRecipes extends RecipesEvent {
  const LoadRecipes();
}

/// Dispatched to filter in-memory recipes by search query or status
class FilterRecipes extends RecipesEvent {
  final String query;
  final String? status;

  const FilterRecipes({this.query = '', this.status});

  @override
  List<Object?> get props => [query, status];
}

/// Create a new recipe
class CreateRecipe extends RecipesEvent {
  final Recipe recipe;

  const CreateRecipe(this.recipe);

  @override
  List<Object?> get props => [recipe];
}

/// Update an existing recipe
class UpdateRecipe extends RecipesEvent {
  final Recipe recipe;

  const UpdateRecipe(this.recipe);

  @override
  List<Object?> get props => [recipe];
}

/// Delete a recipe
class DeleteRecipe extends RecipesEvent {
  final String id;

  const DeleteRecipe(this.id);

  @override
  List<Object?> get props => [id];
}
