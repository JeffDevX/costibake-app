import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_state.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catálogo de Recursos'),
          bottom: const TabBar(
            indicatorColor: AppColors.primaryCaramel,
            labelColor: AppColors.primaryCaramel,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              Tab(text: 'Insumos y Materia Prima'),
              Tab(text: 'Empaques y Descartables'),
            ],
          ),
        ),
        body: BlocBuilder<CatalogBloc, CatalogState>(
          builder: (context, state) {
            if (state is CatalogLoading || state is CatalogInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is CatalogError) {
              return Center(child: Text('Error: ${state.message}'));
            }

            if (state is CatalogLoaded) {
              return TabBarView(
                children: [
                  // Ingredients Tab
                  state.ingredients.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay insumos registrados.\nAgrega compras a granel para comenzar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.ingredients.length,
                          itemBuilder: (context, index) {
                            final item = state.ingredients[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${item.category} • Compra: ${item.purchaseCost.toCurrencyString()} / ${item.purchaseQuantity} ${item.purchaseUnit}',
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${item.minimumUnitCost.toCurrencyString()}/${item.minimumUnit}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDarkCaramel,
                                      ),
                                    ),
                                    if (!item.wastePercentage.isZero)
                                      Text(
                                        'Merma: ${item.wastePercentage.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.warningAmber,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                  // Packaging Tab
                  state.packagings.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay empaques registrados.\nRegistra cajas, domos y blondas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.packagings.length,
                          itemBuilder: (context, index) {
                            final item = state.packagings[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${item.category} • Paquete: ${item.packageCost.toCurrencyString()} (${item.unitsPerPackage} pzas)',
                                ),
                                trailing: Text(
                                  '${item.unitCost.toCurrencyString()}/u',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDarkCaramel,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
