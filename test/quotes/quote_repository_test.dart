import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:costibake_app/core/database/app_database.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/quotes/data/repositories/quote_repository_impl.dart';
import 'package:costibake_app/features/quotes/domain/entities/quote.dart';
import 'package:costibake_app/features/quotes/domain/entities/quote_item.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late QuoteRepositoryImpl quoteRepo;

  setUp(() async {
    await AppDatabase.openInMemoryTestDatabase();
    quoteRepo = QuoteRepositoryImpl();
  });

  group('QuoteRepositoryImpl SQLite ACID Integration Tests (JEF-31)', () {
    test('Saves a quote with items and retrieves it with full relational structure', () async {
      final item1 = QuoteItem(
        id: 'item-101',
        quoteId: 'quote-test-1',
        concept: 'Pastel Zanahoria 22cm',
        type: QuoteItemType.recipe,
        quantity: PreciseDecimal.fromString('1.0'),
        unitPrice: PreciseDecimal.fromString('38.00'),
        notes: 'Con nuez picada',
      );

      final item2 = QuoteItem(
        id: 'item-102',
        quoteId: 'quote-test-1',
        concept: 'Caja Regalo y Moño',
        type: QuoteItemType.custom,
        quantity: PreciseDecimal.fromString('1.0'),
        unitPrice: PreciseDecimal.fromString('5.00'),
      );

      final quote = Quote(
        id: 'quote-test-1',
        clientName: 'Alejandro Morales',
        clientPhone: '5544332211',
        eventNotes: 'Entrega a las 3pm',
        deliveryDate: DateTime(2026, 12, 10, 15, 0),
        discount: PreciseDecimal.fromString('3.00'),
        depositAmount: PreciseDecimal.fromString('20.00'),
        status: QuoteStatus.pending,
        items: [item1, item2],
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      );

      await quoteRepo.saveQuote(quote);

      final retrieved = await quoteRepo.getQuoteById('quote-test-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.clientName, 'Alejandro Morales');
      expect(retrieved.clientPhone, '5544332211');
      expect(retrieved.eventNotes, 'Entrega a las 3pm');
      expect(retrieved.status, QuoteStatus.pending);
      expect(retrieved.discount, PreciseDecimal.fromString('3.00'));
      expect(retrieved.depositAmount, PreciseDecimal.fromString('20.00'));
      expect(retrieved.items.length, 2);
      expect(retrieved.items[0].concept, 'Pastel Zanahoria 22cm');
      expect(retrieved.items[0].notes, 'Con nuez picada');
      expect(retrieved.items[1].concept, 'Caja Regalo y Moño');

      expect(retrieved.subtotal, PreciseDecimal.fromString('43.00'));
      expect(retrieved.totalAmount, PreciseDecimal.fromString('40.00'));
      expect(retrieved.remainingBalance, PreciseDecimal.fromString('20.00'));
    });

    test('Updates quote status efficiently', () async {
      final quote = Quote(
        id: 'quote-status-test',
        clientName: 'Beatriz Gomez',
        deliveryDate: DateTime(2026, 11, 15),
        discount: PreciseDecimal.zero,
        depositAmount: PreciseDecimal.zero,
        status: QuoteStatus.pending,
        items: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await quoteRepo.saveQuote(quote);

      await quoteRepo.updateQuoteStatus('quote-status-test', QuoteStatus.confirmed);
      final updated = await quoteRepo.getQuoteById('quote-status-test');
      expect(updated!.status, QuoteStatus.confirmed);

      await quoteRepo.updateQuoteStatus('quote-status-test', QuoteStatus.delivered);
      final delivered = await quoteRepo.getQuoteById('quote-status-test');
      expect(delivered!.status, QuoteStatus.delivered);
    });

    test('Searches quotes by client, phone, notes and concept', () async {
      final quote1 = Quote(
        id: 'q-s-1',
        clientName: 'Daniel Hernandez',
        clientPhone: '5599887766',
        eventNotes: 'Boda civil',
        deliveryDate: DateTime(2026, 12, 1),
        discount: PreciseDecimal.zero,
        depositAmount: PreciseDecimal.zero,
        status: QuoteStatus.confirmed,
        items: [
          QuoteItem(
            id: 'it-1',
            quoteId: 'q-s-1',
            concept: 'Pastel de Fondant 3 Pisos',
            quantity: PreciseDecimal.one,
            unitPrice: PreciseDecimal.fromString('150.00'),
          )
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final quote2 = Quote(
        id: 'q-s-2',
        clientName: 'Elena Silva',
        clientPhone: '5511002233',
        eventNotes: 'Baby shower',
        deliveryDate: DateTime(2026, 12, 2),
        discount: PreciseDecimal.zero,
        depositAmount: PreciseDecimal.zero,
        status: QuoteStatus.pending,
        items: [
          QuoteItem(
            id: 'it-2',
            quoteId: 'q-s-2',
            concept: 'Galletas Decoradas',
            quantity: PreciseDecimal.fromInt(24),
            unitPrice: PreciseDecimal.fromString('2.50'),
          )
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await quoteRepo.saveQuote(quote1);
      await quoteRepo.saveQuote(quote2);

      // Search by client name
      final res1 = await quoteRepo.searchQuotes('Daniel');
      expect(res1.length, 1);
      expect(res1.first.id, 'q-s-1');

      // Search by phone
      final res2 = await quoteRepo.searchQuotes('110022');
      expect(res2.length, 1);
      expect(res2.first.id, 'q-s-2');

      // Search by item concept
      final res3 = await quoteRepo.searchQuotes('Fondant');
      expect(res3.length, 1);
      expect(res3.first.id, 'q-s-1');

      // Search with status filter
      final res4 = await quoteRepo.searchQuotes('', status: QuoteStatus.pending);
      expect(res4.length, 1);
      expect(res4.first.id, 'q-s-2');
    });

    test('Deletes quote and its related items cascade', () async {
      final quote = Quote(
        id: 'q-delete',
        clientName: 'Persona a eliminar',
        deliveryDate: DateTime(2026, 12, 5),
        discount: PreciseDecimal.zero,
        depositAmount: PreciseDecimal.zero,
        items: [
          QuoteItem(
            id: 'it-del',
            quoteId: 'q-delete',
            concept: 'Pastelito',
            quantity: PreciseDecimal.one,
            unitPrice: PreciseDecimal.fromString('10.00'),
          )
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await quoteRepo.saveQuote(quote);
      expect(await quoteRepo.getQuoteById('q-delete'), isNotNull);

      await quoteRepo.deleteQuote('q-delete');
      expect(await quoteRepo.getQuoteById('q-delete'), isNull);
    });
  });
}
