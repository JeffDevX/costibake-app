import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../../domain/entities/quote.dart';
import '../../domain/services/quote_receipt_generator.dart';

class QuoteShareDialog extends StatelessWidget {
  final Quote quote;
  final BusinessConfig config;

  const QuoteShareDialog({
    super.key,
    required this.quote,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bakeryColors;
    final messagePreview = QuoteReceiptGenerator.formatWhatsAppMessage(
      quote: quote,
      config: config,
    );

    return AlertDialog(
      backgroundColor: colors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.borderSubtle),
      ),
      title: Row(
        children: [
          Icon(Icons.share, color: colors.primaryCaramel),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Compartir Cotización',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textEspresso,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cliente: ${quote.clientName}',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.textEspresso),
              ),
              const SizedBox(height: 12),

              // Button 1: Direct WhatsApp Text
              ElevatedButton.icon(
                key: const Key('btn_share_whatsapp_text'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  final launched = await QuoteReceiptGenerator.openWhatsApp(
                    quote: quote,
                    config: config,
                  );
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('No se pudo abrir WhatsApp automáticamente. Mensaje copiado al portapapeles.'),
                        backgroundColor: colors.primaryCaramel,
                      ),
                    );
                    await Clipboard.setData(ClipboardData(text: messagePreview));
                  }
                },
                icon: const Icon(Icons.chat, size: 20),
                label: const Text('Enviar mensaje por WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(height: 10),

              // Button 2: Share PDF Receipt
              ElevatedButton.icon(
                key: const Key('btn_share_receipt_pdf'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await QuoteReceiptGenerator.sharePdfReceipt(
                    quote: quote,
                    config: config,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 20),
                label: const Text('Compartir Recibo en PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primaryCaramel,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(height: 10),

              // Button 3: Print / Preview PDF
              OutlinedButton.icon(
                key: const Key('btn_print_preview_pdf'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  final pdfBytes = await QuoteReceiptGenerator.generateReceiptPdf(
                    quote: quote,
                    config: config,
                  );
                  await Printing.layoutPdf(
                    onLayout: (_) => pdfBytes,
                    name: 'Cotizacion_${quote.clientName}.pdf',
                  );
                },
                icon: Icon(Icons.print, size: 20, color: colors.primaryDarkCaramel),
                label: Text('Ver / Imprimir Comprobante', style: TextStyle(color: colors.primaryDarkCaramel)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.primaryCaramel),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(height: 16),

              // Preview container with Copy button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vista previa del mensaje:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textMuted),
                  ),
                  TextButton.icon(
                    key: const Key('btn_copy_quote_text'),
                    style: TextButton.styleFrom(foregroundColor: colors.primaryCaramel),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: messagePreview));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mensaje copiado al portapapeles'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copiar texto', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surfaceWarm,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Text(
                  messagePreview,
                  style: TextStyle(fontSize: 11, color: colors.textEspresso, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colors.primaryCaramel),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
