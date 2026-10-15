import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_tables.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../models/recipe_item_model.dart';
import '../models/recipe_model.dart';

abstract class RecipeLocalDataSource {
  Future<List<RecipeModel>> getAll({DatabaseExecutor? executor});
  Future<RecipeModel?> getById(String id, {DatabaseExecutor? executor});
  Future<Map<String, RecipeModel>> getByIds(List<String> ids, {DatabaseExecutor? executor});
  Future<List<RecipeModel>> search(String query, {String? status});
  Future<void> save(RecipeModel model);
  Future<void> delete(String id);
  Future<void> updateStatus(String recipeId, String newStatus);
  Future<Map<String, List<String>>> getSubRecipeDependencyGraph({DatabaseExecutor? executor});
  Future<Map<String, List<String>>> getRecipeIngredientGraph({DatabaseExecutor? executor});
  Future<Map<String, List<String>>> getRecipePackagingGraph({DatabaseExecutor? executor});
  Future<void> updateTimestamps(List<String> recipeIds, DateTime timestamp, {DatabaseExecutor? executor});
}

class RecipeLocalDataSourceImpl implements RecipeLocalDataSource {
  final AppDatabase appDatabase;

  RecipeLocalDataSourceImpl({AppDatabase? database})
      : appDatabase = database ?? AppDatabase.instance;

