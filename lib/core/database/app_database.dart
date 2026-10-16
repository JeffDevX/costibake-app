import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import 'database_tables.dart';

/// Database client managing the offline-first SQLite instance with full ACID transaction support.
class AppDatabase {
  static AppDatabase? _instance;
  Database? _db;

  AppDatabase._();

  static AppDatabase get instance => _instance ??= AppDatabase._();

  /// For testing: allows overriding the underlying database instance (e.g., in-memory test database)
  static void setMockDatabase(Database? mockDb) {
    if (mockDb == null) {
      _instance = AppDatabase._();
    } else {
      _instance = AppDatabase._().._db = mockDb;
    }
  }

  /// Opens a fresh isolated in-memory SQLite database with the full schema and
  /// default seed data, and registers it as the active `AppDatabase.instance`.
  static Future<Database> openInMemoryTestDatabase() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: AppConstants.databaseVersion,
      singleInstance: false,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _insertDefaultConfiguration(db);
        await _seedDefaultDensities(db);
      },
    );
    setMockDatabase(db);
    return db;
  }

  /// Get the active database instance, initializing it if necessary.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onConfigure: (db) async {
        // Enforce SQLite Foreign Key constraints for referential integrity
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _insertDefaultConfiguration(db);
        await _seedDefaultDensities(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migration hooks for future versions
        await _createSchema(db);
        await _seedDefaultDensities(db);
      },
      onOpen: (db) async {
        await _createSchema(db);
      },
    );
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute(DatabaseTables.createTableInsumo);
    await db.execute(DatabaseTables.createTableEmpaque);
    await db.execute(DatabaseTables.createTableReceta);
    await db.execute(DatabaseTables.createTableRecetaInsumo);
    await db.execute(DatabaseTables.createTableRecetaSubreceta);
    await db.execute(DatabaseTables.createTableRecetaEmpaque);
    await db.execute(DatabaseTables.createTableConfiguracionNegocio);
    await db.execute(DatabaseTables.createTableMatrizDensidad);

    for (final indexSql in DatabaseTables.createIndexes) {
      await db.execute(indexSql);
    }

    try {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.tableReceta} ADD COLUMN tarifa_mano_obra_hora TEXT;',
      );
    } catch (_) {}

    try {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.tableReceta} ADD COLUMN porcentaje_overhead TEXT;',
      );
    } catch (_) {}

    try {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.tableReceta} ADD COLUMN modo_fijacion_precio TEXT DEFAULT "MARKUP_SOBRE_COSTO";',
      );
    } catch (_) {}

    try {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.tableReceta} ADD COLUMN regla_redondeo TEXT DEFAULT "NINGUNO";',
      );
    } catch (_) {}

    try {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.tableReceta} ADD COLUMN precio_venta_manual_lote TEXT;',
      );
    } catch (_) {}

    try {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.tableReceta} ADD COLUMN precio_venta_manual_porcion TEXT;',
      );
    } catch (_) {}

    try {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.tableInsumo} ADD COLUMN eliminado INTEGER NOT NULL DEFAULT 0;',
      );
    } catch (_) {}

    try {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.tableEmpaque} ADD COLUMN eliminado INTEGER NOT NULL DEFAULT 0;',
      );
    } catch (_) {}
  }

  static Future<void> _insertDefaultConfiguration(DatabaseExecutor db) async {
    await db.insert(
      DatabaseTables.tableConfiguracionNegocio,
      {
        'id': 'default_business_config',
        'nombre_negocio': 'Mi Taller de Repostería',
        'moneda_simbolo': AppConstants.defaultCurrencySymbol,
        'tarifa_hora_mano_obra':
            AppConstants.defaultLaborRatePerHour.toStringAsFixed(4),
        'porcentaje_overhead_indirectos':
            AppConstants.defaultOverheadPercentage.toStringAsFixed(4),
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Default seed entries for pastry density matrix conforming to BR-DEN-02.
  static final List<Map<String, dynamic>> defaultCulinaryDensities = [
    {
      'id': 'density_harina_trigo',
      'nombre_clave': 'harina_trigo',
      'nombre_mostrado': 'Harina de trigo todo uso',
      'categoria': 'Harinas y Secos',
      'gramos_por_taza': '125.0000',
      'densidad_g_ml': (125.0 / 240.0).toStringAsFixed(6), // ~0.520833
      'es_estandar': 1,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    },
    {
      'id': 'density_azucar_blanca',
      'nombre_clave': 'azucar_blanca',
      'nombre_mostrado': 'Azúcar refinada / blanca',
      'categoria': 'Azúcares y Endulzantes',
      'gramos_por_taza': '200.0000',
      'densidad_g_ml': (200.0 / 240.0).toStringAsFixed(6), // ~0.833333
      'es_estandar': 1,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    },
    {
      'id': 'density_azucar_glass',
      'nombre_clave': 'azucar_glass',
      'nombre_mostrado': 'Azúcar glass / impalpable',
      'categoria': 'Azúcares y Endulzantes',
      'gramos_por_taza': '120.0000',
      'densidad_g_ml': (120.0 / 240.0).toStringAsFixed(6), // 0.500000
      'es_estandar': 1,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    },
    {
      'id': 'density_mantequilla',
      'nombre_clave': 'mantequilla',
      'nombre_mostrado': 'Mantequilla',
      'categoria': 'Grasas y Mantequillas',
      'gramos_por_taza': '227.0000',
      'densidad_g_ml': (227.0 / 240.0).toStringAsFixed(6), // ~0.945833
      'es_estandar': 1,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    },
    {
      'id': 'density_aceite_vegetal',
      'nombre_clave': 'aceite_vegetal',
      'nombre_mostrado': 'Aceite vegetal',
      'categoria': 'Grasas y Mantequillas',
      'gramos_por_taza': '218.0000',
      'densidad_g_ml': (218.0 / 240.0).toStringAsFixed(6), // ~0.908333
      'es_estandar': 1,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    },
    {
      'id': 'density_miel',
      'nombre_clave': 'miel',
      'nombre_mostrado': 'Miel de abeja / jarabe de maíz',
      'categoria': 'Azúcares y Endulzantes',
      'gramos_por_taza': '340.0000',
      'densidad_g_ml': (340.0 / 240.0).toStringAsFixed(6), // ~1.416667
      'es_estandar': 1,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    },
    {
      'id': 'density_cacao_polvo',
      'nombre_clave': 'cacao_polvo',
      'nombre_mostrado': 'Cacao en polvo',
      'categoria': 'Chocolates y Cacao',
      'gramos_por_taza': '100.0000',
      'densidad_g_ml': (100.0 / 240.0).toStringAsFixed(6), // ~0.416667
      'es_estandar': 1,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    },
    {
      'id': 'density_leche_entera',
      'nombre_clave': 'leche_entera',
      'nombre_mostrado': 'Leche entera',
      'categoria': 'Lácteos y Huevos',
      'gramos_por_taza': '245.0000',
      'densidad_g_ml': (245.0 / 240.0).toStringAsFixed(6), // ~1.020833
      'es_estandar': 1,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    },
    {
      'id': 'density_agua_pura',
      'nombre_clave': 'agua_pura',
      'nombre_mostrado': 'Agua pura',
      'categoria': 'Otros',
      'gramos_por_taza': '240.0000',
      'densidad_g_ml': '1.000000',
      'es_estandar': 1,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    },
  ];

  static Future<void> _seedDefaultDensities(DatabaseExecutor db) async {
    for (final item in defaultCulinaryDensities) {
      await db.insert(
        DatabaseTables.tableMatrizDensidad,
        item,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Public seed helper to ensure densities table is populated.
  Future<void> seedDensitiesIfEmpty() async {
    final db = await database;
    await _createSchema(db);
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.tableMatrizDensidad}'),
    );
    if (count == null || count == 0) {
      await _seedDefaultDensities(db);
    }
  }


  /// Executes an operation within an ACID transaction.
  Future<T> runTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction<T>(action);
  }

  /// Close database connection
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
