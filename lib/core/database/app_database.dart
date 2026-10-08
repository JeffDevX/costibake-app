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
  static void setMockDatabase(Database mockDb) {
    _instance = AppDatabase._().._db = mockDb;
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migration hooks for future versions
      },
    );
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute(DatabaseTables.createTableInsumo);
    await db.execute(DatabaseTables.createTableEmpaque);
    await db.execute(DatabaseTables.createTableReceta);
    await db.execute(DatabaseTables.createTableRecetaInsumo);
    await db.execute(DatabaseTables.createTableRecetaEmpaque);
    await db.execute(DatabaseTables.createTableConfiguracionNegocio);

    for (final indexSql in DatabaseTables.createIndexes) {
      await db.execute(indexSql);
    }
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
