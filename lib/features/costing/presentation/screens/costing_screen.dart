import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../recipes/presentation/providers/recipes_providers.dart';
import '../../settings/presentation/providers/settings_providers.dart';
import '../../domain/services/cost_calculator.dart';

class CostingScreen extends ConsumerWidget {
  const CostingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesListProvider);
    final configAsync = ref.watch(businessConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Motor de Costeo y Márgenes'),
      ),
      body: recipesAsync.when(
        data: (recipes) {
          return configAsync.when(
            data: (config) {
              if (recipes.isEmpty) {
                return const Center(
                  child: Text(
                    'Formula al menos una receta para ver el análisis de rentabilidad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  final breakdown = CostCalculator.calculate(
                    recipe: recipe,
                    config: config,
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                recipe.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textEspresso,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.profitGreenLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '+${recipe.targetProfitMargin.toStringAsFixed(0)}% Markup',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.profitGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          // Quad Cost Elements Breakdown
                          _buildCostRow('Insumos Directos:',
                              breakdown.rawMaterialsCost.toCurrencyString(symbol: config.currencySymbol)),
                          _buildCostRow('Empaques Directos:',
                              breakdown.packagingCost.toCurrencyString(symbol: config.currencySymbol)),
                          _buildCostRow('Overhead (${config.overheadPercentage.toStringAsFixed(1)}%):',
                              breakdown.overheadCost.toCurrencyString(symbol: config.currencySymbol)),
                          _buildCostRow('Mano de Obra (${recipe.prepTimeMinutes} min):',
                              breakdown.laborCost.toCurrencyString(symbol: config.currencySymbol)),
                          const Divider(height: 16),
                          _buildCostRow(
                            'Costo Total de Producción:',
                            breakdown.totalProductionCost.toCurrencyString(symbol: config.currencySymbol),
                            isBold: true,
                          ),
                          const SizedBox(height: 12),
                          // Dual Pricing Card (Lote vs Porcion)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PRECIO LOTE SUGERIDO',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        breakdown.suggestedBatchPrice
                                            .toCurrencyString(symbol: config.currencySymbol),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryCaramel,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: AppColors.borderWarm,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PORCIÓN (${recipe.yieldPortions} PZAS)',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        breakdown.suggestedPortionPrice
                                            .toCurrencyString(symbol: config.currencySymbol),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.profitGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildCostRow(String title, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppColors.textEspresso : AppColors.textMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppColors.textEspresso : AppColors.textEspresso,
            ),
          ),
        ],
      ),
    );
  }
}
