import 'package:equatable/equatable.dart';
import '../../domain/entities/recipe.dart';

abstract class RecipesState extends Equatable {
  const RecipesState();

  @override
  List<Object?> get props => [];
}

class RecipesInitial extends RecipesState {
  const RecipesInitial();
}

class RecipesLoading extends RecipesState {
  const RecipesLoading();
}

class RecipesLoaded extends RecipesState {
  final List<Recipe> recipes;
  final String searchQuery;
  final String? statusFilter;

  const RecipesLoaded(
    this.recipes, {
    this.searchQuery = '',
    this.statusFilter,
  });

  List<Recipe> get filteredRecipes {
    return recipes.where((r) {
      final matchesQuery = searchQuery.isEmpty ||
          r.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (r.description?.toLowerCase().contains(searchQuery.toLowerCase()) ??
              false);
      final matchesStatus = statusFilter == null ||
          statusFilter!.isEmpty ||
          r.status == statusFilter;
      return matchesQuery && matchesStatus;
    }).toList();
  }

  @override
  List<Object?> get props => [recipes, searchQuery, statusFilter];
}

class RecipesError extends RecipesState {
  final String message;

  const RecipesError(this.message);

  @override
  List<Object?> get props => [message];
}
