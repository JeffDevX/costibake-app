import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../domain/entities/dual_pricing_breakdown.dart';
import '../../domain/entities/pricing_strategy.dart';
import '../../domain/services/pricing_engine.dart';

/// Interactive dual pricing widget providing markup/margin configuration,
/// psychological rounding, manual price overrides, and loss protection alerts
/// (JEF-16, RF-SYS-18..20, BR-PRC-01..05).
class DualPricingCard extends StatefulWidget {
  final PreciseDecimal totalProductionCost;
  final int yieldPortions;
  final String currencySymbol;
  final PricingStrategy initialStrategy;
  final ValueChanged<PricingStrategy>? onStrategyChanged;

  const DualPricingCard({
    super.key,
    required this.totalProductionCost,
    required this.yieldPortions,
    required this.currencySymbol,
    required this.initialStrategy,
    this.onStrategyChanged,
  });

  @override
  State<DualPricingCard> createState() => _DualPricingCardState();
}

class _DualPricingCardState extends State<DualPricingCard> {
  late PricingMode _mode;
  late RoundingRule _roundingRule;
  late TextEditingController _marginController;
  late TextEditingController _customBatchPriceController;
  late TextEditingController _customPortionPriceController;

  static const List<int> _markupPresets = [30, 40, 50, 60, 100];
  static const List<int> _marginPresets = [20, 30, 40, 50, 70];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialStrategy.mode;
    _roundingRule = widget.initialStrategy.roundingRule;
    _marginController = TextEditingController(
      text: widget.initialStrategy.targetProfitMargin.toStringAsFixed(0),
    );
    _customBatchPriceController = TextEditingController(
      text: widget.initialStrategy.customBatchPrice?.toStringAsFixed(2) ?? '',
    );
    _customPortionPriceController = TextEditingController(
      text: widget.initialStrategy.customPortionPrice?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant DualPricingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStrategy != oldWidget.initialStrategy) {
      if (_mode != widget.initialStrategy.mode) {
        _mode = widget.initialStrategy.mode;
      }
      if (_roundingRule != widget.initialStrategy.roundingRule) {
        _roundingRule = widget.initialStrategy.roundingRule;
      }
      final marginStr =
          widget.initialStrategy.targetProfitMargin.toStringAsFixed(0);
      if (_marginController.text != marginStr) {
        _marginController.text = marginStr;
      }
    }
    if (widget.yieldPortions != oldWidget.yieldPortions ||
        widget.totalProductionCost != oldWidget.totalProductionCost) {
      if (oldWidget.yieldPortions == 1 && widget.yieldPortions > 1) {
        if (_customPortionPriceController.text.isNotEmpty &&
            (_customPortionPriceController.text ==
                    _customBatchPriceController.text ||
                _customPortionPriceController.text ==
                    oldWidget.totalProductionCost.toStringAsFixed(2))) {
          _customPortionPriceController.clear();
          _notifyParent();
        }
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _marginController.dispose();
    _customBatchPriceController.dispose();
    _customPortionPriceController.dispose();
    super.dispose();
  }

  PreciseDecimal get _currentMargin {
    final parsed = PreciseDecimal.tryParse(_marginController.text.trim());
    if (parsed == null || parsed < PreciseDecimal.zero) {
      return PreciseDecimal.fromInt(40);
    }
    if (_mode == PricingMode.marginOnSales &&
        parsed >= PreciseDecimal.fromInt(100)) {
      return PreciseDecimal.fromString('99.0');
    }
    return parsed;
  }

  PreciseDecimal? get _customBatchPrice {
    final text = _customBatchPriceController.text.trim();
    if (text.isEmpty) return null;
    return PreciseDecimal.tryParse(text);
  }

  PreciseDecimal? get _customPortionPrice {
    final text = _customPortionPriceController.text.trim();
    if (text.isEmpty) return null;
    return PreciseDecimal.tryParse(text);
  }

  PricingStrategy get _currentStrategy => PricingStrategy(
        mode: _mode,
        targetProfitMargin: _currentMargin,
        roundingRule: _roundingRule,
        customBatchPrice: _customBatchPrice,
        customPortionPrice: _customPortionPrice,
      );

  void _notifyParent() {
    widget.onStrategyChanged?.call(_currentStrategy);
  }

  DualPricingBreakdown get _breakdown {
    try {
      return PricingEngine.calculate(
        totalProductionCost: widget.totalProductionCost,
        yieldPortions: widget.yieldPortions,
        strategy: _currentStrategy,
      );
    } catch (_) {
      return PricingEngine.calculate(
        totalProductionCost: widget.totalProductionCost,
        yieldPortions: widget.yieldPortions,
        strategy: PricingStrategy.defaultStrategy(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = _breakdown;
    final presets =
        _mode == PricingMode.markupOnCost ? _markupPresets : _marginPresets;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.butterCream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderWarm),
                  ),
                  child: const Icon(
                    Icons.sell_outlined,
                    color: AppColors.primaryCaramel,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estrategia de Precios y Ganancia',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textEspresso,
                        ),
                      ),
                      Text(
                        'Fijación dual de precios (Lote vs. Porción) con protección de rentabilidad (JEF-16)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode Selector: Markup on Cost vs Margin on Sales (BR-PRC-01, RF-SYS-18)
            const Text(
              'Modelo de Ganancia Comercial',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textEspresso,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              key: const Key('pricing_mode_segmented_button'),
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  key: const Key('mode_chip_markup'),
                  label: const Text('Markup sobre Costo'),
                  selected: _mode == PricingMode.markupOnCost,
                  selectedColor: AppColors.butterCream,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _mode == PricingMode.markupOnCost
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _mode == PricingMode.markupOnCost
                        ? AppColors.primaryDarkCaramel
                        : AppColors.textEspresso,
                  ),
                  side: BorderSide(
                    color: _mode == PricingMode.markupOnCost
                        ? AppColors.primaryCaramel
                        : AppColors.borderWarm,
                  ),
                  onSelected: (selected) {
                    if (selected && _mode != PricingMode.markupOnCost) {
                      setState(() {
                        _mode = PricingMode.markupOnCost;
                      });
                      _notifyParent();
                    }
                  },
                ),
                ChoiceChip(
                  key: const Key('mode_chip_margin'),
                  label: const Text('Margen sobre Venta'),
                  selected: _mode == PricingMode.marginOnSales,
                  selectedColor: AppColors.butterCream,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _mode == PricingMode.marginOnSales
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _mode == PricingMode.marginOnSales
                        ? AppColors.primaryDarkCaramel
                        : AppColors.textEspresso,
                  ),
                  side: BorderSide(
                    color: _mode == PricingMode.marginOnSales
                        ? AppColors.primaryCaramel
                        : AppColors.borderWarm,
                  ),
                  onSelected: (selected) {
                    if (selected && _mode != PricingMode.marginOnSales) {
                      setState(() {
                        _mode = PricingMode.marginOnSales;
                        if (_currentMargin >= PreciseDecimal.fromInt(100)) {
                          _marginController.text = '50';
                        }
                      });
                      _notifyParent();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _mode.formulaDescription,
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),

            // Target Margin (%) Selector & Presets
            Row(
              children: [
                Expanded(
                  child: Text(
                    _mode == PricingMode.markupOnCost
                        ? 'Margen Deseado (% Markup)'
                        : 'Margen Deseado (% sobre Venta)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textEspresso,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  height: 48,
                  child: TextFormField(
                    key: const Key('target_margin_input_field'),
                    controller: _marginController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    onEditingComplete: () => FocusScope.of(context).unfocus(),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                    decoration: const InputDecoration(
                      suffixText: '%',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _notifyParent();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quick Preset Chips (30%, 40%, 50%, 60%, 100%)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: presets.map((p) {
                final isSelected =
                    _currentMargin == PreciseDecimal.fromInt(p);
                return FilterChip(
                  key: Key('margin_preset_chip_$p'),
                  label: Text('+$p%'),
                  selected: isSelected,
                  selectedColor: AppColors.butterCream,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primaryDarkCaramel
                        : AppColors.textEspresso,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryCaramel
                        : AppColors.borderWarm,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _marginController.text = p.toString();
                      });
                      _notifyParent();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Rounding Rule Selector (RF-SYS-20)
            const Text(
              'Redondeo Comercial Psicológico',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textEspresso,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: RoundingRule.values.map((rule) {
                final isSelected = _roundingRule == rule;
                return ChoiceChip(
                  key: Key('rounding_chip_${rule.name}'),
                  label: Text(rule.displayName),
                  selected: isSelected,
                  selectedColor: AppColors.surfaceHighlight,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primaryDarkCaramel
                        : AppColors.textEspresso,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryCaramel
                        : AppColors.borderWarm,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _roundingRule = rule;
                      });
                      _notifyParent();
                    }
                  },
                );
              }).toList(),
            ),
            const Divider(height: 28),

            // Dual Pricing Outputs: Batch & Portion (RF-SYS-19)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 540;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildBatchPricingCard(breakdown),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildPortionPricingCard(breakdown),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildBatchPricingCard(breakdown),
                      const SizedBox(height: 14),
                      _buildPortionPricingCard(breakdown),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchPricingCard(DualPricingBreakdown breakdown) {
    final isLoss = breakdown.isBatchAtLoss;
    final isCustom = breakdown.isBatchCustomPrice;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLoss ? AppColors.costRedLight : AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLoss ? AppColors.costRed : AppColors.borderWarm,
          width: isLoss ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.cake_outlined,
                      size: 18,
                      color: AppColors.primaryDarkCaramel,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'PRECIO LOTE SUGERIDO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.textEspresso,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isCustom)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.honeyAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Manual',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDarkCaramel,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Costo Total de Producción
          _buildInfoRow(
            'Costo Total (CTP):',
            breakdown.batchCost.toCurrencyString(symbol: widget.currencySymbol),
          ),
          // Precio Sugerido
          _buildInfoRow(
            'Precio Sugerido:',
            breakdown.roundedSuggestedBatchPrice
                .toCurrencyString(symbol: widget.currencySymbol),
            subtitle: _roundingRule != RoundingRule.none
                ? '(Base: ${breakdown.rawSuggestedBatchPrice.toCurrencyString(symbol: widget.currencySymbol)})'
                : null,
          ),
          const SizedBox(height: 8),

          // Precio Final Efectivo (Large Typographic Contrast >= 24sp)
          const Text(
            'Precio Final Lote:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('custom_batch_price_field'),
                  controller: _customBatchPriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                  style: const TextStyle(
                    fontSize: 24, // Minimum 24sp bold requirement
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDarkCaramel,
                  ),
                  decoration: InputDecoration(
                    prefixText: widget.currencySymbol,
                    prefixStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryCaramel,
                    ),
                    hintText: breakdown.roundedSuggestedBatchPrice
                        .toStringAsFixed(2),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _notifyParent();
                  },
                ),
              ),
              if (isCustom) ...[
                const SizedBox(width: 6),
                IconButton(
                  key: const Key('reset_batch_price_button'),
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Restaurar al precio sugerido',
                  color: AppColors.textMuted,
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () {
                    setState(() {
                      _customBatchPriceController.clear();
                    });
                    _notifyParent();
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Net Profit & Real Margin Rows
          _buildMetricRow(
            'Ganancia Neta:',
            '${breakdown.netProfitBatch >= PreciseDecimal.zero ? '+' : ''}${breakdown.netProfitBatch.toCurrencyString(symbol: widget.currencySymbol)}',
            valueColor: breakdown.netProfitBatch > PreciseDecimal.zero
                ? AppColors.profitGreen
                : AppColors.costRed,
          ),
          _buildMetricRow(
            _mode == PricingMode.markupOnCost ? 'Markup Real:' : 'Margen Real:',
            '${breakdown.realActiveMarginBatch.toStringAsFixed(1)}%',
            valueColor: breakdown.realActiveMarginBatch > PreciseDecimal.zero
                ? AppColors.profitGreen
                : AppColors.costRed,
          ),

          // Loss Protection Alert (BR-PRC-05)
          if (isLoss) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('batch_loss_alert_banner'),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.costRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.costRed),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.costRed, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '¡Alerta de venta a pérdida! El precio no cubre el costo de producción.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.costRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortionPricingCard(DualPricingBreakdown breakdown) {
    final isLoss = breakdown.isPortionAtLoss;
    final isCustom = breakdown.isPortionCustomPrice;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLoss ? AppColors.costRedLight : AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLoss ? AppColors.costRed : AppColors.borderWarm,
          width: isLoss ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.pie_chart_outline,
                      size: 18,
                      color: AppColors.profitGreen,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'PORCIÓN (${breakdown.yieldPortions} PZAS)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.textEspresso,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isCustom)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.honeyAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Manual',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDarkCaramel,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Costo Unitario por Porción
          _buildInfoRow(
            'Costo Unitario (CUP):',
            '${breakdown.portionCost.toCurrencyString(symbol: widget.currencySymbol)}${breakdown.yieldPortions > 1 ? ' / unidad' : ''}',
          ),
          // Precio Sugerido Porción
          _buildInfoRow(
            'Precio Sugerido Porción:',
            '${breakdown.roundedSuggestedPortionPrice.toCurrencyString(symbol: widget.currencySymbol)}${breakdown.yieldPortions > 1 ? ' / unidad' : ''}',
            subtitle: _roundingRule != RoundingRule.none
                ? '(Base: ${breakdown.rawSuggestedPortionPrice.toCurrencyString(symbol: widget.currencySymbol)})'
                : null,
          ),
          const SizedBox(height: 8),

          // Precio Final Efectivo Porción (Large Typographic Contrast >= 24sp)
          Text(
            breakdown.yieldPortions > 1
                ? 'Precio Final por Unidad / Envase:'
                : 'Precio Final Porción:',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('custom_portion_price_field'),
                  controller: _customPortionPriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                  style: const TextStyle(
                    fontSize: 24, // Minimum 24sp bold requirement
                    fontWeight: FontWeight.bold,
                    color: AppColors.profitGreen,
                  ),
                  decoration: InputDecoration(
                    prefixText: widget.currencySymbol,
                    prefixStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.profitGreen,
                    ),
                    hintText: breakdown.roundedSuggestedPortionPrice
                        .toStringAsFixed(2),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _notifyParent();
                  },
                ),
              ),
              if (isCustom) ...[
                const SizedBox(width: 6),
                IconButton(
                  key: const Key('reset_portion_price_button'),
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Restaurar al precio sugerido',
                  color: AppColors.textMuted,
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () {
                    setState(() {
                      _customPortionPriceController.clear();
                    });
                    _notifyParent();
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Net Profit Portion & Real Margin Rows
          _buildMetricRow(
            'Ganancia Unitaria:',
            '${breakdown.netProfitPortion >= PreciseDecimal.zero ? '+' : ''}${breakdown.netProfitPortion.toCurrencyString(symbol: widget.currencySymbol)}${breakdown.yieldPortions > 1 ? ' / unidad' : ''}',
            valueColor: breakdown.netProfitPortion > PreciseDecimal.zero
                ? AppColors.profitGreen
                : AppColors.costRed,
          ),
          _buildMetricRow(
            _mode == PricingMode.markupOnCost ? 'Markup Real:' : 'Margen Real:',
            '${breakdown.realActiveMarginPortion.toStringAsFixed(1)}%',
            valueColor: breakdown.realActiveMarginPortion > PreciseDecimal.zero
                ? AppColors.profitGreen
                : AppColors.costRed,
          ),

          if (breakdown.yieldPortions == 1) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.butterCream,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.primaryDarkCaramel,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rendimiento en 1 lote. Para ver el precio por vasito o cupcake, aumenta las unidades en Rendimiento.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textEspresso,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Loss Protection Alert (BR-PRC-05)
          if (isLoss) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('portion_loss_alert_banner'),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.costRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.costRed),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.costRed, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '¡Alerta de venta a pérdida! El precio fijado no cubre el costo por pieza.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.costRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              subtitle != null ? '$title $subtitle' : title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textEspresso,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textEspresso,
            ),
          ),
        ],
      ),
    );
  }
}
