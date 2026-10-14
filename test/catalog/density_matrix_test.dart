import 'package:costibake_app/core/constants/culinary_units.dart';
import 'package:costibake_app/core/database/app_database.dart';
import 'package:costibake_app/core/database/database_tables.dart';
import 'package:costibake_app/core/errors/exceptions.dart';
import 'package:costibake_app/core/services/density_calculator_service.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/catalog/data/datasources/density_local_datasource.dart';
import 'package:costibake_app/features/catalog/data/models/culinary_density_model.dart';
import 'package:costibake_app/features/catalog/data/repositories/density_repository_impl.dart';
import 'package:costibake_app/features/catalog/domain/entities/culinary_density.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:costibake_app/features/catalog/presentation/screens/ingredient_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('JEF-12: Matriz de Densidades de Repostería (Volumen a Peso)', () {
    late Database db;
    late DensityRepositoryImpl densityRepo;
    late DensityCalculatorService densityService;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      AppDatabase.setMockDatabase(db);

      // Create schema and seed
      await db.execute(DatabaseTables.createTableInsumo);
      await db.execute(DatabaseTables.createTableEmpaque);
      await db.execute(DatabaseTables.createTableReceta);
      await db.execute(DatabaseTables.createTableRecetaInsumo);
      await db.execute(DatabaseTables.createTableRecetaEmpaque);
      await db.execute(DatabaseTables.createTableConfiguracionNegocio);
      await db.execute(DatabaseTables.createTableMatrizDensidad);
      for (final idx in DatabaseTables.createIndexes) {
        await db.execute(idx);
      }

      for (final item in AppDatabase.defaultCulinaryDensities) {
        await db.insert(
          DatabaseTables.tableMatrizDensidad,
          item,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final dataSource = DensityLocalDataSourceImpl(database: AppDatabase.instance);
      densityRepo = DensityRepositoryImpl(localDataSource: dataSource);
      densityService = DensityCalculatorService(densityRepository: densityRepo);
    });

    tearDown(() async {
      await db.close();
    });

    group('Criterios de Aceptación Verificables (SRS)', () {
      test('CA-1 & BR-DEN-02: Base de datos inicializa y siembra las 9 densidades estándar', () async {
        final densities = await densityRepo.getAllDensities();
        expect(densities.length, 9);

        final harina = await densityRepo.getDensityByKey('harina_trigo');
        expect(harina, isNotNull);
        expect(harina!.gramsPerCup.toStringAsFixed(1), '125.0');
        expect(harina.displayName, 'Harina de trigo todo uso');

        final azucar = await densityRepo.getDensityByKey('azucar_blanca');
        expect(azucar, isNotNull);
        expect(azucar!.gramsPerCup.toStringAsFixed(1), '200.0');

        final miel = await densityRepo.getDensityByKey('miel');
        expect(miel, isNotNull);
        expect(miel!.gramsPerCup.toStringAsFixed(1), '340.0');

        final mantequilla = await densityRepo.getDensityByKey('mantequilla');
        expect(mantequilla, isNotNull);
        expect(mantequilla!.gramsPerCup.toStringAsFixed(1), '227.0');

        final aceite = await densityRepo.getDensityByKey('aceite_vegetal');
        expect(aceite, isNotNull);
        expect(aceite!.gramsPerCup.toStringAsFixed(1), '218.0');

        final glass = await densityRepo.getDensityByKey('azucar_glass');
        expect(glass, isNotNull);
        expect(glass!.gramsPerCup.toStringAsFixed(1), '120.0');

        final cacao = await densityRepo.getDensityByKey('cacao_polvo');
        expect(cacao, isNotNull);
        expect(cacao!.gramsPerCup.toStringAsFixed(1), '100.0');

        final leche = await densityRepo.getDensityByKey('leche_entera');
        expect(leche, isNotNull);
        expect(leche!.gramsPerCup.toStringAsFixed(1), '245.0');

        final agua = await densityRepo.getDensityByKey('agua_pura');
        expect(agua, isNotNull);
        expect(agua!.gramsPerCup.toStringAsFixed(1), '240.0');
      });

      test('CA-2: 1 taza de harina se traduce a 125 gramos exactos y costea según \$/g', () {
        // Harina de trigo: 1 taza = 125.00 g exactos
        final grams = densityService.translateRecipeIngredientToGrams(
          quantity: 1.0,
          fromUnit: 'taza',
          ingredientNameOrKey: 'harina_trigo',
        );
        expect(grams.toStringAsFixed(2), '125.00');

        // Costeo con saco de 5 lb a $3.00
        // 5 lb = 2267.96185 g
        // Costo por gramo = 3.00 / 2267.96185
        // Costo de 1 taza (125g) = 125 * (3.00 / 2267.96185) = $0.1653 -> $0.17
        final cost = densityService.calculateRecipeVolumeCost(
          recipeVolume: 1.0,
          recipeVolumeUnit: 'taza',
          ingredientKey: 'harina_trigo',
          bulkPurchaseCost: PreciseDecimal.fromString('3.00'),
          bulkPurchaseQuantity: 5,
          bulkPurchaseUnit: 'lb',
        );
        expect(cost.toStringAsFixed(2), '0.17');
        expect(cost.toCurrencyString(), r'$0.17');
      });

      test('CA-3: 1 taza de azúcar común se traduce a 200 gramos exactos', () {
        final grams = densityService.translateRecipeIngredientToGrams(
          quantity: 1.0,
          fromUnit: 'taza',
          ingredientNameOrKey: 'azucar_blanca',
        );
        expect(grams.toStringAsFixed(2), '200.00');
        expect(grams.toDouble(), 200.0);
      });

      test('CA-4: 1/2 taza de miel se traduce a 170 gramos exactos', () {
        // 0.5 taza * 340 g/taza = 170.00 g
        final grams = densityService.translateRecipeIngredientToGrams(
          quantity: 0.5,
          fromUnit: 'taza',
          ingredientNameOrKey: 'miel',
        );
        expect(grams.toStringAsFixed(2), '170.00');
        expect(grams.toDouble(), 170.0);
      });

      test('CA-5: Validación de conversión inter-dimensional con tolerancia < 0.01 g', () {
        // 1/4 taza de harina = 0.25 * 125 = 31.25 g
        final quarterCup = densityService.volumeToMass(
          volume: 0.25,
          volumeUnit: CulinaryUnit.cup,
          ingredientKey: 'harina_trigo',
        );
        expect((quarterCup.toDouble() - 31.25).abs() < 0.01, isTrue);

        // 1/3 taza de mantequilla = 0.333333 * 227 = 75.666 g
        final thirdCupButter = densityService.volumeToMass(
          volume: 1.0 / 3.0,
          volumeUnit: CulinaryUnit.cup,
          ingredientKey: 'mantequilla',
        );
        expect((thirdCupButter.toDouble() - (227.0 / 3.0)).abs() < 0.01, isTrue);

        // 2 cucharadas de cacao en polvo (1 tbsp = 15 ml, cup = 240 ml, 2 tbsp = 30 ml -> 30 * 100/240 = 12.5 g)
        final tbspCacao = densityService.volumeToMass(
          volume: 2,
          volumeUnit: CulinaryUnit.tablespoon,
          ingredientKey: 'cacao_polvo',
        );
        expect((tbspCacao.toDouble() - 12.5).abs() < 0.01, isTrue);
      });
    });

    group('BR-DEN-03: Excepción Protectora ante Falta de Densidad', () {
      test('Intento de convertir volumen a masa sin densidad arroja CrossDimensionConversionException', () {
        expect(
          () => densityService.volumeToMass(
            volume: 1.0,
            volumeUnit: CulinaryUnit.cup,
            ingredientKey: 'insumo_sin_densidad_123',
          ),
          throwsA(isA<CrossDimensionConversionException>()),
        );
      });

      test('Intento de convertir masa a volumen sin densidad arroja CrossDimensionConversionException', () {
        expect(
          () => densityService.massToVolume(
            mass: 500.0,
            massUnit: CulinaryUnit.gram,
            ingredientKey: 'insumo_sin_densidad_123',
          ),
          throwsA(isA<CrossDimensionConversionException>()),
        );
      });
    });

    group('BR-DEN-01 & BR-DEN-04: Persistencia y Densidades Personalizadas', () {
      test('Guardar densidad personalizada (harina de almendra 112 g/taza) y recuperar de SQLite', () async {
        final almondFlour = CulinaryDensity.fromGramsPerCup(
          id: 'density_harina_almendra',
          key: 'harina_almendra',
          displayName: 'Harina de Almendra Fina',
          category: 'Harinas y Secos',
          gramsPerCup: PreciseDecimal.fromString('112.0000'),
          isStandard: false,
        );

        await densityRepo.saveDensity(almondFlour);

        final retrieved = await densityRepo.getDensityByKey('harina_almendra');
        expect(retrieved, isNotNull);
        expect(retrieved!.displayName, 'Harina de Almendra Fina');
        expect(retrieved.gramsPerCup.toStringAsFixed(1), '112.0');
        expect(retrieved.isStandard, isFalse);

        // Conversión usando la entidad guardada
        final grams = densityService.volumeToMass(
          volume: 2.0,
          volumeUnit: CulinaryUnit.cup,
          densityEntity: retrieved,
        );
        expect(grams.toStringAsFixed(1), '224.0');
      });

      test('CulinaryDensityModel toMap y fromMap round-trip', () {
        final now = DateTime.now();
        final model = CulinaryDensityModel(
          id: 'test-1',
          key: 'azucar_mascabado',
          displayName: 'Azúcar Mascabado',
          category: 'Azúcares',
          gramsPerCup: PreciseDecimal.fromString('210.0000'),
          densityGPerMl: PreciseDecimal.fromString('0.875000'),
          isStandard: false,
          updatedAt: now,
        );

        final map = model.toMap();
        final reconstructed = CulinaryDensityModel.fromMap(map);

        expect(reconstructed.id, model.id);
        expect(reconstructed.key, model.key);
        expect(reconstructed.gramsPerCup, model.gramsPerCup);
        expect(reconstructed.densityGPerMl, model.densityGPerMl);
      });
    });

    group('Integración en UI (IngredientFormScreen con Preajustes y Densidad)', () {
      testWidgets('Renders density section without overflow on compact 360x640 mobile', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<CatalogBloc>(
              create: (_) => CatalogBloc(
                ingredientRepository: FakeIngredientRepository(),
                packagingRepository: FakePackagingRepository(),
              ),
              child: const IngredientFormScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to density section in the scrollable view
        final densityTitle = find.text('Matriz de Densidad Culinaria (Volumen a Peso)');
        await tester.scrollUntilVisible(
          densityTitle,
          200.0,
          scrollable: find.byType(Scrollable).first,
        );

        expect(densityTitle, findsOneWidget);
        expect(find.byKey(const Key('density_preset_dropdown')), findsOneWidget);

        // Verify no RenderFlex overflow
        expect(tester.takeException(), isNull);
      });

      testWidgets('Entering density saves into ingredient properly', (tester) async {
        final fakeRepo = FakeIngredientRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<CatalogBloc>(
              create: (_) => CatalogBloc(
                ingredientRepository: fakeRepo,
                packagingRepository: FakePackagingRepository(),
              ),
              child: const IngredientFormScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fill required form fields
        await tester.enterText(find.byType(TextFormField).at(0), 'Harina Especial');
        await tester.enterText(find.byType(TextFormField).at(1), '5');
        await tester.enterText(find.byType(TextFormField).at(2), '15.00');

        // Scroll to density field and enter density
        final densityInput = find.widgetWithText(TextFormField, 'Densidad del Insumo (g/ml)');
        await tester.scrollUntilVisible(
          densityInput,
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(densityInput, '0.5208');
        await tester.pumpAndSettle();

        // Save
        final saveBtn = find.byKey(const Key('btn_save_ingredient'));
        await tester.scrollUntilVisible(
          saveBtn,
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.savedIngredients.length, 1);
        final saved = fakeRepo.savedIngredients.first;
        expect(saved.name, 'Harina Especial');
        expect(saved.densityGPerMl, isNotNull);
        expect(saved.densityGPerMl!.toStringAsFixed(4), '0.5208');
      });
    });
  });
}


class FakeIngredientRepository implements IngredientRepository {
  final List<Ingredient> savedIngredients = [];

  @override
  Future<List<Ingredient>> getAllIngredients() async => savedIngredients;

  @override
  Future<Ingredient?> getIngredientById(String id) async => null;

  @override
  Future<List<Ingredient>> searchIngredients(String query, {String? category}) async => [];

  @override
  Future<void> saveIngredient(Ingredient ingredient) async {
    savedIngredients.add(ingredient);
  }

  @override
  Future<void> deleteIngredient(String id, {bool force = false}) async {}

  @override
  Future<List<String>> getRecipesUsingIngredient(String ingredientId) async => [];
}

class FakePackagingRepository implements PackagingRepository {
  @override
  Future<List<Packaging>> getAllPackaging() async => [];

  @override
  Future<Packaging?> getPackagingById(String id) async => null;

  @override
  Future<List<Packaging>> searchPackaging(String query, {String? category}) async => [];

  @override
  Future<void> savePackaging(Packaging packaging) async {}

  @override
  Future<void> deletePackaging(String id, {bool force = false}) async {}

  @override
  Future<List<String>> getRecipesUsingPackaging(String packagingId) async => [];
}
