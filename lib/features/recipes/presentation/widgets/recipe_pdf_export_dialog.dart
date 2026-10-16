import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../costing/domain/entities/cost_breakdown.dart';
import '../../../costing/domain/services/costing_calculation_engine.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_pdf_document_type.dart';
import '../../domain/services/recipe_pdf_generator.dart';

/// Modal dialog allowing the pastry chef to select the export modality
/// (Production Sheet vs. Financial Technical Sheet) and preview/print or share the resulting PDF (JEF-26, RF-SYS-27).
class RecipePdfExportDialog extends StatefulWidget {
  final Recipe recipe;
  final BusinessConfig? businessConfig;
  final CostBreakdown? costBreakdown;
  final Future<void> Function(Uint8List bytes, String filename)? onCustomPrint;
  final Future<void> Function(Uint8List bytes, String filename)? onCustomShare;

  const RecipePdfExportDialog({
    super.key,
    required this.recipe,
    this.businessConfig,
    this.costBreakdown,
    this.onCustomPrint,
    this.onCustomShare,
  });

  /// Static helper to display the modal dialog.
  static Future<void> show(
    BuildContext context, {
    required Recipe recipe,
    BusinessConfig? businessConfig,
    CostBreakdown? costBreakdown,
    Future<void> Function(Uint8List bytes, String filename)? onCustomPrint,
    Future<void> Function(Uint8List bytes, String filename)? onCustomShare,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => RecipePdfExportDialog(
        recipe: recipe,
        businessConfig: businessConfig,
        costBreakdown: costBreakdown,
        onCustomPrint: onCustomPrint,
        onCustomShare: onCustomShare,
      ),
    );
  }

  @override
  State<RecipePdfExportDialog> createState() => _RecipePdfExportDialogState();
}

class _RecipePdfExportDialogState extends State<RecipePdfExportDialog> {
  RecipePdfDocumentType _selectedType = RecipePdfDocumentType.productionSheet;
  bool _isGenerating = false;

  BusinessConfig _resolveBusinessConfig(BuildContext context) {
    if (widget.businessConfig != null) {
      return widget.businessConfig!;
    }
    try {
      final state = context.read<SettingsBloc>().state;
      if (state is SettingsLoaded) {
        return state.config;
      }
    } catch (_) {}

    return BusinessConfig(
      id: 'default',
      businessName: 'Mi Pastelería Artesanal',
      currencySymbol: '\$',
      laborHourlyRate: widget.recipe.laborHourlyRateOverride ??
          PreciseDecimal.fromInt(10),
      overheadPercentage: widget.recipe.overheadPercentageOverride ??
          PreciseDecimal.fromInt(15),
      updatedAt: DateTime.now(),
    );
  }

  CostBreakdown _resolveCostBreakdown(BusinessConfig config) {
    if (widget.costBreakdown != null) {
      return widget.costBreakdown!;
    }
    return CostingCalculationEngine.calculate(
      recipe: widget.recipe,
      config: config,
    );
  }

  Future<Uint8List> _generateBytes(BusinessConfig config) async {
    final breakdown = _resolveCostBreakdown(config);
    return RecipePdfGenerator.generatePdf(
      recipe: widget.recipe,
      config: config,
      costBreakdown: breakdown,
      documentType: _selectedType,
    );
  }

  String _buildFilename() {
    final sanitizedRecipe = widget.recipe.name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final prefix = _selectedType == RecipePdfDocumentType.productionSheet
        ? 'ficha_produccion'
        : 'ficha_financiera';
    return '${prefix}_$sanitizedRecipe.pdf';
  }

  Future<void> _handlePrintPreview(BusinessConfig config) async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _generateBytes(config);
      final filename = _buildFilename();

      if (widget.onCustomPrint != null) {
        await widget.onCustomPrint!(bytes, filename);
      } else {
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: filename,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: AppColors.costRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _handleShare(BusinessConfig config) async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _generateBytes(config);
      final filename = _buildFilename();

      if (widget.onCustomShare != null) {
        await widget.onCustomShare!(bytes, filename);
      } else {
        await Printing.sharePdf(
          bytes: bytes,
          filename: filename,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir PDF: $e'),
            backgroundColor: AppColors.costRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _resolveBusinessConfig(context);
    final isIncomplete = widget.recipe.isIncomplete;

    return AlertDialog(
      key: const Key('recipe_pdf_export_dialog'),
      scrollable: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.butterCream,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.primaryDarkCaramel,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Exportar Receta en PDF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textEspresso,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona el formato de documento a generar para "${widget.recipe.name}":',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),

            if (isIncomplete) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.costRedLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.costRed.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.costRed, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Receta Incompleta: contiene insumos eliminados. Los reportes reflejarán las advertencias correspondientes.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.costRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Opción 1: Ficha de Producción Culinaria (BR-EXP-02)
            InkWell(
              key: const Key('radio_export_production_sheet'),
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _selectedType = RecipePdfDocumentType.productionSheet;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedType == RecipePdfDocumentType.productionSheet
                      ? AppColors.butterCream
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedType == RecipePdfDocumentType.productionSheet
                        ? AppColors.primaryCaramel
                        : AppColors.borderSubtle,
                    width: _selectedType == RecipePdfDocumentType.productionSheet
                        ? 1.5
                        : 1.0,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _selectedType == RecipePdfDocumentType.productionSheet
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _selectedType == RecipePdfDocumentType.productionSheet
                          ? AppColors.primaryCaramel
                          : AppColors.textLight,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ficha de Producción Culinaria',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textEspresso,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Diseñada para ayudantes y personal de cocina. Contiene ingredientes, porciones, molde y notas, ocultando estrictamente costos y precios.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Opción 2: Ficha Técnica Financiera (BR-EXP-03)
            InkWell(
              key: const Key('radio_export_financial_sheet'),
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _selectedType = RecipePdfDocumentType.financialSheet;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedType == RecipePdfDocumentType.financialSheet
                      ? AppColors.butterCream
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedType == RecipePdfDocumentType.financialSheet
                        ? AppColors.primaryCaramel
                        : AppColors.borderSubtle,
                    width: _selectedType == RecipePdfDocumentType.financialSheet
                        ? 1.5
                        : 1.0,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _selectedType == RecipePdfDocumentType.financialSheet
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _selectedType == RecipePdfDocumentType.financialSheet
                          ? AppColors.primaryCaramel
                          : AppColors.textLight,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ficha Técnica Financiera',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textEspresso,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Diseñada para el repostero / administración. Desglose completo de materias primas, empaques, mano de obra, overhead, márgenes y precio sugerido.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isGenerating) ...[
              const SizedBox(height: 16),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 8),
                    Text(
                      'Generando documento PDF...',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('btn_cancel_export_dialog'),
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        OutlinedButton.icon(
          key: const Key('btn_share_pdf'),
          onPressed: _isGenerating ? null : () => _handleShare(config),
          icon: const Icon(Icons.share_outlined, size: 18),
          label: const Text('Compartir'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(96, 44),
          ),
        ),
        ElevatedButton.icon(
          key: const Key('btn_preview_print_pdf'),
          onPressed: _isGenerating ? null : () => _handlePrintPreview(config),
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Imprimir / Ver'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryCaramel,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 44),
          ),
        ),
      ],
    );
  }
}
