import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_tables.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/ingredient_model.dart';

abstract class IngredientLocalDataSource {
  Future<List<IngredientModel>> getAll();
  Future<IngredientModel?> getById(String id);
  Future<List<IngredientModel>> search(String query, {String? category});
  Future<void> save(IngredientModel model);
  Future<void> delete(String id, {bool force = false});
  Future<List<String>> getUsageInRecipes(String ingredientId);
}

class IngredientLocalDataSourceImpl implements IngredientLocalDataSource {
  final AppDatabase appDatabase;

  IngredientLocalDataSourceImpl({AppDatabase? database})
      : appDatabase = database ?? AppDatabase.instance;

  @override
  Future<List<IngredientModel>> getAll() async {
    final db = await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableInsumo,
      orderBy: 'nombre COLLATE NOCASE ASC',
    );
    return results.map(IngredientModel.fromMap).toList();
  }

  @override
  Future<IngredientModel?> getById(String id) async {
    final db = await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableInsumo,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return IngredientModel.fromMap(results.first);
  }

  @override
  Future<List<IngredientModel>> search(String query, {String? category}) async {
    final db = await appDatabase.database;
    String whereClause = 'nombre LIKE ?';
    List<dynamic> whereArgs = ['%$query%'];

    if (category != null && category.isNotEmpty) {
      whereClause += ' AND categoria = ?';
      whereArgs.add(category);
    }

    final results = await db.query(
      DatabaseTables.tableInsumo,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'nombre COLLATE NOCASE ASC',
    );
    return results.map(IngredientModel.fromMap).toList();
  }

  @override
  Future<void> save(IngredientModel model) async {
    final db = await appDatabase.database;
    await db.insert(
      DatabaseTables.tableInsumo,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<String>> getUsageInRecipes(String ingredientId) async {
    final db = await appDatabase.database;
    final query = '''
      SELECT DISTINCT r.nombre 
      FROM ${DatabaseTables.tableRecetaInsumo} ri
      INNER JOIN ${DatabaseTables.tableReceta} r ON ri.receta_id = r.id
      WHERE ri.insumo_id = ?
    ''';
    final results = await db.rawQuery(query, [ingredientId]);
    return results.map((row) => row['nombre'] as String).toList();
  }

  @override
  Future<void> delete(String id, {bool force = false}) async {
    final db = await appDatabase.database;

    // Protective dependency check (JEF-17)
    final affectedRecipes = await getUsageInRecipes(id);
    if (affectedRecipes.isNotEmpty && !force) {
      throw DependencyConstraintException(
        'El insumo no puede eliminarse porque está siendo utilizado en recetas activas.',
        affectedRecipeNames: affectedRecipes,
      );
    }

    await appDatabase.runTransaction((txn) async {
      if (force && affectedRecipes.isNotEmpty) {
        // Mark affected recipes as incomplete requiring review (JEF-18)
        final updateQuery = '''
          UPDATE ${DatabaseTables.tableReceta}
          SET estado = ?, fecha_actualizacion = ?
          WHERE id IN (
            SELECT receta_id FROM ${DatabaseTables.tableRecetaInsumo} WHERE insumo_id = ?
          )
        ''';
        await txn.rawUpdate(updateQuery, [
          AppConstants.recipeStatusIncomplete,
          DateTime.now().toIso8601String(),
          id,
        ]);

        // Remove recipe-ingredient relations safely
        await txn.delete(
          DatabaseTables.tableRecetaInsumo,
          where: 'insumo_id = ?',
          whereArgs: [id],
        );
      }

      await txn.delete(
        DatabaseTables.tableInsumo,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
