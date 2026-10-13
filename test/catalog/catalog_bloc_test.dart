import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockIngredientRepository implements IngredientRepository {
  final List<Ingredient> _ingredients = [];

  @override
  Future<List<Ingredient>> getAllIngredients() async => List.of(_ingredients);

  @override
  Future<Ingredient?> getIngredientById(String id) async =>
      _ingredients.where((i) => i.id == id).firstOrNull;

  @override
  Future<List<Ingredient>> searchIngredients(String query, {String? category}) async =>
      _ingredients;

  @override
  Future<void> saveIngredient(Ingredient ingredient) async {
    _ingredients.removeWhere((i) => i.id == ingredient.id);
    _ingredients.add(ingredient);
  }

  @override
  Future<void> deleteIngredient(String id, {bool force = false}) async {
    _ingredients.removeWhere((i) => i.id == id);
  }

  @override
  Future<List<String>> getRecipesUsingIngredient(String ingredientId) async => [];
}

class MockPackagingRepository implements PackagingRepository {
  final List<Packaging> _packagings = [];

  @override
  Future<List<Packaging>> getAllPackaging() async => List.of(_packagings);

  @override
  Future<Packaging?> getPackagingById(String id) async =>
      _packagings.where((p) => p.id == id).firstOrNull;

  @override
  Future<List<Packaging>> searchPackaging(String query, {String? category}) async =>
      _packagings;

  @override
  Future<void> savePackaging(Packaging packaging) async {
    _packagings.removeWhere((p) => p.id == packaging.id);
    _packagings.add(packaging);
  }

  @override
  Future<void> deletePackaging(String id, {bool force = false}) async {
    _packagings.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<String>> getRecipesUsingPackaging(String packagingId) async => [];
}

void main() {
  late CatalogBloc catalogBloc;
  late MockIngredientRepository ingredientRepository;
  late MockPackagingRepository packagingRepository;

  setUp(() {
    ingredientRepository = MockIngredientRepository();
    packagingRepository = MockPackagingRepository();
    catalogBloc = CatalogBloc(
      ingredientRepository: ingredientRepository,
      packagingRepository: packagingRepository,
    );
  });

  tearDown(() {
    catalogBloc.close();
  });

  group('CatalogBloc Unit Tests (Pure BLoC Pattern)', () {
    test('Initial state is CatalogInitial', () {
      expect(catalogBloc.state, equals(const CatalogInitial()));
    });

    test('Emits [CatalogLoading, CatalogLoaded] when LoadCatalog is added', () async {
      final expected = [
        const CatalogLoading(),
        const CatalogLoaded(
          ingredients: [],
          packaging: [],
        ),
      ];

      expectLater(catalogBloc.stream, emitsInOrder(expected));
      catalogBloc.add(const LoadCatalog());
    });

    test('Adds ingredient and reloads catalog successfully', () async {
      final ingredient = Ingredient(
        id: 'ing-1',
        name: 'Harina Fina de Trigo',
        category: 'Secos',
        purchaseUnit: 'kg',
        purchaseQuantity: PreciseDecimal.fromString('50.00'),
        purchasePrice: PreciseDecimal.fromString('45.00'),
        minimumUnit: 'g',
        minimumUnitCost: PreciseDecimal.fromString('0.0009'),
        wastePercentage: PreciseDecimal.zero,
        notes: 'Insumo lote inicial',
        updatedAt: DateTime.now(),
      );

      final expected = [
        const CatalogLoading(),
        CatalogLoaded(
          ingredients: [ingredient],
          packaging: const [],
        ),
      ];

      expectLater(catalogBloc.stream, emitsInOrder(expected));
      catalogBloc.add(SaveIngredient(ingredient));
    });
  });
}
