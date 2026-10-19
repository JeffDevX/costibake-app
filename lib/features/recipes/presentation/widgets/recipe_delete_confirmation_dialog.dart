import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../bloc/recipes_bloc.dart';
import '../bloc/recipes_event.dart';

/// Reusable confirmation dialog for deleting recipes safely.
/// Verifies sub-recipe dependency protection to prevent breaking parent recipes.
class RecipeDeleteConfirmationDialog {
  /// Displays a confirmation dialog to delete a recipe.
  /// If the recipe is used as a sub-recipe in any other recipe, a protective
  /// warning dialog is displayed preventing deletion until it is unlinked.
  static Future<bool> show(
    BuildContext context, {
    required Recipe recipe,
    VoidCallback? onDeleted,
  }) async {
    // 1. Check if the recipe is used as a subrecipe in other recipes
    RecipeRepository? recipeRepo;
    try {
      recipeRepo = context.read<RecipeRepository>();
    } catch (_) {}

    if (recipeRepo != null) {
      try {
        final subRecipeGraph = await recipeRepo.getSubRecipeDependencyGraph();
        final parentRecipeIds = subRecipeGraph.entries
            .where((entry) => entry.value.contains(recipe.id))
            .map((e) => e.key)
            .toList();

        if (parentRecipeIds.isNotEmpty && context.mounted) {
          final allRecipes = await recipeRepo.getAllRecipes();
          if (!context.mounted) return false;
          final parentNames = allRecipes
              .where((r) => parentRecipeIds.contains(r.id))
              .map((r) => '• ${r.name}')
              .join('\n');

          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              key: const Key('dialog_subrecipe_protection'),
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.costRed),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Receta en Uso como Sub-receta',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Text(
                'No se puede eliminar la receta "${recipe.name}" porque está incluida como sub-receta en las siguientes recetas:\n\n$parentNames\n\nDebes desvincularla de esas recetas antes de poder eliminarla.',
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  key: const Key('btn_close_subrecipe_protection_dialog'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(80, AppConstants.minTouchTargetSize),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
          return false;
        }
      } catch (_) {
        // Fall through to standard confirmation if graph check is unavailable
      }
    }

    if (!context.mounted) return false;

    // 2. Standard confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('dialog_confirm_delete_recipe'),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.costRed),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿Eliminar Receta?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente la receta "${recipe.name}"? Esta acción eliminará su costeo y no se puede deshacer.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            key: const Key('btn_cancel_delete_recipe'),
            style: TextButton.styleFrom(
              minimumSize: const Size(80, AppConstants.minTouchTargetSize),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            key: const Key('btn_confirm_delete_recipe'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.costRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, AppConstants.minTouchTargetSize),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<RecipesBloc>().add(DeleteRecipe(recipe.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receta "${recipe.name}" eliminada correctamente.'),
          backgroundColor: AppColors.textEspresso,
          duration: const Duration(seconds: 3),
        ),
      );
      onDeleted?.call();
      return true;
    }

    return false;
  }
}
