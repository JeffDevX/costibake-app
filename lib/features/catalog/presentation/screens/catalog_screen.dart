import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/catalog_providers.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(ingredientsListProvider);
    final packagingAsync = ref.watch(packagingListProvider);

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
        body: TabBarView(
          children: [
            // Ingredients Tab
            ingredientsAsync.when(
              data: (ingredients) {
                if (ingredients.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay insumos registrados.\nAgrega compras a granel para comenzar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ingredients.length,
                  itemBuilder: (context, index) {
                    final item = ingredients[index];
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
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
            // Packaging Tab
            packagingAsync.when(
              data: (packagings) {
                if (packagings.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay empaques registrados.\nRegistra cajas, domos y blondas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: packagings.length,
                  itemBuilder: (context, index) {
                    final item = packagings[index];
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
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ],
        ),
      ),
    );
  }
}
