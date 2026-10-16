import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
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
      where: 'COALESCE(eliminado, 0) = 0',
      orderBy: 'nombre COLLATE NOCASE ASC',
    );
    return results.map(PackagingModel.fromMap).toList();
  }

  @override
  Future<PackagingModel?> getById(String id) async {
    final db = await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableEmpaque,
      where: 'id = ? AND COALESCE(eliminado, 0) = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return PackagingModel.fromMap(results.first);
  }

  @override
  Future<List<PackagingModel>> search(String query, {String? category}) async {
    final db = await appDatabase.database;
    String whereClause = 'COALESCE(eliminado, 0) = 0 AND nombre LIKE ?';
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
    final map = Map<String, dynamic>.from(model.toMap());
    map['eliminado'] = 0;
    await db.insert(
      DatabaseTables.tableEmpaque,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<String>> getUsageInRecipes(String packagingId) async {
    final db = await appDatabase.database;
    const query = '''
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
    final affectedRecipes = await getUsageInRecipes(id);
    if (affectedRecipes.isNotEmpty && !force) {
      throw DependencyConstraintException(
        'El empaque no puede eliminarse porque está siendo utilizado en recetas activas.',
        affectedRecipeNames: affectedRecipes,
      );
    }

    await appDatabase.runTransaction((txn) async {
      if (force && affectedRecipes.isNotEmpty) {
        final nowIso = DateTime.now().toIso8601String();

        // 1. Mark affected recipes as INCOMPLETA_REQUIERE_REVISION (RF-SYS-23, BR-FRC-02)
        const updateRecipesQuery = '''
          UPDATE ${DatabaseTables.tableReceta}
          SET estado = ?, fecha_actualizacion = ?
          WHERE id IN (
            SELECT receta_id FROM ${DatabaseTables.tableRecetaEmpaque} WHERE empaque_id = ?
          )
        ''';
        await txn.rawUpdate(updateRecipesQuery, [
          AppConstants.recipeStatusIncomplete,
          nowIso,
          id,
        ]);

        // 2. Soft-delete packaging in EMPAQUE while preserving historical reference in RECETA_EMPAQUE
        const softDeletePackagingQuery = '''
          UPDATE ${DatabaseTables.tableEmpaque}
          SET eliminado = 1,
              nombre = CASE
                WHEN nombre LIKE '%[ELIMINADO]' THEN nombre
                ELSE nombre || ' [ELIMINADO]'
              END,
              costo_unitario = '0.0000',
              fecha_actualizacion = ?
          WHERE id = ?
        ''';
        await txn.rawUpdate(softDeletePackagingQuery, [nowIso, id]);
        return;
      }

      await txn.delete(
        DatabaseTables.tableEmpaque,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
