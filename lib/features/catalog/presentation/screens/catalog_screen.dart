import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:costibake_app/core/constants/app_breakpoints.dart';
import 'package:costibake_app/core/theme/app_colors.dart';
import 'package:costibake_app/core/widgets/responsive_center.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../bloc/catalog_state.dart';
import 'ingredient_form_screen.dart';
import 'packaging_form_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;

  static const List<String> ingredientCategories = [
    'Todos',
    'Harinas y Secos',
    'Lácteos y Huevos',
    'Grasas y Mantequillas',
    'Chocolates y Cacao',
    'Azúcares y Endulzantes',
    'Frutas y Purés',
    'Levaduras e Impulsores',
    'Esencias y Colorantes',
    'Frutos Secos',
    'Otros',
  ];

  static const List<String> packagingCategories = [
    'Todos',
    'Cajas para Pastel',
    'Bases y Blondas',
    'Domos y Contenedores',
    'Capacillos y Pirotines',
    'Cintas y Decoración',
    'Bolsas y Mangas',
    'Otros Descartables',
  ];

  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController = TextEditingController();

    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    context.read<CatalogBloc>().add(
          const FilterCatalog(
            query: '',
            clearIngredientCategory: true,
            clearPackagingCategory: true,
          ),
        );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isPackagingTab = _currentTabIndex == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Recursos'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryCaramel,
          labelColor: AppColors.primaryCaramel,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Insumos y Materia Prima'),
            Tab(text: 'Empaques y Descartables'),
          ],
        ),
      ),
      body: BlocConsumer<CatalogBloc, CatalogState>(
        listener: (context, state) {
          if (state is CatalogLoaded && state.lastCascadeResult != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.lastCascadeResult!.userNotificationMessage),
                backgroundColor: AppColors.profitGreen,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CatalogLoading || state is CatalogInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CatalogError) {
            return Center(child: Text('Error: ${state.message}'));
          }

          if (state is CatalogLoaded) {
            return Column(
              children: [
                // Barra de Búsqueda y Filtros de Categoría
                _buildSearchAndFilters(state, isPackagingTab),

                // Contenido de la pestaña activa
                Expanded(
                  child: isPackagingTab
                      ? _buildPackagingsTab(state)
                      : _buildIngredientsTab(state),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final query = _searchController.text.trim();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => isPackagingTab
                  ? PackagingFormScreen(
                      initialName: query.isNotEmpty ? query : null,
                    )
                  : IngredientFormScreen(
                      initialName: query.isNotEmpty ? query : null,
                    ),
            ),
          );
        },
        backgroundColor: AppColors.primaryCaramel,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          isPackagingTab ? 'Nuevo Empaque' : 'Nuevo Insumo',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(CatalogLoaded state, bool isPackagingTab) {
    final currentCategories =
        isPackagingTab ? packagingCategories : ingredientCategories;
    final selectedCategory = isPackagingTab
        ? (state.packagingCategory ?? 'Todos')
        : (state.ingredientCategory ?? 'Todos');

    return ResponsiveCenter(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: Container(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            // Barra de búsqueda con botón de limpieza (RNF-01, BR-SRH-01, BR-SRH-02)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 50,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    context.read<CatalogBloc>().add(
                          FilterCatalog(query: val),
                        );
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: isPackagingTab
                        ? 'Buscar empaques, domos, cajas...'
                        : 'Buscar insumos, harinas, lácteos...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.primaryCaramel,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: AppColors.textMuted,
                            ),
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () {
                              _searchController.clear();
                              context.read<CatalogBloc>().add(
                                    const FilterCatalog(query: ''),
                                  );
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderWarm),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderWarm),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primaryCaramel,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Selector horizontal de categorías táctil (BR-SRH-03, RNF-01 >= 48px)
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: currentCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = currentCategories[index];
                  final isSelected = selectedCategory.toLowerCase() == cat.toLowerCase() ||
                      (selectedCategory == 'Todos' && cat == 'Todos');

                  return Center(
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.primaryCaramel,
                      backgroundColor: AppColors.surfaceCard,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textEspresso,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primaryCaramel
                              : AppColors.borderWarm,
                        ),
                      ),
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (isPackagingTab) {
                          context.read<CatalogBloc>().add(
                                FilterCatalog(
                                  packagingCategory:
                                      cat == 'Todos' ? null : cat,
                                  clearPackagingCategory: cat == 'Todos',
                                ),
                              );
                        } else {
                          context.read<CatalogBloc>().add(
                                FilterCatalog(
                                  ingredientCategory:
                                      cat == 'Todos' ? null : cat,
                                  clearIngredientCategory: cat == 'Todos',
                                ),
                              );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsTab(CatalogLoaded state) {
    // Si el catálogo está completamente vacío en SQLite
    if (state.allIngredients.isEmpty) {
      return Center(
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
                    builder: (_) => const IngredientFormScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Registrar Primer Insumo'),
            ),
          ],
        ),
      );
    }

    // Si hay insumos pero la búsqueda o filtro actual no arroja resultados (BR-SRH-04)
    if (state.ingredients.isEmpty) {
      final query = _searchController.text.trim();
      return _buildSearchEmptyState(
        itemType: 'Insumo',
        query: query,
        onCreatePressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IngredientFormScreen(
                initialName: query.isNotEmpty ? query : null,
              ),
            ),
          );
        },
      );
    }

    return ResponsiveCenter(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: 8,
          left: 16,
          right: 16,
          bottom: 80,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  if (!item.wastePercentage.isZero)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Merma: ${item.wastePercentage}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.costRed,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${item.minimumUnitCost.toStringAsFixed(4)}/${item.minimumUnit}',
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildPackagingsTab(CatalogLoaded state) {
    // Si el catálogo está completamente vacío en SQLite
    if (state.allPackagings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.all_inbox_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay empaques registrados.\nRegistra cajas, domos y blondas para costear.',
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
                    builder: (_) => const PackagingFormScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Registrar Primer Empaque'),
            ),
          ],
        ),
      );
    }

    // Si hay empaques pero la búsqueda o filtro actual no arroja resultados (BR-SRH-04)
    if (state.packagings.isEmpty) {
      final query = _searchController.text.trim();
      return _buildSearchEmptyState(
        itemType: 'Empaque',
        query: query,
        onCreatePressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PackagingFormScreen(
                initialName: query.isNotEmpty ? query : null,
              ),
            ),
          );
        },
      );
    }

    return ResponsiveCenter(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: 8,
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PackagingFormScreen(
                      packaging: item,
                    ),
                  ),
                );
              },
              title: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                    '${item.category} • Paquete: ${item.packageCost.toCurrencyString()} (${item.unitsPerPackage} pzas)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  if (item.notes != null && item.notes!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${item.unitCost.toStringAsFixed(4)}/u',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primaryDarkCaramel,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.unitCost.toCurrencyString()}/u',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchEmptyState({
    required String itemType,
    required String query,
    required VoidCallback onCreatePressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty
                  ? 'No se encontraron resultados para "$query"'
                  : 'No hay elementos en la categoría seleccionada',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textEspresso,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verifica la ortografía o registra este recurso directamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add),
              label: Text(
                query.isNotEmpty
                    ? 'Crear "$query" como $itemType'
                    : 'Crear nuevo $itemType',
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _clearSearchAndFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar Búsqueda y Filtros'),
            ),
          ],
        ),
      ),
    );
  }
}
