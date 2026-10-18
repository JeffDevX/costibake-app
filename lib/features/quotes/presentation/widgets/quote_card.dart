import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../../domain/entities/quote.dart';
import 'quote_share_dialog.dart';

class QuoteCard extends StatelessWidget {
  final Quote quote;
  final BusinessConfig config;
  final VoidCallback onTap;
  final ValueChanged<QuoteStatus> onStatusChanged;
  final VoidCallback onDelete;

  const QuoteCard({
    super.key,
    required this.quote,
    required this.config,
    required this.onTap,
    required this.onStatusChanged,
    required this.onDelete,
  });

  Color _getStatusColor(QuoteStatus status) {
    switch (status) {
      case QuoteStatus.pending:
        return Colors.orange.shade700;
      case QuoteStatus.confirmed:
        return AppColors.primaryCaramel;
      case QuoteStatus.delivered:
        return Colors.green.shade700;
      case QuoteStatus.cancelled:
        return Colors.grey.shade600;
    }
  }

  Color _getStatusBgColor(QuoteStatus status) {
    switch (status) {
      case QuoteStatus.pending:
        return Colors.orange.shade50;
      case QuoteStatus.confirmed:
        return AppColors.butterCream;
      case QuoteStatus.delivered:
        return Colors.green.shade50;
      case QuoteStatus.cancelled:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final statusColor = _getStatusColor(quote.status);
    final statusBg = _getStatusBgColor(quote.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderSubtle, width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Client Name, Status Badge, Menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.butterCream,
                          child: Icon(
                            Icons.person,
                            size: 20,
                            color: AppColors.primaryCaramel,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quote.clientName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textEspresso,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (quote.clientPhone != null && quote.clientPhone!.isNotEmpty)
                                Text(
                                  quote.clientPhone!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      quote.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                    tooltip: 'Opciones de cotización',
                    onSelected: (action) {
                      if (action == 'status_pending') onStatusChanged(QuoteStatus.pending);
                      if (action == 'status_confirmed') onStatusChanged(QuoteStatus.confirmed);
                      if (action == 'status_delivered') onStatusChanged(QuoteStatus.delivered);
                      if (action == 'status_cancelled') onStatusChanged(QuoteStatus.cancelled);
                      if (action == 'delete') onDelete();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'status_pending',
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_empty, size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Marcar como Pendiente'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'status_confirmed',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 18, color: AppColors.primaryCaramel),
                            SizedBox(width: 8),
                            Text('Marcar como Confirmada'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'status_delivered',
                        child: Row(
                          children: [
                            Icon(Icons.task_alt, size: 18, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Marcar como Entregada'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'status_cancelled',
                        child: Row(
                          children: [
                            Icon(Icons.cancel_outlined, size: 18, color: Colors.grey),
                            SizedBox(width: 8),
                            Text('Marcar como Cancelada'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar cotización', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Delivery Date & Items Summary
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 16, color: AppColors.primaryDarkCaramel),
                  const SizedBox(width: 6),
                  Text(
                    'Entrega: ${dateFormat.format(quote.deliveryDate)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDarkCaramel,
                    ),
                  ),
                ],
              ),

              if (quote.items.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  quote.items.map((i) => '${i.quantity.toStringAsFixed(0)}x ${i.concept}').join(' • '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textEspresso),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const Divider(height: 20, color: AppColors.borderSubtle),

              // Financial row & WhatsApp Share button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: ${config.currencySymbol}${quote.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textEspresso,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Anticipo: ${config.currencySymbol}${quote.depositAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Saldo: ${config.currencySymbol}${quote.remainingBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: quote.remainingBalance > PreciseDecimal.zero
                                  ? Colors.red.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Share CTA
                  ElevatedButton.icon(
                    key: Key('btn_share_quote_${quote.id}'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => QuoteShareDialog(
                          quote: quote,
                          config: config,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Compartir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp color
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(48, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
