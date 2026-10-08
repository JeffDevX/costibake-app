import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_tables.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/packaging_model.dart';

abstract class PackagingLocalDataSource {
  Future<List<PackagingModel>> getAll();
  Future<PackagingModel?> getById(String id);
  Future<List<PackagingModel>> search(String query, {String? category});
  Future<void> save(PackagingModel model);
  Future<void> delete(String id, {bool force = false});
  Future<List<String>> getUsageInRecipes(String packagingId);
}

class PackagingLocalDataSourceImpl implements PackagingLocalDataSource {
  final AppDatabase appDatabase;

  PackagingLocalDataSourceImpl({AppDatabase? database})
      : appDatabase = database ?? AppDatabase.instance;

  @override
  Future<List<PackagingModel>> getAll() async {
    final db = await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableEmpaque,
      orderBy: 'nombre COLLATE NOCASE ASC',
    );
    return results.map(PackagingModel.fromMap).toList();
  }

  @override
  Future<PackagingModel?> getById(String id) async {
    final db = await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableEmpaque,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return PackagingModel.fromMap(results.first);
  }

  @override
  Future<List<PackagingModel>> search(String query, {String? category}) async {
    final db = await appDatabase.database;
    String whereClause = 'nombre LIKE ?';
    List<dynamic> whereArgs = ['%$query%'];

    if (category != null && category.isNotEmpty) {
      whereClause += ' AND categoria = ?';
      whereArgs.add(category);
    }

    final results = await db.query(
      DatabaseTables.tableEmpaque,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'nombre COLLATE NOCASE ASC',
    );
    return results.map(PackagingModel.fromMap).toList();
  }

  @override
  Future<void> save(PackagingModel model) async {
    final db = await appDatabase.database;
    await db.insert(
      DatabaseTables.tableEmpaque,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<String>> getUsageInRecipes(String packagingId) async {
    final db = await appDatabase.database;
    final query = '''
      SELECT DISTINCT r.nombre 
      FROM ${DatabaseTables.tableRecetaEmpaque} re
      INNER JOIN ${DatabaseTables.tableReceta} r ON re.receta_id = r.id
      WHERE re.empaque_id = ?
    ''';
    final results = await db.rawQuery(query, [packagingId]);
    return results.map((row) => row['nombre'] as String).toList();
  }

  @override
  Future<void> delete(String id, {bool force = false}) async {
    final db = await appDatabase.database;

    final affectedRecipes = await getUsageInRecipes(id);
    if (affectedRecipes.isNotEmpty && !force) {
      throw DependencyConstraintException(
        'El empaque no puede eliminarse porque está siendo utilizado en recetas activas.',
        affectedRecipeNames: affectedRecipes,
      );
    }

    await appDatabase.runTransaction((txn) async {
      if (force && affectedRecipes.isNotEmpty) {
        await txn.delete(
          DatabaseTables.tableRecetaEmpaque,
          where: 'empaque_id = ?',
          whereArgs: [id],
        );
      }

      await txn.delete(
        DatabaseTables.tableEmpaque,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
