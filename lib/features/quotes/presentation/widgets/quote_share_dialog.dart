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
    final messagePreview = QuoteReceiptGenerator.formatWhatsAppMessage(
      quote: quote,
      config: config,
    );

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.share, color: AppColors.primaryCaramel),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Compartir Cotización',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textEspresso,
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
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textEspresso),
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
                      const SnackBar(
                        content: Text('No se pudo abrir WhatsApp automáticamente. Mensaje copiado al portapapeles.'),
                        backgroundColor: AppColors.primaryCaramel,
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
                  backgroundColor: AppColors.primaryCaramel,
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
                icon: const Icon(Icons.print, size: 20, color: AppColors.primaryDarkCaramel),
                label: const Text('Ver / Imprimir Comprobante', style: TextStyle(color: AppColors.primaryDarkCaramel)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryCaramel),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(height: 16),

              // Preview container with Copy button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vista previa del mensaje:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                  ),
                  TextButton.icon(
                    key: const Key('btn_copy_quote_text'),
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
                  color: AppColors.butterCream,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  messagePreview,
                  style: const TextStyle(fontSize: 11, color: AppColors.textEspresso, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
