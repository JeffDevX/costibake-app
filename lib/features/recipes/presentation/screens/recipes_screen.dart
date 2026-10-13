import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:costibake_app/core/constants/app_breakpoints.dart';
import 'package:costibake_app/core/constants/app_constants.dart';
import 'package:costibake_app/core/theme/app_colors.dart';
import 'package:costibake_app/core/widgets/responsive_center.dart';
import '../bloc/recipes_bloc.dart';
import '../bloc/recipes_state.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recetario Paramétrico'),
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
            final recipes = state.recipes;
            if (recipes.isEmpty) {
              return const Center(
                child: Text(
                  'No hay recetas formuladas.\nCrea tu primera receta con prorrateo de insumos.',
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
                  final isIncomplete =
                      recipe.status == AppConstants.recipeStatusIncomplete;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              recipe.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (isIncomplete) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.costRedLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'REVISIÓN REQUERIDA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.costRed,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${recipe.yieldPortions} porciones • ${recipe.totalTimeMinutes} min de preparación'
                        '${recipe.moldDimension != null ? ' • Molde ${recipe.moldDimension}' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
