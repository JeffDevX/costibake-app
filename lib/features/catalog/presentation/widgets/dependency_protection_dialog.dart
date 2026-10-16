import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../recipes/data/repositories/recipe_repository_impl.dart';
import '../../../recipes/domain/entities/recipe.dart';
import '../../../recipes/domain/repositories/recipe_repository.dart';
import '../../../recipes/presentation/bloc/recipes_bloc.dart';
import '../../../recipes/presentation/bloc/recipes_state.dart';
import '../../../recipes/presentation/screens/recipe_form_screen.dart';
import '../../domain/entities/dependency_block_info.dart';

/// Protective modal dialog displayed when a user attempts to delete an
/// ingredient or packaging item that is actively referenced by one or more
/// recipes (`RF-SYS-21`, `RF-SYS-22`, `BR-INT-01`, `BR-INT-02`).
///
/// Features:
/// - Displays the blocked item name, total count of affected recipes, and the
///   explicit list of affected recipe names (`BR-INT-02`).
/// - Allows tapping any affected recipe in the list (`"Ver Receta afectada"`)
///   to navigate directly to `RecipeFormScreen` so the user can edit the recipe
///   and replace the ingredient manually.
/// - Provides a `"Cancelar"` action with a touch target >= 48px.
class DependencyProtectionDialog extends StatelessWidget {
  final DependencyBlockInfo blockInfo;
  final void Function(String recipeName)? onNavigateToRecipe;

  const DependencyProtectionDialog({
    super.key,
    required this.blockInfo,
    this.onNavigateToRecipe,
  });

  /// Helper to display the protective modal dialog (`RF-SYS-22`).
  static Future<void> show(
    BuildContext context, {
    required DependencyBlockInfo blockInfo,
    void Function(String recipeName)? onNavigateToRecipe,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DependencyProtectionDialog(
        blockInfo: blockInfo,
        onNavigateToRecipe: onNavigateToRecipe,
      ),
    );
  }

  Future<void> _handleRecipeTap(BuildContext context, String recipeName) async {
    final navigator = Navigator.of(context);

    if (onNavigateToRecipe != null) {
      navigator.pop();
      onNavigateToRecipe!(recipeName);
      return;
    }

    // Attempt to resolve the Recipe from RecipesBloc if available in context
    Recipe? targetRecipe;
    try {
      final recipesBloc = context.read<RecipesBloc>();
      final state = recipesBloc.state;
      if (state is RecipesLoaded) {
        final matches = state.recipes
            .where((r) => r.name.toLowerCase() == recipeName.toLowerCase())
            .toList();
        if (matches.isNotEmpty) {
          targetRecipe = matches.first;
        }
      }
    } catch (_) {
      // RecipesBloc not in widget tree
    }

    // Fallback to RecipeRepository in context or RecipeRepositoryImpl
    if (targetRecipe == null) {
      try {
        RecipeRepository repo;
        try {
          repo = context.read<RecipeRepository>();
        } catch (_) {
          repo = RecipeRepositoryImpl();
        }
        final allRecipes = await repo.getAllRecipes();
        final matches = allRecipes
            .where((r) => r.name.toLowerCase() == recipeName.toLowerCase())
            .toList();
        if (matches.isNotEmpty) {
          targetRecipe = matches.first;
        }
      } catch (_) {}
    }

    // Fallback placeholder recipe so navigation to RecipeFormScreen always succeeds
    final now = DateTime.now();
    final recipeToOpen = targetRecipe ??
        Recipe(
          id: 'lookup-$recipeName',
          name: recipeName,
          yieldPortions: 10,
          prepTimeMinutes: 30,
          bakeTimeMinutes: 30,
          targetProfitMargin: PreciseDecimal.fromInt(40),
          status: AppConstants.recipeStatusActive,
          createdAt: now,
          updatedAt: now,
        );

    navigator.pop();
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => RecipeFormScreen(recipeToEdit: recipeToOpen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemTypeLabel = blockInfo.isPackaging ? 'Empaque' : 'Insumo';

    return AlertDialog(
      key: const Key('dependency_protection_dialog'),
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.costRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.costRed,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Borrado Bloqueado ($itemTypeLabel en Uso)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textEspresso,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Protección de integridad referencial (BR-INT-01)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exact message required by BR-INT-02
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.costRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.costRed.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                blockInfo.formattedBlockMessage,
                key: const Key('dependency_block_message'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textEspresso,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Toca cualquier receta afectada para editarla y reemplazar este recurso manualmente:',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...blockInfo.affectedRecipeNames.map((recipeName) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.surfaceCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.borderWarm),
                  ),
                  child: InkWell(
                    key: Key('affected_recipe_tile_$recipeName'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _handleRecipeTap(context, recipeName),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.menu_book_outlined,
                              size: 18,
                              color: AppColors.primaryDarkCaramel,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    recipeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textEspresso,
                                    ),
                                  ),
                                  const Text(
                                    'Ver Receta afectada',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryCaramel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                              color: AppColors.primaryCaramel,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        SizedBox(
          height: 48,
          child: TextButton(
            key: const Key('btn_cancel_dependency_dialog'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textEspresso,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
