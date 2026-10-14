import 'package:equatable/equatable.dart';
import '../../../../core/utils/text_search_utils.dart';
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
  final List<Ingredient> allIngredients;
  final List<Packaging> allPackagings;
  final String searchQuery;
  final String? ingredientCategory;
  final String? packagingCategory;

  const CatalogLoaded({
    required List<Ingredient> ingredients,
    required List<Packaging> packagings,
    this.searchQuery = '',
    this.ingredientCategory,
    this.packagingCategory,
  })  : allIngredients = ingredients,
        allPackagings = packagings;

  /// Filtered ingredients by search text query and category (BR-SRH-01, BR-SRH-03)
  List<Ingredient> get ingredients {
    return allIngredients.where((item) {
      if (ingredientCategory != null &&
          ingredientCategory!.isNotEmpty &&
          ingredientCategory != 'Todos') {
        if (item.category.toLowerCase() != ingredientCategory!.toLowerCase()) {
          return false;
        }
      }
      if (searchQuery.trim().isNotEmpty) {
        if (!TextSearchUtils.containsNormalized(item.name, searchQuery) &&
            !TextSearchUtils.containsNormalized(item.category, searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Filtered packagings by search text query and category (BR-SRH-01, BR-SRH-03)
  List<Packaging> get packagings {
    return allPackagings.where((item) {
      if (packagingCategory != null &&
          packagingCategory!.isNotEmpty &&
          packagingCategory != 'Todos') {
        if (item.category.toLowerCase() != packagingCategory!.toLowerCase()) {
          return false;
        }
      }
      if (searchQuery.trim().isNotEmpty) {
        if (!TextSearchUtils.containsNormalized(item.name, searchQuery) &&
            !TextSearchUtils.containsNormalized(item.category, searchQuery) &&
            !(item.notes != null &&
                TextSearchUtils.containsNormalized(item.notes!, searchQuery))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  List<Object?> get props => [
        allIngredients,
        allPackagings,
        searchQuery,
        ingredientCategory,
        packagingCategory,
      ];

  CatalogLoaded copyWith({
    List<Ingredient>? ingredients,
    List<Packaging>? packagings,
    String? searchQuery,
    String? ingredientCategory,
    String? packagingCategory,
    bool clearIngredientCategory = false,
    bool clearPackagingCategory = false,
  }) {
    return CatalogLoaded(
      ingredients: ingredients ?? allIngredients,
      packagings: packagings ?? allPackagings,
      searchQuery: searchQuery ?? this.searchQuery,
      ingredientCategory: clearIngredientCategory
          ? null
          : (ingredientCategory ?? this.ingredientCategory),
      packagingCategory: clearPackagingCategory
          ? null
          : (packagingCategory ?? this.packagingCategory),
    );
  }
}

class CatalogError extends CatalogState {
  final String message;

  const CatalogError(this.message);

  @override
  List<Object?> get props => [message];
}
