import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/backup/domain/entities/backup_manifest.dart';
import 'package:costibake_app/features/backup/domain/entities/backup_result.dart';
import 'package:costibake_app/features/backup/domain/services/backup_service.dart';
import 'package:costibake_app/features/backup/presentation/widgets/backup_restore_card.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:costibake_app/features/quotes/domain/entities/quote.dart';
import 'package:costibake_app/features/quotes/domain/repositories/quote_repository.dart';
import 'package:costibake_app/features/quotes/presentation/bloc/quotes_bloc.dart';
import 'package:costibake_app/features/quotes/presentation/bloc/quotes_event.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_event.dart';
import 'package:costibake_app/features/settings/domain/entities/business_config.dart';
import 'package:costibake_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_event.dart';

class _FakeBackupService implements BackupService {
  bool createCalled = false;
  bool restoreCalled = false;

  final BackupManifest fakeManifest = BackupManifest(
    formatVersion: 1,
    appName: 'CostiBake',
    databaseVersion: 1,
    createdAt: DateTime(2026, 10, 18, 10, 30),
    tableCounts: const {
      'RECETA': 5,
      'INSUMO': 20,
      'EMPAQUE': 4,
      'COTIZACION': 3,
    },
    checksum: 'mock_hash_123',
  );

  @override
  Future<BackupExportResult> createBackup() async {
    createCalled = true;
    return BackupExportResult(
      fileName: 'costibake_backup_20261018_1030.cbake',
      filePath: '/tmp/costibake_backup_20261018_1030.cbake',
      bytes: Uint8List(16),
      manifest: fakeManifest,
    );
  }

  @override
  Future<BackupValidationResult> validateBackupFile(Uint8List fileBytes) async {
    return BackupValidationResult.success(fakeManifest);
  }

  @override
  Future<BackupManifest> restoreBackup(Uint8List fileBytes) async {
    restoreCalled = true;
    return fakeManifest;
  }

  @override
  Future<Map<String, int>> getDatabaseStats() async {
    return {
      'RECETA': 5,
      'INSUMO': 20,
      'COTIZACION': 3,
    };
  }
}

// Dummy Repositories
class _DummyIngRepo implements IngredientRepository {
  @override
  Future<List<Ingredient>> getAllIngredients() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyPackRepo implements PackagingRepository {
  @override
  Future<List<Packaging>> getAllPackaging() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyRecipeRepo implements RecipeRepository {
  @override
  Future<List<Recipe>> getAllRecipes() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummySettingsRepo implements SettingsRepository {
  @override
  Future<BusinessConfig> getBusinessConfig() async => BusinessConfig(
        id: 'cfg',
        businessName: 'Taller',
        currencySymbol: '\$',
        laborHourlyRate: PreciseDecimal.zero,
        overheadPercentage: PreciseDecimal.zero,
        updatedAt: DateTime.now(),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyQuoteRepo implements QuoteRepository {
  @override
  Future<List<Quote>> getAllQuotes() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test BLoCs with reload interception
class _TestCatalogBloc extends CatalogBloc {
  bool reloaded = false;
  _TestCatalogBloc()
      : super(
          ingredientRepository: _DummyIngRepo(),
          packagingRepository: _DummyPackRepo(),
        );

  @override
  void add(CatalogEvent event) {
    if (event is LoadCatalog) reloaded = true;
    super.add(event);
  }
}

class _TestRecipesBloc extends RecipesBloc {
  bool reloaded = false;
  _TestRecipesBloc() : super(recipeRepository: _DummyRecipeRepo());

  @override
  void add(RecipesEvent event) {
    if (event is LoadRecipes) reloaded = true;
    super.add(event);
  }
}

class _TestSettingsBloc extends SettingsBloc {
  bool reloaded = false;
  _TestSettingsBloc() : super(settingsRepository: _DummySettingsRepo());

  @override
  void add(SettingsEvent event) {
    if (event is LoadSettings) reloaded = true;
    super.add(event);
  }
}

class _TestQuotesBloc extends QuotesBloc {
  bool reloaded = false;
  _TestQuotesBloc() : super(quoteRepository: _DummyQuoteRepo());

  @override
  void add(QuotesEvent event) {
    if (event is LoadQuotes) reloaded = true;
    super.add(event);
  }
}

void main() {
  late _FakeBackupService fakeService;
  late _TestCatalogBloc catalogBloc;
  late _TestRecipesBloc recipesBloc;
  late _TestSettingsBloc settingsBloc;
  late _TestQuotesBloc quotesBloc;

  setUp(() {
    fakeService = _FakeBackupService();
    catalogBloc = _TestCatalogBloc();
    recipesBloc = _TestRecipesBloc();
    settingsBloc = _TestSettingsBloc();
    quotesBloc = _TestQuotesBloc();
  });

  tearDown(() {
    catalogBloc.close();
    recipesBloc.close();
    settingsBloc.close();
    quotesBloc.close();
  });

  Widget buildTestable(Widget child) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CatalogBloc>.value(value: catalogBloc),
        BlocProvider<RecipesBloc>.value(value: recipesBloc),
        BlocProvider<SettingsBloc>.value(value: settingsBloc),
        BlocProvider<QuotesBloc>.value(value: quotesBloc),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('BackupRestoreCard Widget Tests (JEF-32, BR-BCK-01..04)', () {
    testWidgets('Renders card with database stats and action buttons', (tester) async {
      await tester.pumpWidget(buildTestable(
        BackupRestoreCard(backupService: fakeService),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Copia de Seguridad y Restauración'), findsOneWidget);
      expect(find.byKey(const Key('btn_create_backup')), findsOneWidget);
      expect(find.byKey(const Key('btn_restore_backup')), findsOneWidget);

      // Verify badges loaded
      expect(find.text('5'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('Tapping create backup calls service and opens success dialog', (tester) async {
      await tester.pumpWidget(buildTestable(
        BackupRestoreCard(backupService: fakeService),
      ));
      await tester.pumpAndSettle();

      final createBtn = find.byKey(const Key('btn_create_backup'));
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(fakeService.createCalled, isTrue);
      expect(find.text('Copia Creada'), findsOneWidget);
      expect(find.text('costibake_backup_20261018_1030.cbake'), findsOneWidget);
      expect(find.byKey(const Key('btn_share_backup')), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Copia Creada'), findsNothing);
    });

    testWidgets('BR-BCK-04: Confirmation dialog triggers transactional restoration and reloads BLoCs',
        (tester) async {
      await tester.pumpWidget(buildTestable(
        BackupRestoreCard(backupService: fakeService),
      ));
      await tester.pumpAndSettle();

      // Trigger the restore flow directly on state
      final dynamic cardState = tester.state(find.byType(BackupRestoreCard));
      cardState.callRestoreForTest(Uint8List(16), fakeService.fakeManifest);
      await tester.pumpAndSettle();

      // Verify confirmation dialog (BR-BCK-04)
      expect(find.text('Confirmar Restauración'), findsOneWidget);
      expect(
        find.textContaining('Esta acción reemplazará toda la base de datos actual'),
        findsOneWidget,
      );

      // Confirm restoration
      final confirmBtn = find.byKey(const Key('btn_confirm_restore_db'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(fakeService.restoreCalled, isTrue);
      expect(catalogBloc.reloaded, isTrue);
      expect(recipesBloc.reloaded, isTrue);
      expect(settingsBloc.reloaded, isTrue);
      expect(quotesBloc.reloaded, isTrue);
      expect(find.textContaining('¡Base de datos restaurada con éxito!'), findsOneWidget);
    });
  });
}
