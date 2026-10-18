import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../entities/quote.dart';

class QuoteReceiptGenerator {
  static const PdfColor _primaryCaramel = PdfColor.fromInt(0xFFC06B3E);
  static const PdfColor _primaryDarkCaramel = PdfColor.fromInt(0xFF994D25);
  static const PdfColor _butterCream = PdfColor.fromInt(0xFFFFF9F0);
  static const PdfColor _textEspresso = PdfColor.fromInt(0xFF2C221E);
  static const PdfColor _textMuted = PdfColor.fromInt(0xFF6B5E57);
  static const PdfColor _borderSubtle = PdfColor.fromInt(0xFFE6DEC8);
  static const PdfColor _profitGreen = PdfColor.fromInt(0xFF2E7D32);
  static const PdfColor _costRed = PdfColor.fromInt(0xFFC62828);

  /// Generates the raw PDF bytes for a commercial client quote receipt (BR-COT-04).
  static Future<Uint8List> generateReceiptPdf({
    required Quote quote,
    required BusinessConfig config,
  }) async {
    final doc = buildPdfDocument(quote: quote, config: config);
    return await doc.save();
  }

  /// Builds the printable `pw.Document` instance.
  static pw.Document buildPdfDocument({
    required Quote quote,
    required BusinessConfig config,
  }) {
    final pdf = pw.Document(
      title: 'Cotización - ${quote.clientName}',
      author: config.businessName,
      creator: 'CostiBake',
    );

    final fontBase = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontOblique = pw.Font.helveticaOblique();

    final theme = pw.ThemeData.withFont(
      base: fontBase,
      bold: fontBold,
      italic: fontOblique,
    );

    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: _butterCream,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: _borderSubtle),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          config.businessName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: _primaryDarkCaramel,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'PRESUPUESTO Y COMPROBANTE DE PEDIDO',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: const pw.BoxDecoration(
                            color: _primaryCaramel,
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            quote.status.label.toUpperCase(),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Folio: #${quote.id.substring(0, 8).toUpperCase()}',
                          style: const pw.TextStyle(fontSize: 9, color: _textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Client and Delivery Info Box
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderSubtle),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CLIENTE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textMuted)),
                        pw.SizedBox(height: 2),
                        pw.Text(quote.clientName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _textEspresso)),
                        if (quote.clientPhone != null && quote.clientPhone!.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Tel: ${quote.clientPhone}', style: const pw.TextStyle(fontSize: 10, color: _textMuted)),
                        ],
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('FECHA DE ENTREGA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textMuted)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          dateFormat.format(quote.deliveryDate),
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _primaryDarkCaramel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (quote.eventNotes != null && quote.eventNotes!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'Detalles del Pedido: ${quote.eventNotes}',
                    style: const pw.TextStyle(fontSize: 9, color: _textEspresso),
                  ),
                ),
              ],

              pw.SizedBox(height: 16),

              // Items Table
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: _borderSubtle, width: 0.5),
                  bottom: pw.BorderSide(color: _borderSubtle, width: 1),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(4),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(1.8),
                  3: pw.FlexColumnWidth(1.8),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: _butterCream),
                    children: [
                      _tableCell('CONCEPTO / DESCRIPCIÓN', isHeader: true),
                      _tableCell('CANT.', isHeader: true, align: pw.TextAlign.center),
                      _tableCell('PRECIO UNIT.', isHeader: true, align: pw.TextAlign.right),
                      _tableCell('TOTAL', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  ...quote.items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.concept,
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _textEspresso),
                              ),
                              if (item.notes != null && item.notes!.isNotEmpty)
                                pw.Text(
                                  item.notes!,
                                  style: const pw.TextStyle(fontSize: 8, color: _textMuted),
                                ),
                            ],
                          ),
                        ),
                        _tableCell(item.quantity.toStringAsFixed(1), align: pw.TextAlign.center),
                        _tableCell('${config.currencySymbol}${item.unitPrice.toStringAsFixed(2)}', align: pw.TextAlign.right),
                        _tableCell('${config.currencySymbol}${item.total.toStringAsFixed(2)}', align: pw.TextAlign.right, isBold: true),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 16),

              // Financial Summary & Totals
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _borderSubtle),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TÉRMINOS Y CONDICIONES', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textMuted)),
                          pw.SizedBox(height: 4),
                          pw.Text('• Se requiere un anticipo mínimo del 50% para apartar la fecha.', style: const pw.TextStyle(fontSize: 8, color: _textMuted)),
                          pw.Text('• El saldo restante se liquida al momento de la entrega.', style: const pw.TextStyle(fontSize: 8, color: _textMuted)),
                          pw.Text('• Por favor conserve este comprobante para cualquier aclaración.', style: const pw.TextStyle(fontSize: 8, color: _textMuted)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: _butterCream,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: _borderSubtle),
                      ),
                      child: pw.Column(
                        children: [
                          _summaryRow('Subtotal:', '${config.currencySymbol}${quote.subtotal.toStringAsFixed(2)}'),
                          if (quote.discount > PreciseDecimal.zero) ...[
                            pw.SizedBox(height: 4),
                            _summaryRow('Descuento:', '-${config.currencySymbol}${quote.discount.toStringAsFixed(2)}', valueColor: _costRed),
                          ],
                          pw.Divider(color: _borderSubtle, thickness: 1),
                          _summaryRow('TOTAL:', '${config.currencySymbol}${quote.totalAmount.toStringAsFixed(2)}', isBold: true, fontSize: 13),
                          pw.SizedBox(height: 6),
                          _summaryRow('Anticipo:', '${config.currencySymbol}${quote.depositAmount.toStringAsFixed(2)}', valueColor: _profitGreen),
                          pw.SizedBox(height: 4),
                          _summaryRow(
                            'Saldo Pendiente:',
                            '${config.currencySymbol}${quote.remainingBalance.toStringAsFixed(2)}',
                            isBold: true,
                            valueColor: quote.remainingBalance > PreciseDecimal.zero ? _costRed : _profitGreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  '¡Muchas gracias por su preferencia! ✨ Generado por CostiBake',
                  style: const pw.TextStyle(fontSize: 8, color: _textMuted),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 10,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? _primaryDarkCaramel : _textEspresso,
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 10,
    PdfColor? valueColor,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: _textEspresso,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor ?? _textEspresso,
          ),
        ),
      ],
    );
  }

  /// Formats WhatsApp message with professional typography and emojis (BR-COT-04).
  static String formatWhatsAppMessage({
    required Quote quote,
    required BusinessConfig config,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');
    final buffer = StringBuffer();

    buffer.writeln('🍰 *COTIZACIÓN - ${config.businessName.toUpperCase()}* 🍰');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 *Cliente:* ${quote.clientName}');
    if (quote.clientPhone != null && quote.clientPhone!.isNotEmpty) {
      buffer.writeln('📞 *Teléfono:* ${quote.clientPhone}');
    }
    buffer.writeln('📅 *Fecha de entrega:* ${dateFormat.format(quote.deliveryDate)}');
    if (quote.eventNotes != null && quote.eventNotes!.trim().isNotEmpty) {
      buffer.writeln('📝 *Detalles:* ${quote.eventNotes!.trim()}');
    }
    buffer.writeln('');
    buffer.writeln('📋 *DETALLE DEL PEDIDO:*');
    for (final item in quote.items) {
      buffer.writeln('• ${item.quantity.toStringAsFixed(1)}x ${item.concept} - ${config.currencySymbol}${item.total.toStringAsFixed(2)}');
      if (item.notes != null && item.notes!.trim().isNotEmpty) {
        buffer.writeln('  _(${item.notes!.trim()})_');
      }
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💵 *Subtotal:* ${config.currencySymbol}${quote.subtotal.toStringAsFixed(2)}');
    if (quote.discount > PreciseDecimal.zero) {
      buffer.writeln('🏷️ *Descuento:* -${config.currencySymbol}${quote.discount.toStringAsFixed(2)}');
    }
    buffer.writeln('💰 *TOTAL:* ${config.currencySymbol}${quote.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('✅ *Anticipo:* ${config.currencySymbol}${quote.depositAmount.toStringAsFixed(2)}');
    buffer.writeln('⏳ *Saldo Pendiente:* ${config.currencySymbol}${quote.remainingBalance.toStringAsFixed(2)}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('✨ ¡Muchas gracias por tu preferencia! ✨');

    return buffer.toString();
  }

  /// Opens WhatsApp directly using URL scheme or web API.
  static Future<bool> openWhatsApp({
    required Quote quote,
    required BusinessConfig config,
  }) async {
    final message = formatWhatsAppMessage(quote: quote, config: config);
    final encodedMessage = Uri.encodeComponent(message);

    // Clean phone number (strip spaces, dashes, etc.)
    final rawPhone = quote.clientPhone ?? '';
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');

    final urlString = cleanPhone.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=$encodedMessage'
        : 'https://wa.me/?text=$encodedMessage';

    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Shares the generated PDF receipt through the OS native share sheet (which allows selecting WhatsApp).
  static Future<void> sharePdfReceipt({
    required Quote quote,
    required BusinessConfig config,
  }) async {
    final pdfBytes = await generateReceiptPdf(quote: quote, config: config);
    final cleanClientName = quote.clientName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final filename = 'Cotizacion_${cleanClientName}_${quote.id.substring(0, 6)}.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }
}
