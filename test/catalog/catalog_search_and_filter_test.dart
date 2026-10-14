import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/core/utils/text_search_utils.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_state.dart';
import 'package:costibake_app/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:costibake_app/features/catalog/presentation/screens/ingredient_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockIngredientRepo implements IngredientRepository {
  List<Ingredient> items = [];

  @override
  Future<List<Ingredient>> getAllIngredients() async => List.of(items);
  @override
  Future<Ingredient?> getIngredientById(String id) async =>
      items.where((e) => e.id == id).firstOrNull;
  @override
  Future<List<Ingredient>> searchIngredients(String query, {String? category}) async =>
      items;
  @override
  Future<void> saveIngredient(Ingredient ingredient) async {
    items.removeWhere((e) => e.id == ingredient.id);
    items.add(ingredient);
  }
  @override
  Future<void> deleteIngredient(String id, {bool force = false}) async {
    items.removeWhere((e) => e.id == id);
  }
  @override
  Future<List<String>> getRecipesUsingIngredient(String ingredientId) async => [];
}

class _MockPackagingRepo implements PackagingRepository {
  List<Packaging> items = [];

  @override
  Future<List<Packaging>> getAllPackaging() async => List.of(items);
  @override
  Future<Packaging?> getPackagingById(String id) async =>
      items.where((p) => p.id == id).firstOrNull;
  @override
  Future<List<Packaging>> searchPackaging(String query, {String? category}) async =>
      items;
  @override
  Future<void> savePackaging(Packaging packaging) async {
    items.removeWhere((p) => p.id == packaging.id);
    items.add(packaging);
  }
  @override
  Future<void> deletePackaging(String id, {bool force = false}) async {
    items.removeWhere((p) => p.id == id);
  }
  @override
  Future<List<String>> getRecipesUsingPackaging(String packagingId) async => [];
}

