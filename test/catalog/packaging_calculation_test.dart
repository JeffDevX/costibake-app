import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_state.dart';
import 'package:costibake_app/features/catalog/presentation/screens/packaging_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockIngredientRepo implements IngredientRepository {
  @override
  Future<List<Ingredient>> getAllIngredients() async => [];
  @override
  Future<Ingredient?> getIngredientById(String id) async => null;
  @override
  Future<List<Ingredient>> searchIngredients(String query, {String? category}) async => [];
  @override
  Future<void> saveIngredient(Ingredient ingredient) async {}
  @override
  Future<void> deleteIngredient(String id, {bool force = false}) async {}
  @override
  Future<List<String>> getRecipesUsingIngredient(String ingredientId) async => [];
}

class _MockPackagingRepo implements PackagingRepository {
  final List<Packaging> _items = [];

  @override
  Future<List<Packaging>> getAllPackaging() async => List.of(_items);
  @override
  Future<Packaging?> getPackagingById(String id) async =>
      _items.where((p) => p.id == id).firstOrNull;
  @override
  Future<List<Packaging>> searchPackaging(String query, {String? category}) async =>
      _items;
  @override
  Future<void> savePackaging(Packaging packaging) async {
    _items.removeWhere((p) => p.id == packaging.id);
    _items.add(packaging);
  }
  @override
  Future<void> deletePackaging(String id, {bool force = false}) async {
    _items.removeWhere((p) => p.id == id);
  }
  @override
  Future<List<String>> getRecipesUsingPackaging(String packagingId) async => [];
}

void main() {
  group('JEF-8 / RF-SYS-03 / BR-EMP-01: Cálculo de Costo Unitario de Empaque', () {
    test('Criterio Aceptación 1: Paquete de 50 cajas a \$25.00 -> \$0.5000 / pieza', () {
      final packageCost = PreciseDecimal.fromString('25.00');
      const units = 50;

      final unitCost = Packaging.calculateUnitCost(
        packageCost: packageCost,
        unitsPerPackage: units,
      );

      expect(unitCost.toStringAsFixed(4), equals('0.5000'));
      expect(unitCost.toCurrencyString(), equals(r'$0.50'));
    });

    test('Criterio Aceptación 2: Paquete de 100 capacillos a \$3.50 -> \$0.0350 / pieza', () {
      final packageCost = PreciseDecimal.fromString('3.50');
      const units = 100;

      final unitCost = Packaging.calculateUnitCost(
        packageCost: packageCost,
        unitsPerPackage: units,
      );

      expect(unitCost.toStringAsFixed(4), equals('0.0350'));
      expect(unitCost.toCurrencyString(), equals(r'$0.04'));
    });

    test('Criterio Aceptación 3: Paquete de 20 bases MDF a \$18.00 -> \$0.9000 / pieza', () {
      final packageCost = PreciseDecimal.fromString('18.00');
      const units = 20;

      final unitCost = Packaging.calculateUnitCost(
        packageCost: packageCost,
        unitsPerPackage: units,
      );

      expect(unitCost.toStringAsFixed(4), equals('0.9000'));
      expect(unitCost.toCurrencyString(), equals(r'$0.90'));
    });

    test('BR-EMP-02: Unidades <= 0 retorna costo cero para proteger división', () {
      final packageCost = PreciseDecimal.fromString('15.00');

      expect(Packaging.calculateUnitCost(packageCost: packageCost, unitsPerPackage: 0),
          equals(PreciseDecimal.zero));
      expect(Packaging.calculateUnitCost(packageCost: packageCost, unitsPerPackage: -5),
          equals(PreciseDecimal.zero));
    });
  });

  group('CatalogBloc - Packaging Events Unit Tests', () {
    late CatalogBloc bloc;
    late _MockIngredientRepo ingredientRepo;
    late _MockPackagingRepo packagingRepo;

    setUp(() {
      ingredientRepo = _MockIngredientRepo();
      packagingRepo = _MockPackagingRepo();
      bloc = CatalogBloc(
        ingredientRepository: ingredientRepo,
        packagingRepository: packagingRepo,
      );
    });

    tearDown(() {
      bloc.close();
    });

    test('AddPackaging guarda empaque y recarga catálogo', () async {
      final packaging = Packaging(
        id: 'pack-1',
        name: 'Caja Pastel 10"',
        category: 'Cajas para Pastel',
        packageCost: PreciseDecimal.fromString('25.00'),
        unitsPerPackage: 50,
        unitCost: PreciseDecimal.fromString('0.5000'),
        notes: 'Molde 10 pulgadas',
        updatedAt: DateTime.now(),
      );

      final expected = [
        const CatalogLoading(),
        CatalogLoaded(ingredients: const [], packagings: [packaging]),
      ];

      final expectation = expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(AddPackaging(packaging));
      await expectation;
    });

    test('DeletePackaging elimina empaque y recarga catálogo', () async {
      final packaging = Packaging(
        id: 'pack-1',
        name: 'Caja Pastel 10"',
        category: 'Cajas para Pastel',
        packageCost: PreciseDecimal.fromString('25.00'),
        unitsPerPackage: 50,
        unitCost: PreciseDecimal.fromString('0.5000'),
        updatedAt: DateTime.now(),
      );
      await packagingRepo.savePackaging(packaging);

      final expected = [
        const CatalogLoading(),
        const CatalogLoaded(ingredients: [], packagings: []),
      ];

      final expectation = expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const DeletePackaging('pack-1'));
      await expectation;
    });
  });

  group('PackagingFormScreen Widget & Responsive Tests', () {
    late CatalogBloc bloc;

    setUp(() {
      bloc = CatalogBloc(
        ingredientRepository: _MockIngredientRepo(),
        packagingRepository: _MockPackagingRepo(),
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

    testWidgets('PackagingFormScreen renders without overflow on compact 360x640 screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestable(const PackagingFormScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(PackagingFormScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Registrar Empaque'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PackagingFormScreen calculates unit cost reactively on user typing',
        (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestable(const PackagingFormScreen()));
      await tester.pumpAndSettle();

      // Enter cost 25.00 and units 50
      final costField = find.widgetWithText(TextFormField, 'Costo Total del Paquete *');
      final unitsField = find.widgetWithText(TextFormField, 'Unidades por Paquete *');

      await tester.enterText(costField, '25.00');
      await tester.enterText(unitsField, '50');
      await tester.pumpAndSettle();

      // Verify the banner recalculated
      expect(find.text(r'$0.5000 / pieza'), findsOneWidget);
      expect(find.text(r'$0.50/u'), findsOneWidget);
    });
  });
}
