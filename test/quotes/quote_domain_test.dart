import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/quotes/domain/entities/quote.dart';
import 'package:costibake_app/features/quotes/domain/entities/quote_item.dart';
import 'package:costibake_app/features/quotes/domain/services/quote_receipt_generator.dart';
import 'package:costibake_app/features/settings/domain/entities/business_config.dart';

void main() {
  group('Quote and QuoteItem Domain Unit Tests (BR-COT-01..04)', () {
    test('QuoteItem calculates total quantity * unitPrice with high precision', () {
      final item = QuoteItem(
        id: 'item-1',
        quoteId: 'quote-1',
        concept: 'Pastel de Chocolate 20cm',
        type: QuoteItemType.recipe,
        quantity: PreciseDecimal.fromString('2.5'),
        unitPrice: PreciseDecimal.fromString('35.00'),
      );

      expect(item.total, PreciseDecimal.fromString('87.50'));
    });

    test('Quote calculates subtotal, discount, totalAmount and remainingBalance', () {
      final item1 = QuoteItem(
        id: 'item-1',
        quoteId: 'quote-1',
        concept: 'Pastel Tres Leches',
        type: QuoteItemType.recipe,
        quantity: PreciseDecimal.fromString('1.0'),
        unitPrice: PreciseDecimal.fromString('40.00'),
      );

      final item2 = QuoteItem(
        id: 'item-2',
        quoteId: 'quote-1',
        concept: 'Topper Personalizado',
        type: QuoteItemType.custom,
        quantity: PreciseDecimal.fromString('1.0'),
        unitPrice: PreciseDecimal.fromString('15.00'),
      );

      final quote = Quote(
        id: 'quote-1',
        clientName: 'María García',
        clientPhone: '+525512345678',
        eventNotes: 'Temática flores moradas',
        deliveryDate: DateTime(2026, 11, 20, 16, 0),
        discount: PreciseDecimal.fromString('5.00'),
        depositAmount: PreciseDecimal.fromString('30.00'),
        status: QuoteStatus.confirmed,
        items: [item1, item2],
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      );

      // Subtotal = 40.00 + 15.00 = 55.00
      expect(quote.subtotal, PreciseDecimal.fromString('55.00'));
      // Total = 55.00 - 5.00 = 50.00
      expect(quote.totalAmount, PreciseDecimal.fromString('50.00'));
      // Remaining = 50.00 - 30.00 = 20.00
      expect(quote.remainingBalance, PreciseDecimal.fromString('20.00'));
      expect(quote.isFullyPaid, isFalse);
    });

    test('Quote handles deposit exceeding or matching total', () {
      final item = QuoteItem(
        id: 'item-1',
        quoteId: 'quote-2',
        concept: 'Cupcakes Docena',
        quantity: PreciseDecimal.fromString('2.0'),
        unitPrice: PreciseDecimal.fromString('20.00'),
      );

      final quote = Quote(
        id: 'quote-2',
        clientName: 'Carlos Ruiz',
        deliveryDate: DateTime(2026, 11, 22),
        discount: PreciseDecimal.zero,
        depositAmount: PreciseDecimal.fromString('40.00'),
        items: [item],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(quote.subtotal, PreciseDecimal.fromString('40.00'));
      expect(quote.totalAmount, PreciseDecimal.fromString('40.00'));
      expect(quote.remainingBalance, PreciseDecimal.zero);
      expect(quote.isFullyPaid, isTrue);
    });

    test('QuoteStatus parses from code and falls back to pending', () {
      expect(QuoteStatus.fromCode('CONFIRMADA'), QuoteStatus.confirmed);
      expect(QuoteStatus.fromCode('ENTREGADA'), QuoteStatus.delivered);
      expect(QuoteStatus.fromCode('CANCELADA'), QuoteStatus.cancelled);
      expect(QuoteStatus.fromCode('UNKNOWN'), QuoteStatus.pending);
    });

    test('QuoteReceiptGenerator formats WhatsApp message with complete breakdown', () {
      final config = BusinessConfig(
        id: 'cfg-1',
        businessName: 'Dulces Momentos',
        currencySymbol: '\$',
        laborHourlyRate: PreciseDecimal.fromString('12.00'),
        overheadPercentage: PreciseDecimal.fromString('15.00'),
        updatedAt: DateTime.now(),
      );

      final item = QuoteItem(
        id: 'item-1',
        quoteId: 'q-wa',
        concept: 'Pastel Redondo 20cm Vainilla',
        quantity: PreciseDecimal.fromString('1.0'),
        unitPrice: PreciseDecimal.fromString('45.00'),
        notes: 'Relleno de Nutella',
      );

      final quote = Quote(
        id: 'q-wa-12345678',
        clientName: 'Ana Mendoza',
        clientPhone: '5511223344',
        eventNotes: 'Cumpleaños sorpresa',
        deliveryDate: DateTime(2026, 12, 15, 17, 30),
        discount: PreciseDecimal.fromString('5.00'),
        depositAmount: PreciseDecimal.fromString('25.00'),
        items: [item],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final message = QuoteReceiptGenerator.formatWhatsAppMessage(
        quote: quote,
        config: config,
      );

      expect(message, contains('COTIZACIÓN - DULCES MOMENTOS'));
      expect(message, contains('Ana Mendoza'));
      expect(message, contains('5511223344'));
      expect(message, contains('Cumpleaños sorpresa'));
      expect(message, contains('Pastel Redondo 20cm Vainilla'));
      expect(message, contains('Relleno de Nutella'));
      expect(message, contains('\$45.00'));
      expect(message, contains('TOTAL:* \$40.00'));
      expect(message, contains('Anticipo:* \$25.00'));
      expect(message, contains('Saldo Pendiente:* \$15.00'));
    });

    test('QuoteReceiptGenerator builds PDF Document without throwing', () {
      final config = BusinessConfig(
        id: 'cfg-1',
        businessName: 'CostiBake Test Bakery',
        currencySymbol: '\$',
        laborHourlyRate: PreciseDecimal.fromString('15.00'),
        overheadPercentage: PreciseDecimal.fromString('10.00'),
        updatedAt: DateTime.now(),
      );

      final item = QuoteItem(
        id: 'item-pdf',
        quoteId: 'q-pdf',
        concept: 'Torta Red Velvet',
        quantity: PreciseDecimal.fromString('2.0'),
        unitPrice: PreciseDecimal.fromString('35.00'),
      );

      final quote = Quote(
        id: 'q-pdf-12345678',
        clientName: 'Sofia Ramos',
        deliveryDate: DateTime(2026, 12, 24, 18, 0),
        discount: PreciseDecimal.zero,
        depositAmount: PreciseDecimal.fromString('35.00'),
        items: [item],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final doc = QuoteReceiptGenerator.buildPdfDocument(
        quote: quote,
        config: config,
      );

      expect(doc, isNotNull);
      expect(doc.document.pdfPageList.pages.length, 1);
    });
  });
}
