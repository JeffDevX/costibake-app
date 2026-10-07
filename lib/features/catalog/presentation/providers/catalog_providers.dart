import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ingredient_repository_impl.dart';
import '../../data/repositories/packaging_repository_impl.dart';
import '../../domain/entities/ingredient.dart';
import '../../domain/entities/packaging.dart';
import '../../domain/repositories/ingredient_repository.dart';
import '../../domain/repositories/packaging_repository.dart';

final ingredientRepositoryProvider = Provider<IngredientRepository>((ref) {
  return IngredientRepositoryImpl();
});

final packagingRepositoryProvider = Provider<PackagingRepository>((ref) {
  return PackagingRepositoryImpl();
});

final ingredientsListProvider =
    FutureProvider.autoDispose<List<Ingredient>>((ref) async {
  final repository = ref.watch(ingredientRepositoryProvider);
  return await repository.getAllIngredients();
});

final packagingListProvider =
    FutureProvider.autoDispose<List<Packaging>>((ref) async {
  final repository = ref.watch(packagingRepositoryProvider);
  return await repository.getAllPackaging();
});
