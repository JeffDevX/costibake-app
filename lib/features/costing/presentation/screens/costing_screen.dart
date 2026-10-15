import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:costibake_app/core/constants/app_breakpoints.dart';
import 'package:costibake_app/core/theme/app_colors.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/core/widgets/responsive_center.dart';
import 'package:costibake_app/features/costing/domain/entities/pricing_strategy.dart';
import 'package:costibake_app/features/costing/domain/services/cost_calculator.dart';
import 'package:costibake_app/features/costing/presentation/widgets/cost_distribution_widget.dart';
import 'package:costibake_app/features/costing/presentation/widgets/dual_pricing_card.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_event.dart';
import 'package:costibake_app/features/recipes/presentation/bloc/recipes_state.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_state.dart';

class CostingScreen extends StatelessWidget {
  const CostingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motor de Costeo y Márgenes'),
      ),
      body: BlocBuilder<RecipesBloc, RecipesState>(
        builder: (context, recipesState) {
          if (recipesState is RecipesLoading || recipesState is RecipesInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (recipesState is RecipesError) {
            return Center(child: Text('Error: ${recipesState.message}'));
          }

          if (recipesState is RecipesLoaded) {
            final recipes = recipesState.recipes;

            return BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, settingsState) {
                if (settingsState is SettingsLoading || settingsState is SettingsInitial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (settingsState is SettingsError) {
                  return Center(child: Text('Error: ${settingsState.message}'));
                }

                if (settingsState is SettingsLoaded) {
                  final config = settingsState.config;

                  if (recipes.isEmpty) {
                    return const Center(
                      child: Text(
                        'Formula al menos una receta para ver el análisis de rentabilidad.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                      ),
                    );
                  }

                  return ResponsiveCenter(
                    maxWidth: AppBreakpoints.maxContentWidth,
                    child: ListView.builder(
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
                                    Expanded(
                                      child: Text(
                                        recipe.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textEspresso,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.profitGreenLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        recipe.pricingMode == PricingMode.markupOnCost
                                            ? '+${recipe.targetProfitMargin.toStringAsFixed(0)}% Markup'
                                            : '+${recipe.targetProfitMargin.toStringAsFixed(0)}% Margen Venta',
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
                                // Quad Cost Elements Breakdown (JEF-15)
                                _buildCostRow('Insumos Directos (CI):',
                                    breakdown.rawMaterialsCost.toCurrencyString(symbol: config.currencySymbol)),
                                if (breakdown.subRecipesCost > PreciseDecimal.zero)
                                  _buildCostRow('Sub-recetas Modulares:',
                                      breakdown.subRecipesCost.toCurrencyString(symbol: config.currencySymbol)),
                                _buildCostRow('Empaques Directos (CE):',
                                    breakdown.packagingCost.toCurrencyString(symbol: config.currencySymbol)),
                                _buildCostRow('Overhead (${breakdown.effectiveOverheadPercentage.toStringAsFixed(1)}%):',
                                    breakdown.overheadCost.toCurrencyString(symbol: config.currencySymbol)),
                                _buildCostRow('Mano de Obra (${recipe.prepTimeMinutes} min @ ${breakdown.effectiveLaborRatePerHour.toCurrencyString(symbol: config.currencySymbol)}/h):',
                                    breakdown.laborCost.toCurrencyString(symbol: config.currencySymbol)),
                                const Divider(height: 16),
                                _buildCostRow(
                                  'Costo Total de Producción (CTP):',
                                  breakdown.totalProductionCost.toCurrencyString(symbol: config.currencySymbol),
                                  isBold: true,
                                ),
                                const SizedBox(height: 14),
                                // Visual Distribution Progress Bar & Legend (JEF-15)
                                CostDistributionWidget(
                                  breakdown: breakdown,
                                  currencySymbol: config.currencySymbol,
                                ),
                                const SizedBox(height: 14),
                                // Interactive Dual Pricing Card (JEF-16)
                                DualPricingCard(
                                  key: Key('costing_dual_pricing_${recipe.id}'),
                                  totalProductionCost:
                                      breakdown.totalProductionCost,
                                  yieldPortions: breakdown.yieldPortions,
                                  currencySymbol: config.currencySymbol,
                                  initialStrategy: recipe.pricingStrategy,
                                  onStrategyChanged: (newStrategy) {
                                    final updatedRecipe = recipe.copyWith(
                                      pricingMode: newStrategy.mode,
                                      targetProfitMargin:
                                          newStrategy.targetProfitMargin,
                                      roundingRule: newStrategy.roundingRule,
                                      customBatchPrice:
                                          newStrategy.customBatchPrice,
                                      clearCustomBatchPrice:
                                          newStrategy.customBatchPrice == null,
                                      customPortionPrice:
                                          newStrategy.customPortionPrice,
                                      clearCustomPortionPrice:
                                          newStrategy.customPortionPrice == null,
                                    );
                                    context
                                        .read<RecipesBloc>()
                                        .add(UpdateRecipe(updatedRecipe));
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildCostRow(String title, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? AppColors.textEspresso : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.end,
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
