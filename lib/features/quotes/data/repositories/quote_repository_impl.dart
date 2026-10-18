import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_tables.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/quote_item.dart';
import '../../domain/repositories/quote_repository.dart';

class QuoteRepositoryImpl implements QuoteRepository {
  final AppDatabase appDatabase;

  QuoteRepositoryImpl({AppDatabase? database})
      : appDatabase = database ?? AppDatabase.instance;

  @override
  Future<List<Quote>> getAllQuotes() async {
    final db = await appDatabase.database;
    final quoteRows = await db.query(
      DatabaseTables.tableCotizacion,
      orderBy: 'fecha_entrega ASC, fecha_creacion DESC',
    );

    if (quoteRows.isEmpty) return [];

    final itemRows = await db.query(
      DatabaseTables.tableCotizacionItem,
      orderBy: 'rowid ASC',
    );

    final itemsByQuoteId = <String, List<QuoteItem>>{};
    for (final row in itemRows) {
      final qId = row['cotizacion_id'] as String;
      itemsByQuoteId.putIfAbsent(qId, () => []).add(QuoteItem.fromMap(row));
    }

    return quoteRows.map((row) {
      final qId = row['id'] as String;
      return Quote.fromMap(row, items: itemsByQuoteId[qId] ?? const []);
    }).toList();
  }

  @override
  Future<Quote?> getQuoteById(String id) async {
    final db = await appDatabase.database;
    final quoteRows = await db.query(
      DatabaseTables.tableCotizacion,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (quoteRows.isEmpty) return null;

    final itemRows = await db.query(
      DatabaseTables.tableCotizacionItem,
      where: 'cotizacion_id = ?',
      whereArgs: [id],
      orderBy: 'rowid ASC',
    );

    final items = itemRows.map((r) => QuoteItem.fromMap(r)).toList();
    return Quote.fromMap(quoteRows.first, items: items);
  }

  @override
  Future<void> saveQuote(Quote quote) async {
    final db = await appDatabase.database;
    await db.transaction((txn) async {
      await txn.insert(
        DatabaseTables.tableCotizacion,
        quote.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        DatabaseTables.tableCotizacionItem,
        where: 'cotizacion_id = ?',
        whereArgs: [quote.id],
      );

      final batch = txn.batch();
      for (final item in quote.items) {
        batch.insert(
          DatabaseTables.tableCotizacionItem,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> deleteQuote(String id) async {
    final db = await appDatabase.database;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseTables.tableCotizacionItem,
        where: 'cotizacion_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        DatabaseTables.tableCotizacion,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  @override
  Future<void> updateQuoteStatus(String id, QuoteStatus newStatus) async {
    final db = await appDatabase.database;
    await db.update(
      DatabaseTables.tableCotizacion,
      {
        'estado': newStatus.code,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Quote>> searchQuotes(String query, {QuoteStatus? status}) async {
    final all = await getAllQuotes();
    final lowerQ = query.trim().toLowerCase();

    return all.where((q) {
      final matchesStatus = status == null || q.status == status;
      if (!matchesStatus) return false;

      if (lowerQ.isEmpty) return true;

      final matchesClient = q.clientName.toLowerCase().contains(lowerQ);
      final matchesPhone = q.clientPhone?.toLowerCase().contains(lowerQ) ?? false;
      final matchesNotes = q.eventNotes?.toLowerCase().contains(lowerQ) ?? false;
      final matchesItems = q.items.any((i) => i.concept.toLowerCase().contains(lowerQ));

      return matchesClient || matchesPhone || matchesNotes || matchesItems;
    }).toList();
  }
}
