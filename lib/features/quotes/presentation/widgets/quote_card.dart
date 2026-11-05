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

  Color _getStatusColor(BuildContext context, QuoteStatus status) {
    final colors = context.bakeryColors;
    switch (status) {
      case QuoteStatus.pending:
        return colors.warningAmber;
      case QuoteStatus.confirmed:
        return colors.primaryCaramel;
      case QuoteStatus.delivered:
        return colors.profitGreen;
      case QuoteStatus.cancelled:
        return colors.textMuted;
    }
  }

  Color _getStatusBgColor(BuildContext context, QuoteStatus status) {
    final colors = context.bakeryColors;
    final isCacao = context.isCacaoMode;
    final color = _getStatusColor(context, status);

    if (isCacao) {
      return color.withValues(alpha: 0.2);
    }

    switch (status) {
      case QuoteStatus.pending:
        return Colors.orange.shade50;
      case QuoteStatus.confirmed:
        return colors.butterCream;
      case QuoteStatus.delivered:
        return Colors.green.shade50;
      case QuoteStatus.cancelled:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bakeryColors;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final statusColor = _getStatusColor(context, quote.status);
    final statusBg = _getStatusBgColor(context, quote.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: context.isCacaoMode ? 0 : 1.5,
      color: colors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderSubtle, width: 0.8),
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
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: colors.surfaceHighlight,
                          child: Icon(
                            Icons.person,
                            size: 20,
                            color: colors.primaryCaramel,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quote.clientName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: colors.textEspresso,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (quote.clientPhone != null && quote.clientPhone!.isNotEmpty)
                                Text(
                                  quote.clientPhone!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textMuted,
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
                      border: Border.all(color: statusColor.withValues(alpha: context.isCacaoMode ? 0.4 : 0.5)),
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
                    icon: Icon(Icons.more_vert, color: colors.textMuted),
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
                      PopupMenuItem(
                        value: 'status_confirmed',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 18, color: colors.primaryCaramel),
                            const SizedBox(width: 8),
                            const Text('Marcar como Confirmada'),
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
                  Icon(Icons.event_outlined, size: 16, color: colors.primaryCaramel),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Entrega: ${dateFormat.format(quote.deliveryDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.primaryDarkCaramel,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (quote.items.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  quote.items.map((i) => '${i.quantity.toStringAsFixed(0)}x ${i.concept}').join(' • '),
                  style: TextStyle(fontSize: 12, color: colors.textEspresso),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              Divider(height: 20, color: colors.borderSubtle),

              // Financial row & WhatsApp Share button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total: ${config.currencySymbol}${quote.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.textEspresso,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Text(
                              'Anticipo: ${config.currencySymbol}${quote.depositAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.profitGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Saldo: ${config.currencySymbol}${quote.remainingBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: quote.remainingBalance > PreciseDecimal.zero
                                    ? colors.costRed
                                    : colors.profitGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

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
