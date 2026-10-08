import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_tables.dart';
import '../models/recipe_item_model.dart';
import '../models/recipe_model.dart';

abstract class RecipeLocalDataSource {
  Future<List<RecipeModel>> getAll();
  Future<RecipeModel?> getById(String id);
  Future<List<RecipeModel>> search(String query, {String? status});
  Future<void> save(RecipeModel model);
  Future<void> delete(String id);
  Future<void> updateStatus(String recipeId, String newStatus);
}

class RecipeLocalDataSourceImpl implements RecipeLocalDataSource {
  final AppDatabase appDatabase;

  RecipeLocalDataSourceImpl({AppDatabase? database})
      : appDatabase = database ?? AppDatabase.instance;

  @override
  Future<List<RecipeModel>> getAll() async {
    final db = await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableReceta,
      orderBy: 'nombre COLLATE NOCASE ASC',
    );

    final recipes = <RecipeModel>[];
    for (final map in results) {
      final recipeId = map['id'] as String;
      final ingredients = await _getIngredientsForRecipe(db, recipeId);
      final packaging = await _getPackagingForRecipe(db, recipeId);
      recipes.add(RecipeModel.fromMap(
        map,
        ingredients: ingredients,
        packaging: packaging,
      ));
    }
    return recipes;
  }

  @override
  Future<RecipeModel?> getById(String id) async {
    final db = await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableReceta,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;

    final ingredients = await _getIngredientsForRecipe(db, id);
    final packaging = await _getPackagingForRecipe(db, id);

    return RecipeModel.fromMap(
      results.first,
      ingredients: ingredients,
      packaging: packaging,
    );
  }

  @override
  Future<List<RecipeModel>> search(String query, {String? status}) async {
    final db = await appDatabase.database;
    String whereClause = 'nombre LIKE ?';
    List<dynamic> whereArgs = ['%$query%'];

    if (status != null && status.isNotEmpty) {
      whereClause += ' AND estado = ?';
      whereArgs.add(status);
    }

    final results = await db.query(
      DatabaseTables.tableReceta,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'nombre COLLATE NOCASE ASC',
    );

    final recipes = <RecipeModel>[];
    for (final map in results) {
      final recipeId = map['id'] as String;
      final ingredients = await _getIngredientsForRecipe(db, recipeId);
      final packaging = await _getPackagingForRecipe(db, recipeId);
      recipes.add(RecipeModel.fromMap(
        map,
        ingredients: ingredients,
        packaging: packaging,
      ));
    }
    return recipes;
  }

  @override
  Future<void> save(RecipeModel model) async {
    // Transactional atomic write for recipe and all associated recipe items
    await appDatabase.runTransaction((txn) async {
      await txn.insert(
        DatabaseTables.tableReceta,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Clean existing item relationships for this recipe
      await txn.delete(
        DatabaseTables.tableRecetaInsumo,
        where: 'receta_id = ?',
        whereArgs: [model.id],
      );
      await txn.delete(
        DatabaseTables.tableRecetaEmpaque,
        where: 'receta_id = ?',
        whereArgs: [model.id],
      );

      // Re-insert current ingredients
      for (final item in model.ingredients) {
        final itemModel = item is RecipeIngredientItemModel
            ? item
            : RecipeIngredientItemModel.fromEntity(item);
        await txn.insert(
          DatabaseTables.tableRecetaInsumo,
          itemModel.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Re-insert current packaging
      for (final pack in model.packaging) {
        final packModel = pack is RecipePackagingItemModel
            ? pack
            : RecipePackagingItemModel.fromEntity(pack);
        await txn.insert(
          DatabaseTables.tableRecetaEmpaque,
          packModel.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> delete(String id) async {
    final db = await appDatabase.database;
    await db.delete(
      DatabaseTables.tableReceta,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateStatus(String recipeId, String newStatus) async {
    final db = await appDatabase.database;
    await db.update(
      DatabaseTables.tableReceta,
      {
        'estado': newStatus,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [recipeId],
    );
  }

  Future<List<RecipeIngredientItemModel>> _getIngredientsForRecipe(
    DatabaseExecutor db,
    String recipeId,
  ) async {
    final query = '''
      SELECT ri.id, ri.receta_id, ri.insumo_id, ri.cantidad, ri.unidad, ri.notas,
             i.nombre as insumo_nombre, i.costo_unitario_minimo
      FROM ${DatabaseTables.tableRecetaInsumo} ri
      LEFT JOIN ${DatabaseTables.tableInsumo} i ON ri.insumo_id = i.id
      WHERE ri.receta_id = ?
    ''';
    final results = await db.rawQuery(query, [recipeId]);
    return results.map(RecipeIngredientItemModel.fromMap).toList();
  }

  Future<List<RecipePackagingItemModel>> _getPackagingForRecipe(
    DatabaseExecutor db,
    String recipeId,
  ) async {
    final query = '''
      SELECT re.id, re.receta_id, re.empaque_id, re.cantidad_piezas, re.notas,
             e.nombre as empaque_nombre, e.costo_unitario
      FROM ${DatabaseTables.tableRecetaEmpaque} re
      LEFT JOIN ${DatabaseTables.tableEmpaque} e ON re.empaque_id = e.id
      WHERE re.receta_id = ?
    ''';
    final results = await db.rawQuery(query, [recipeId]);
    return results.map(RecipePackagingItemModel.fromMap).toList();
  }
}
