import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../bloc/catalog_state.dart';
import 'ingredient_form_screen.dart';

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
                  // Tab 1: Insumos y Materia Prima
                  state.ingredients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay insumos registrados.\nAgrega compras a granel para comenzar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const IngredientFormScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Registrar Primer Insumo'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            top: 16,
                            left: 16,
                            right: 16,
                            bottom: 80, // espacio para el FAB
                          ),
                          itemCount: state.ingredients.length,
                          itemBuilder: (context, index) {
                            final item = state.ingredients[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => IngredientFormScreen(
                                        ingredient: item,
                                      ),
                                    ),
                                  );
                                },
                                title: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.category} • Compra: ${item.purchaseCost.toCurrencyString()} / ${item.purchaseQuantity} ${item.purchaseUnit}',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (!item.wastePercentage.isZero)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Merma: ${item.wastePercentage.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.warningAmber,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${item.minimumUnitCost.toStringAsFixed(6)}/${item.minimumUnit}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.primaryDarkCaramel,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.minimumUnitCost.toCurrencyString()}/${item.minimumUnit}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                  // Tab 2: Empaques y Descartables
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
                          padding: const EdgeInsets.only(
                            top: 16,
                            left: 16,
                            right: 16,
                            bottom: 80,
                          ),
                          itemCount: state.packagings.length,
                          itemBuilder: (context, index) {
                            final item = state.packagings[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const IngredientFormScreen(),
              ),
            );
          },
          backgroundColor: AppColors.primaryCaramel,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Nuevo Insumo',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