  @override
  Future<Map<String, List<String>>> getRecipeIngredientGraph({DatabaseExecutor? executor}) async {
    final db = executor ?? await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableRecetaInsumo,
      columns: ['receta_id', 'insumo_id'],
    );
    final graph = <String, List<String>>{};
    for (final row in results) {
      final recipeId = row['receta_id'] as String;
      final ingredientId = row['insumo_id'] as String;
      graph.putIfAbsent(recipeId, () => []).add(ingredientId);
    }
    return graph;
  }

  @override
  Future<Map<String, List<String>>> getRecipePackagingGraph({DatabaseExecutor? executor}) async {
    final db = executor ?? await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableRecetaEmpaque,
      columns: ['receta_id', 'empaque_id'],
    );
    final graph = <String, List<String>>{};
    for (final row in results) {
      final recipeId = row['receta_id'] as String;
      final packagingId = row['empaque_id'] as String;
      graph.putIfAbsent(recipeId, () => []).add(packagingId);
    }
    return graph;
  }

  @override
  Future<void> updateTimestamps(
    List<String> recipeIds,
    DateTime timestamp, {
    DatabaseExecutor? executor,
  }) async {
    if (recipeIds.isEmpty) return;
    final db = executor ?? await appDatabase.database;
    final iso = timestamp.toIso8601String();
    final placeholders = List.filled(recipeIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE ${DatabaseTables.tableReceta} SET fecha_actualizacion = ? WHERE id IN ($placeholders)',
      [iso, ...recipeIds],
    );
  }

  @override
  Future<Map<String, List<String>>> getSubRecipeDependencyGraph({DatabaseExecutor? executor}) async {
    final db = executor ?? await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableRecetaSubreceta,
      columns: ['receta_padre_id', 'receta_hija_id'],
    );
    final graph = <String, List<String>>{};
    for (final row in results) {
      final parent = row['receta_padre_id'] as String;
      final child = row['receta_hija_id'] as String;
      graph.putIfAbsent(parent, () => []).add(child);
    }
    return graph;
  }

  @override
  Future<List<RecipeModel>> getAll({DatabaseExecutor? executor}) async {
    final db = executor ?? await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableReceta,
      orderBy: 'nombre COLLATE NOCASE ASC',
    );

    final recipes = <RecipeModel>[];
    for (final map in results) {
      final recipeId = map['id'] as String;
      final ingredients = await _getIngredientsForRecipe(db, recipeId);
      final subRecipes = await _getSubRecipesForRecipe(db, recipeId);
      final packaging = await _getPackagingForRecipe(db, recipeId);
      recipes.add(RecipeModel.fromMap(
        map,
        ingredients: ingredients,
        subRecipes: subRecipes,
        packaging: packaging,
      ));
    }
    return recipes;
  }

  @override
  Future<RecipeModel?> getById(String id, {DatabaseExecutor? executor}) async {
    final db = executor ?? await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableReceta,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;

    final ingredients = await _getIngredientsForRecipe(db, id);
    final subRecipes = await _getSubRecipesForRecipe(db, id);
    final packaging = await _getPackagingForRecipe(db, id);

    return RecipeModel.fromMap(
      results.first,
      ingredients: ingredients,
      subRecipes: subRecipes,
      packaging: packaging,
    );
  }

  @override
  Future<Map<String, RecipeModel>> getByIds(
    List<String> ids, {
    DatabaseExecutor? executor,
  }) async {
    if (ids.isEmpty) return const {};
    final db = executor ?? await appDatabase.database;
    final placeholders = List.filled(ids.length, '?').join(',');

    final recipeRows = await db.query(
      DatabaseTables.tableReceta,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    final ingQuery = '''
      SELECT ri.id, ri.receta_id, ri.insumo_id, ri.cantidad, ri.unidad, ri.seccion, ri.notas,
             i.nombre as insumo_nombre, i.costo_unitario_minimo, i.densidad_g_ml, i.unidad_minima
      FROM ${DatabaseTables.tableRecetaInsumo} ri
      LEFT JOIN ${DatabaseTables.tableInsumo} i ON ri.insumo_id = i.id
      WHERE ri.receta_id IN ($placeholders)
    ''';
    final ingRows = await db.rawQuery(ingQuery, ids);
    final ingByRecipe = <String, List<RecipeIngredientItemModel>>{};
    for (final row in ingRows) {
      final rId = row['receta_id'] as String;
      ingByRecipe.putIfAbsent(rId, () => []).add(RecipeIngredientItemModel.fromMap(row));
    }

    final packQuery = '''
      SELECT re.id, re.receta_id, re.empaque_id, re.cantidad_piezas, re.notas,
             e.nombre as empaque_nombre, e.costo_unitario
      FROM ${DatabaseTables.tableRecetaEmpaque} re
      LEFT JOIN ${DatabaseTables.tableEmpaque} e ON re.empaque_id = e.id
      WHERE re.receta_id IN ($placeholders)
    ''';
    final packRows = await db.rawQuery(packQuery, ids);
    final packByRecipe = <String, List<RecipePackagingItemModel>>{};
    for (final row in packRows) {
      final rId = row['receta_id'] as String;
      packByRecipe.putIfAbsent(rId, () => []).add(RecipePackagingItemModel.fromMap(row));
    }

    final subQuery = '''
      SELECT rs.id, rs.receta_padre_id, rs.receta_hija_id, rs.cantidad_factor, rs.seccion, rs.notas,
             rh.nombre as receta_hija_nombre
      FROM ${DatabaseTables.tableRecetaSubreceta} rs
      LEFT JOIN ${DatabaseTables.tableReceta} rh ON rs.receta_hija_id = rh.id
      WHERE rs.receta_padre_id IN ($placeholders)
    ''';
    final subRows = await db.rawQuery(subQuery, ids);
    final subByRecipe = <String, List<RecipeSubRecipeItemModel>>{};
    for (final row in subRows) {
      final pId = row['receta_padre_id'] as String;
      subByRecipe.putIfAbsent(pId, () => []).add(RecipeSubRecipeItemModel.fromMap(row));
    }

    final resultMap = <String, RecipeModel>{};
    for (final row in recipeRows) {
      final rId = row['id'] as String;
      resultMap[rId] = RecipeModel.fromMap(
        row,
        ingredients: ingByRecipe[rId] ?? const [],
        packaging: packByRecipe[rId] ?? const [],
        subRecipes: subByRecipe[rId] ?? const [],
      );
    }
    return resultMap;
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
      final subRecipes = await _getSubRecipesForRecipe(db, recipeId);
      final packaging = await _getPackagingForRecipe(db, recipeId);
      recipes.add(RecipeModel.fromMap(
        map,
        ingredients: ingredients,
        subRecipes: subRecipes,
        packaging: packaging,
      ));
    }
    return recipes;
  }

  @override
  Future<void> save(RecipeModel model) async {
    // Transactional atomic write for recipe and all associated recipe items (RF-SYS-09)
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
        DatabaseTables.tableRecetaSubreceta,
        where: 'receta_padre_id = ?',
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

      // Re-insert modular sub-recipes (RF-SYS-10)
      for (final sub in model.subRecipes) {
        final subModel = sub is RecipeSubRecipeItemModel
            ? sub
            : RecipeSubRecipeItemModel.fromEntity(sub);
        await txn.insert(
          DatabaseTables.tableRecetaSubreceta,
          subModel.toMap(),
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

  Future<PreciseDecimal> _calculateRecipeDirectCost(
    DatabaseExecutor db,
    String recipeId, [
    Set<String>? visited,
  ]) async {
    final v = visited ?? <String>{};
    if (!v.add(recipeId)) return PreciseDecimal.zero;

    final ingredients = await _getIngredientsForRecipe(db, recipeId);
    final packaging = await _getPackagingForRecipe(db, recipeId);

    PreciseDecimal total = PreciseDecimal.zero;
    for (final ing in ingredients) {
      total += ing.calculateItemCost();
    }
    for (final pack in packaging) {
      total += pack.calculateItemCost();
    }

    const subQuery = '''
      SELECT receta_hija_id, cantidad_factor
      FROM ${DatabaseTables.tableRecetaSubreceta}
      WHERE receta_padre_id = ?
    ''';
    final subResults = await db.rawQuery(subQuery, [recipeId]);
    for (final subRow in subResults) {
      final childId = subRow['receta_hija_id'] as String;
      final factor =
          PreciseDecimal.fromString(subRow['cantidad_factor'] as String);
      final childCost = await _calculateRecipeDirectCost(db, childId, v);
      total += childCost * factor;
    }

    v.remove(recipeId);
    return total;
  }

  Future<List<RecipeIngredientItemModel>> _getIngredientsForRecipe(
    DatabaseExecutor db,
    String recipeId,
  ) async {
    const query = '''
      SELECT ri.id, ri.receta_id, ri.insumo_id, ri.cantidad, ri.unidad, ri.seccion, ri.notas,
             i.nombre as insumo_nombre, i.costo_unitario_minimo, i.densidad_g_ml, i.unidad_minima
      FROM ${DatabaseTables.tableRecetaInsumo} ri
      LEFT JOIN ${DatabaseTables.tableInsumo} i ON ri.insumo_id = i.id
      WHERE ri.receta_id = ?
    ''';
    final results = await db.rawQuery(query, [recipeId]);
    return results.map(RecipeIngredientItemModel.fromMap).toList();
  }

  Future<List<RecipeSubRecipeItemModel>> _getSubRecipesForRecipe(
    DatabaseExecutor db,
    String recipeId,
  ) async {
    const query = '''
      SELECT rs.id, rs.receta_padre_id, rs.receta_hija_id, rs.cantidad_factor, rs.seccion, rs.notas,
             rh.nombre as receta_hija_nombre
      FROM ${DatabaseTables.tableRecetaSubreceta} rs
      LEFT JOIN ${DatabaseTables.tableReceta} rh ON rs.receta_hija_id = rh.id
      WHERE rs.receta_padre_id = ?
    ''';
    final results = await db.rawQuery(query, [recipeId]);
    final subRecipes = <RecipeSubRecipeItemModel>[];
    for (final row in results) {
      final childId = row['receta_hija_id'] as String;
      final childTotalCost = await _calculateRecipeDirectCost(db, childId);

      final map = Map<String, dynamic>.from(row);
      map['costo_total_hija'] = childTotalCost.toStringAsFixed(4);
      subRecipes.add(RecipeSubRecipeItemModel.fromMap(map));
    }
    return subRecipes;
  }

  Future<List<RecipePackagingItemModel>> _getPackagingForRecipe(
    DatabaseExecutor db,
    String recipeId,
  ) async {
    const query = '''
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