void main() {
  group('BR-SRH-01: TextSearchUtils Diacritics & Case Insensitive Normalization', () {
    test('Normalizes Spanish vowels with accents / tildes', () {
      expect(TextSearchUtils.normalize('Azúcar'), equals('azucar'));
      expect(TextSearchUtils.normalize('Limón'), equals('limon'));
      expect(TextSearchUtils.normalize('Café'), equals('cafe'));
      expect(TextSearchUtils.normalize('Ñandú'), equals('nandu'));
      expect(TextSearchUtils.normalize('MARACUYÁ'), equals('maracuya'));
    });

    test('ContainsNormalized matches correctly across accents and cases', () {
      expect(TextSearchUtils.containsNormalized('Azúcar Blanca Refinada', 'azucar'), isTrue);
      expect(TextSearchUtils.containsNormalized('Azúcar Blanca Refinada', 'AZÚCAR'), isTrue);
      expect(TextSearchUtils.containsNormalized('Harina de Trigo', 'trigo'), isTrue);
      expect(TextSearchUtils.containsNormalized('Harina de Trigo', 'harina'), isTrue);
      expect(TextSearchUtils.containsNormalized('Mantequilla sin sal', 'chocolate'), isFalse);
    });
  });

  group('CatalogBloc - Search & Filtering Logic (JEF-10)', () {
    late _MockIngredientRepo ingredientRepo;
    late _MockPackagingRepo packagingRepo;
    late CatalogBloc bloc;

    final ing1 = Ingredient(
      id: 'ing-1',
      name: 'Azúcar Blanca',
      category: 'Azúcares y Endulzantes',
      purchaseCost: PreciseDecimal.fromString('2.50'),
      purchaseQuantity: PreciseDecimal.fromInt(1),
      purchaseUnit: 'kg',
      wastePercentage: PreciseDecimal.zero,
      minimumUnitCost: PreciseDecimal.fromString('0.0025'),
      minimumUnit: 'g',
      updatedAt: DateTime.now(),
    );

    final ing2 = Ingredient(
      id: 'ing-2',
      name: 'Harina de Trigo 0000',
      category: 'Harinas y Secos',
      purchaseCost: PreciseDecimal.fromString('3.00'),
      purchaseQuantity: PreciseDecimal.fromInt(1),
      purchaseUnit: 'kg',
      wastePercentage: PreciseDecimal.zero,
      minimumUnitCost: PreciseDecimal.fromString('0.0030'),
      minimumUnit: 'g',
      updatedAt: DateTime.now(),
    );

    final ing3 = Ingredient(
      id: 'ing-3',
      name: 'Mantequilla Gloria',
      category: 'Grasas y Mantequillas',
      purchaseCost: PreciseDecimal.fromString('5.00'),
      purchaseQuantity: PreciseDecimal.fromInt(1),
      purchaseUnit: 'kg',
      wastePercentage: PreciseDecimal.zero,
      minimumUnitCost: PreciseDecimal.fromString('0.0050'),
      minimumUnit: 'g',
      updatedAt: DateTime.now(),
    );

    final pack1 = Packaging(
      id: 'pack-1',
      name: 'Caja para Pastel 10"',
      category: 'Cajas para Pastel',
      packageCost: PreciseDecimal.fromString('25.00'),
      unitsPerPackage: 50,
      unitCost: PreciseDecimal.fromString('0.5000'),
      notes: 'MDF 10 pulgadas',
      updatedAt: DateTime.now(),
    );

    final pack2 = Packaging(
      id: 'pack-2',
      name: 'Domo para Cupcakes x6',
      category: 'Domos y Contenedores',
      packageCost: PreciseDecimal.fromString('12.00'),
      unitsPerPackage: 20,
      unitCost: PreciseDecimal.fromString('0.6000'),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      ingredientRepo = _MockIngredientRepo();
      packagingRepo = _MockPackagingRepo();
      ingredientRepo.items = [ing1, ing2, ing3];
      packagingRepo.items = [pack1, pack2];

      bloc = CatalogBloc(
        ingredientRepository: ingredientRepo,
        packagingRepository: packagingRepo,
      );
    });

    tearDown(() {
      bloc.close();
    });

    test('Loads catalog with all items when initially dispatched', () async {
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          const CatalogLoading(),
          predicate<CatalogLoaded>((state) {
            return state.ingredients.length == 3 && state.packagings.length == 2;
          }),
        ]),
      );

      bloc.add(const LoadCatalog());
      await expectation;
    });

    test('FilterCatalog filters ingredients by search query without diacritics', () async {
      bloc.add(const LoadCatalog());
      await bloc.stream.firstWhere((s) => s is CatalogLoaded);

      // Search 'azucar' without accent should match 'Azúcar Blanca'
      bloc.add(const FilterCatalog(query: 'azucar'));

      final state = await bloc.stream.firstWhere((s) => s is CatalogLoaded) as CatalogLoaded;
      expect(state.ingredients.length, equals(1));
      expect(state.ingredients.first.name, equals('Azúcar Blanca'));
    });

    test('FilterCatalog filters ingredients by category', () async {
      bloc.add(const LoadCatalog());
      await bloc.stream.firstWhere((s) => s is CatalogLoaded);

      bloc.add(const FilterCatalog(ingredientCategory: 'Harinas y Secos'));

      final state = await bloc.stream.firstWhere((s) => s is CatalogLoaded) as CatalogLoaded;
      expect(state.ingredients.length, equals(1));
      expect(state.ingredients.first.name, equals('Harina de Trigo 0000'));
    });

    test('FilterCatalog filters packagings by search query and category', () async {
      bloc.add(const LoadCatalog());
      await bloc.stream.firstWhere((s) => s is CatalogLoaded);

      bloc.add(const FilterCatalog(query: 'cupcake'));

      final state = await bloc.stream.firstWhere((s) => s is CatalogLoaded) as CatalogLoaded;
      expect(state.packagings.length, equals(1));
      expect(state.packagings.first.name, equals('Domo para Cupcakes x6'));
    });

    test('FilterCatalog matching notes attribute in packagings', () async {
      bloc.add(const LoadCatalog());
      await bloc.stream.firstWhere((s) => s is CatalogLoaded);

      bloc.add(const FilterCatalog(query: 'MDF'));

      final state = await bloc.stream.firstWhere((s) => s is CatalogLoaded) as CatalogLoaded;
      expect(state.packagings.length, equals(1));
      expect(state.packagings.first.name, equals('Caja para Pastel 10"'));
    });
  });

  group('CatalogScreen UI - Search Bar, Filter Chips & Empty States', () {
    late _MockIngredientRepo ingredientRepo;
    late _MockPackagingRepo packagingRepo;
    late CatalogBloc bloc;

    setUp(() {
      ingredientRepo = _MockIngredientRepo();
      packagingRepo = _MockPackagingRepo();

      ingredientRepo.items = [
        Ingredient(
          id: 'ing-1',
          name: 'Azúcar Blanca',
          category: 'Azúcares y Endulzantes',
          purchaseCost: PreciseDecimal.fromString('2.50'),
          purchaseQuantity: PreciseDecimal.fromInt(1),
          purchaseUnit: 'kg',
          wastePercentage: PreciseDecimal.zero,
          minimumUnitCost: PreciseDecimal.fromString('0.0025'),
          minimumUnit: 'g',
          updatedAt: DateTime.now(),
        ),
        Ingredient(
          id: 'ing-2',
          name: 'Harina de Trigo',
          category: 'Harinas y Secos',
          purchaseCost: PreciseDecimal.fromString('3.00'),
          purchaseQuantity: PreciseDecimal.fromInt(1),
          purchaseUnit: 'kg',
          wastePercentage: PreciseDecimal.zero,
          minimumUnitCost: PreciseDecimal.fromString('0.0030'),
          minimumUnit: 'g',
          updatedAt: DateTime.now(),
        ),
      ];

      packagingRepo.items = [
        Packaging(
          id: 'pack-1',
          name: 'Caja para Pastel 10"',
          category: 'Cajas para Pastel',
          packageCost: PreciseDecimal.fromString('25.00'),
          unitsPerPackage: 50,
          unitCost: PreciseDecimal.fromString('0.5000'),
          updatedAt: DateTime.now(),
        ),
      ];

      bloc = CatalogBloc(
        ingredientRepository: ingredientRepo,
        packagingRepository: packagingRepo,
      );
    });

    tearDown(() {
      bloc.close();
    });

    Widget buildTestable(Widget child) {
      return BlocProvider<CatalogBloc>.value(
        value: bloc,
        child: MaterialApp(home: child),
      );
    }

    Future<void> ensureLoaded(WidgetTester tester) async {
      await tester.runAsync(() async {
        if (bloc.state is! CatalogLoaded) {
          final future = bloc.stream.firstWhere((s) => s is CatalogLoaded);
          bloc.add(const LoadCatalog());
          await future;
        }
      });
    }

    testWidgets('Renders search bar and category filter chips in CatalogScreen',
        (tester) async {
      await ensureLoaded(tester);

      await tester.pumpWidget(buildTestable(const CatalogScreen()));
      await tester.pump();

      // Search bar is visible
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Buscar insumos, harinas, lácteos...'), findsOneWidget);

      // Visible chips are rendered in horizontal list
      expect(find.widgetWithText(FilterChip, 'Todos'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Harinas y Secos'), findsOneWidget);

      // Initial ingredients are rendered
      expect(find.text('Azúcar Blanca'), findsOneWidget);
      expect(find.text('Harina de Trigo'), findsOneWidget);
    });

    Future<void> pumpBlocUpdate(WidgetTester tester) async {
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
    }

    testWidgets('Filtering by search query updates list reactively', (tester) async {
      await ensureLoaded(tester);

      await tester.pumpWidget(buildTestable(const CatalogScreen()));
      await tester.pump();

      // Type 'azucar' (unaccented) into search bar
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'azucar');
      await pumpBlocUpdate(tester);

      // Only 'Azúcar Blanca' should be shown
      expect(find.text('Azúcar Blanca'), findsOneWidget);
      expect(find.text('Harina de Trigo'), findsNothing);

      // Clear icon button should appear and reset search when tapped
      final clearButton = find.byTooltip('Limpiar búsqueda');
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await pumpBlocUpdate(tester);

      // Both items back
      expect(find.text('Azúcar Blanca'), findsOneWidget);
      expect(find.text('Harina de Trigo'), findsOneWidget);
    });

    testWidgets('Searching non-existent item displays BR-SRH-04 empty state with direct action',
        (tester) async {
      await ensureLoaded(tester);

      await tester.pumpWidget(buildTestable(const CatalogScreen()));
      await tester.pump();

      // Type non-existent ingredient 'Vainilla Bourbon'
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Vainilla Bourbon');
      await pumpBlocUpdate(tester);

      // Empty state shown
      expect(find.text('No se encontraron resultados para "Vainilla Bourbon"'), findsOneWidget);
      expect(find.text('Crear "Vainilla Bourbon" como Insumo'), findsOneWidget);
      expect(find.text('Limpiar Búsqueda y Filtros'), findsOneWidget);

      // Tap on create button
      await tester.tap(find.text('Crear "Vainilla Bourbon" como Insumo'));
      await tester.pumpAndSettle();

      // Opens IngredientFormScreen with prefilled name!
      expect(find.byType(IngredientFormScreen), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Vainilla Bourbon'), findsOneWidget);
    });
  });
}
