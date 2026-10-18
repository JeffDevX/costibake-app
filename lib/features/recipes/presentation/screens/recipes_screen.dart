import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../catalog/domain/repositories/ingredient_repository.dart';
import '../../domain/entities/ai_recipe_extraction.dart';
import '../../domain/services/ai_recipe_extractor.dart';
import '../../domain/services/ingredient_catalog_matcher.dart';
import '../bloc/recipes_bloc.dart';
import '../bloc/recipes_event.dart';
import '../bloc/recipes_state.dart';
import '../widgets/missing_ingredients_wizard_dialog.dart';
import '../widgets/recipe_pdf_export_dialog.dart';
import 'ai_recipe_preview_screen.dart';
import 'recipe_form_screen.dart';
import 'recipe_scaling_screen.dart';

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

  Future<void> _openAiScanModal(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.butterCream,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primaryCaramel,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ingesta de Receta con IA',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textEspresso,
                            ),
                          ),
                          Text(
                            'Extrae ingredientes, porciones y costos al instante',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                ListTile(
                  key: const Key('tile_scan_camera'),
                  leading: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.primaryCaramel),
                  title: const Text('Tomar Foto de Cuaderno o Recetario'),
                  subtitle: const Text('Cámara en tiempo real'),
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _processImageSource(context, ImageSource.camera);
                  },
                ),
                ListTile(
                  key: const Key('tile_scan_gallery'),
                  leading: const Icon(Icons.photo_library_rounded,
                      color: AppColors.honeyAccent),
                  title: const Text('Subir Foto desde Galería'),
                  subtitle: const Text('Imágenes JPEG, PNG, WEBP'),
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _processImageSource(context, ImageSource.gallery);
                  },
                ),
                ListTile(
                  key: const Key('tile_scan_pdf'),
                  leading: const Icon(Icons.picture_as_pdf_rounded,
                      color: AppColors.costRed),
                  title: const Text('Subir Documento PDF'),
                  subtitle: const Text('Archivos digitales .pdf'),
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _processPdfDocument(context);
                  },
                ),
                ListTile(
                  key: const Key('tile_scan_docx'),
                  leading: const Icon(Icons.description_rounded,
                      color: AppColors.infoBlue),
                  title: const Text('Subir Documento Word (DOCX)'),
                  subtitle: const Text('Archivos .docx de Office'),
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _processDocxDocument(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleExtractedRecipe(
    BuildContext context,
    Future<AiRecipeExtraction> Function() extractionTask,
  ) async {
    final ingredientRepo = context.read<IngredientRepository>();
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Analizando receta con Inteligencia Artificial...\nEsto puede tomar unos segundos.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final rawExtraction = await extractionTask();
      final catalog = await ingredientRepo.getAllIngredients();
      final matchedExtraction = IngredientCatalogMatcher.matchExtraction(
        extraction: rawExtraction,
        catalog: catalog,
      );

      navigator.pop();

      AiRecipeExtraction fullyResolved = matchedExtraction;
      if (matchedExtraction.unresolvedIngredientsCount > 0 && context.mounted) {
        final resolvedFromWizard =
            await MissingIngredientsWizardDialog.show(
          context: context,
          extraction: matchedExtraction,
          catalog: catalog,
          ingredientRepository: ingredientRepo,
        );

        if (resolvedFromWizard == null) return;
        fullyResolved = resolvedFromWizard;
      }

      if (context.mounted) {
        final refreshedCatalog = await ingredientRepo.getAllIngredients();
        if (context.mounted) {
          await AiRecipePreviewScreen.show(
            context: context,
            extraction: fullyResolved,
            catalog: refreshedCatalog,
          );
        }
      }
    } catch (e) {
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error al procesar la receta: $e'),
          backgroundColor: AppColors.costRed,
        ),
      );
    }
  }

  Future<void> _processImageSource(
      BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? 'image/jpeg';

      if (!context.mounted) return;
      final extractor = context.read<AiRecipeExtractor>();

      await _handleExtractedRecipe(
        context,
        () => extractor.extractFromImage(imageBytes: bytes, mimeType: mime),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar la imagen: $e'),
            backgroundColor: AppColors.costRed,
          ),
        );
      }
    }
  }

  Future<void> _processPdfDocument(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      if (!context.mounted) return;
      final extractor = context.read<AiRecipeExtractor>();

      await _handleExtractedRecipe(
        context,
        () => extractor.extractFromPdf(pdfBytes: bytes),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir el documento PDF: $e'),
            backgroundColor: AppColors.costRed,
          ),
        );
      }
    }
  }

  Future<void> _processDocxDocument(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      if (!context.mounted) return;
      final extractor = context.read<AiRecipeExtractor>();

      await _handleExtractedRecipe(
        context,
        () => extractor.extractFromDocx(docxBytes: bytes),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir el documento Word: $e'),
            backgroundColor: AppColors.costRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recetario Paramétrico'),
        actions: [
          IconButton(
            key: const Key('btn_scan_recipe_ai'),
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: 'Escanear Receta con IA',
            onPressed: () => _openAiScanModal(context),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            key: const Key('btn_scan_recipe_ai_fab'),
            heroTag: 'fab_scan_ai',
            onPressed: () => _openAiScanModal(context),
            backgroundColor: AppColors.butterCream,
            icon: const Icon(Icons.auto_awesome,
                color: AppColors.primaryCaramel),
            label: const Text(
              'Escanear con IA',
              style: TextStyle(
                color: AppColors.primaryDarkCaramel,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            key: const Key('btn_add_recipe'),
            heroTag: 'fab_add_recipe',
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
        ],
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
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 12,
                                        runSpacing: 10,
                                        children: [
                                          OutlinedButton.icon(
                                            key: const Key('btn_empty_scan_ai'),
                                            onPressed: () =>
                                                _openAiScanModal(context),
                                            icon: const Icon(Icons.auto_awesome,
                                                color: AppColors.primaryCaramel),
                                            label: const Text('Escanear con IA'),
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(160,
                                                  AppConstants.minTouchTargetSize),
                                            ),
                                          ),
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
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryCaramel,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(160,
                                                  AppConstants.minTouchTargetSize),
                                            ),
                                          ),
                                        ],
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
