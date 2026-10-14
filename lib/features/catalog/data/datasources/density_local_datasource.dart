import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_tables.dart';
import '../models/culinary_density_model.dart';

abstract class DensityLocalDataSource {
  Future<List<CulinaryDensityModel>> getAll();
  Future<CulinaryDensityModel?> getByKey(String key);
  Future<void> save(CulinaryDensityModel model);
  Future<void> seedIfEmpty();
}

class DensityLocalDataSourceImpl implements DensityLocalDataSource {
  final AppDatabase appDatabase;

  DensityLocalDataSourceImpl({AppDatabase? database})
      : appDatabase = database ?? AppDatabase.instance;

  @override
  Future<List<CulinaryDensityModel>> getAll() async {
    final db = await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableMatrizDensidad,
      orderBy: 'nombre_mostrado COLLATE NOCASE ASC',
    );
    return results.map(CulinaryDensityModel.fromMap).toList();
  }

  @override
  Future<CulinaryDensityModel?> getByKey(String key) async {
    final db = await appDatabase.database;
    final normalized = key.toLowerCase().trim().replaceAll(' ', '_');
    final results = await db.query(
      DatabaseTables.tableMatrizDensidad,
      where: 'nombre_clave = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return CulinaryDensityModel.fromMap(results.first);
  }

  @override
  Future<void> save(CulinaryDensityModel model) async {
    final db = await appDatabase.database;
    await db.insert(
      DatabaseTables.tableMatrizDensidad,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> seedIfEmpty() async {
    await appDatabase.seedDensitiesIfEmpty();
  }
}
