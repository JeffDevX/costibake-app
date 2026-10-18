import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../bloc/recipes_bloc.dart';
import '../bloc/recipes_event.dart';
import '../bloc/recipes_state.dart';
import 'recipe_form_screen.dart';
import 'recipe_scaling_screen.dart';
import '../widgets/recipe_pdf_export_dialog.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<RecipesBloc>().add(
          FilterRecipes(
            query: query,
            status: _selectedStatusFilter.isEmpty ? null : _selectedStatusFilter,
          ),
        );
  }

  void _onStatusFilterSelected(String status) {
    setState(() {
      _selectedStatusFilter = _selectedStatusFilter == status ? '' : status;
    });
    context.read<RecipesBloc>().add(
          FilterRecipes(
            query: _searchController.text,
            status: _selectedStatusFilter.isEmpty ? null : _selectedStatusFilter,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recetario Paramétrico'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('btn_add_recipe'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecipeFormScreen()),
          );
        },
        backgroundColor: AppColors.primaryCaramel,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nueva Receta',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: BlocBuilder<RecipesBloc, RecipesState>(
        builder: (context, state) {
          if (state is RecipesLoading || state is RecipesInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is RecipesError) {
            return Center(child: Text('Error: ${state.message}'));
          }

          if (state is RecipesLoaded) {
            final recipes = state.filteredRecipes;
            final allRecipesCount = state.recipes.length;

            return ResponsiveCenter(
              maxWidth: AppBreakpoints.maxContentWidth,
              child: Column(
                children: [
                  // Search and Filter Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar recetas...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.borderSubtle),
                            ),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                        const SizedBox(height: 8),

                        // Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('Todas'),
                                selected: _selectedStatusFilter.isEmpty,
                                onSelected: (_) => _onStatusFilterSelected(''),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Activas'),
                                selected: _selectedStatusFilter ==
                                    AppConstants.recipeStatusActive,
                                onSelected: (_) => _onStatusFilterSelected(
                                    AppConstants.recipeStatusActive),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Borrador'),
                                selected: _selectedStatusFilter ==
                                    AppConstants.recipeStatusDraft,
                                onSelected: (_) => _onStatusFilterSelected(
                                    AppConstants.recipeStatusDraft),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('Requiere Revisión'),
                                selected: _selectedStatusFilter ==
                                    AppConstants.recipeStatusIncomplete,
                                onSelected: (_) => _onStatusFilterSelected(
                                    AppConstants.recipeStatusIncomplete),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Recipes List
                  Expanded(
                    child: recipes.isEmpty
                        ? (allRecipesCount == 0
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.menu_book,
                                          size: 56, color: AppColors.textMuted),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No hay recetas formuladas.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.textEspresso,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Crea tu primera receta modular con prorrateo automático de ingredientes y costos.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton.icon(
                                        key: const Key('btn_empty_create_recipe'),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const RecipeFormScreen()),
                                          );
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('Formular Receta'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const Center(
                                child: Text(
                                  'No se encontraron recetas con los filtros aplicados.',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 16),
                                ),
                              ))
                        : ListView.builder(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: recipes.length,
                            itemBuilder: (context, index) {
                              final recipe = recipes[index];
                              final isIncomplete = recipe.status ==
                                      AppConstants.recipeStatusIncomplete ||
                                  recipe.hasOrphanedItems;
                              final isDraft = recipe.status ==
                                  AppConstants.recipeStatusDraft;

                              return Card(
                                key: Key('recipe_card_${recipe.id}'),
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isIncomplete
                                      ? BorderSide(
                                          color: AppColors.costRed
                                              .withValues(alpha: 0.5),
                                          width: 1.5,
                                        )
                                      : BorderSide.none,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RecipeFormScreen(
                                            recipeToEdit: recipe),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (isIncomplete) ...[
                                              const Icon(
                                                Icons.warning_amber_rounded,
                                                color: AppColors.costRed,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Expanded(
                                              child: Text(
                                                recipe.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            if (isIncomplete) ...[
                                              Container(
                                                key: Key(
                                                    'badge_incomplete_recipe_${recipe.id}'),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.costRedLight,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'REVISIÓN REQUERIDA',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.costRed,
                                                  ),
                                                ),
                                              ),
                                            ] else if (isDraft) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceHighlight,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'BORRADOR',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        // Subtitle info
                                        Text(
                                          '${recipe.yieldPortions} porciones • ${recipe.totalTimeMinutes} min de preparación'
                                          '${recipe.moldDimension != null ? ' • Molde ${recipe.moldDimension}' : ''}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Badges: modular components count & cost
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppColors.butterCream,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${recipe.ingredients.length} insumos'
                                                  '${recipe.subRecipes.isNotEmpty ? ' • ${recipe.subRecipes.length} sub-recetas' : ''}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors
                                                        .primaryDarkCaramel,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (isIncomplete)
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    const Text(
                                                      'Receta Incompleta',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                        color:
                                                            AppColors.costRed,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Precio sugerido deshabilitado',
                                                      key: Key(
                                                          'incomplete_price_warning_${recipe.id}'),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.costRed,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      'Lote: \$${recipe.totalDirectCost.toStringAsFixed(2)}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: AppColors
                                                            .textEspresso,
                                                      ),
                                                    ),
                                                    if (recipe.yieldPortions >
                                                        1) ...[
                                                      Text(
                                                        '\$${(recipe.totalDirectCost / PreciseDecimal.fromInt(recipe.yieldPortions)).toStringAsFixed(2)} / porción',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppColors
                                                              .primaryDarkCaramel,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Wrap(
                                            alignment: WrapAlignment.end,
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              TextButton.icon(
                                                key: Key('btn_export_pdf_${recipe.id}'),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  minimumSize: const Size(48, 36),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: () {
                                                  RecipePdfExportDialog.show(
                                                    context,
                                                    recipe: recipe,
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.picture_as_pdf_outlined,
                                                  size: 16,
                                                  color: AppColors.primaryCaramel,
                                                ),
                                                label: const Text(
                                                  'Exportar PDF',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primaryCaramel,
                                                  ),
                                                ),
                                              ),
                                              TextButton.icon(
                                                key: Key('btn_scale_recipe_${recipe.id}'),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  minimumSize: const Size(48, 36),
                                                  tapTargetSize:
                                                      MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          RecipeScalingScreen(
                                                              recipe: recipe),
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.aspect_ratio_outlined,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Escalar Receta / Molde',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
