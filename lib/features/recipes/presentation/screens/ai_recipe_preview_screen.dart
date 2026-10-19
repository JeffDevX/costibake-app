import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/culinary_units.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../catalog/domain/entities/ingredient.dart';
import '../../domain/entities/ai_recipe_extraction.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_item.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../bloc/recipes_bloc.dart';
import '../bloc/recipes_event.dart';
import 'recipe_form_screen.dart';

/// Screen allowing the baker to inspect, fine-tune, and verify an AI-extracted recipe,
/// seeing instant preliminary ingredient costs and saving directly with full costing math.
/// Implements BR-IA-09, BR-IA-10, BR-IA-11.
class AiRecipePreviewScreen extends StatefulWidget {
  final AiRecipeExtraction extraction;
  final List<Ingredient> catalog;

  const AiRecipePreviewScreen({
    super.key,
    required this.extraction,
    required this.catalog,
  });

  static Future<void> show({
    required BuildContext context,
    required AiRecipeExtraction extraction,
    required List<Ingredient> catalog,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiRecipePreviewScreen(
          extraction: extraction,
          catalog: catalog,
        ),
      ),
    );
  }

  @override
  State<AiRecipePreviewScreen> createState() => _AiRecipePreviewScreenState();
}

class _AiRecipePreviewScreenState extends State<AiRecipePreviewScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _yieldPortionsController;
  late TextEditingController _prepTimeController;
  late TextEditingController _bakeTimeController;
  late TextEditingController _moldDimensionController;
  late TextEditingController _notesController;

  String? _moldType;
  late List<AiExtractedIngredient> _ingredients;
  bool _isSaving = false;

  late final List<String> _moldTypes;

  @override
  void initState() {
    super.initState();
    final ext = widget.extraction;
    _titleController = TextEditingController(text: ext.title);
    _yieldPortionsController =
        TextEditingController(text: ext.yieldPortions.toString());
    _yieldPortionsController.addListener(() => setState(() {}));
    _prepTimeController =
        TextEditingController(text: ext.prepTimeMinutes.toString());
    _bakeTimeController =
        TextEditingController(text: ext.bakeTimeMinutes.toString());
    _moldDimensionController =
        TextEditingController(text: ext.moldDimension ?? '');

    // Combine steps and notes into description
    final buffer = StringBuffer();
    if (ext.notes != null && ext.notes!.trim().isNotEmpty) {
      buffer.writeln('Notas: ${ext.notes!.trim()}\n');
    }
    if (ext.steps.isNotEmpty) {
      buffer.writeln('Instrucciones de Elaboración:');
      for (int i = 0; i < ext.steps.length; i++) {
        buffer.writeln('${i + 1}. ${ext.steps[i]}');
      }
    }
    _notesController = TextEditingController(text: buffer.toString().trim());

    _moldTypes = List<String>.from(AppConstants.standardMoldTypes);
    final extMold = ext.moldType?.trim();
    if (extMold != null && extMold.isNotEmpty && !_moldTypes.contains(extMold)) {
      _moldTypes.insert(_moldTypes.length - 1, extMold);
    }
    _moldType = (extMold != null && extMold.isNotEmpty)
        ? extMold
        : _moldTypes.first;

    _ingredients = List.from(ext.ingredients);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yieldPortionsController.dispose();
    _prepTimeController.dispose();
    _bakeTimeController.dispose();
    _moldDimensionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Ingredient? _getCatalogIngredient(String? id) {
    if (id == null) return null;
    return widget.catalog.where((c) => c.id == id).firstOrNull;
  }

  PreciseDecimal _calculateItemCost(AiExtractedIngredient item) {
    final catalogItem = _getCatalogIngredient(item.matchedCatalogIngredientId);
    if (catalogItem == null) return PreciseDecimal.zero;

    try {
      final targetUnit = catalogItem.minimumUnit;
      final normalizedQty = UnitConverter.convertUnit(
        item.quantity,
        item.unit,
        targetUnit,
        density: catalogItem.densityGPerMl,
      );
      return normalizedQty * catalogItem.minimumUnitCost;
    } catch (_) {
      return item.quantity * catalogItem.minimumUnitCost;
    }
  }

  PreciseDecimal get _totalIngredientsCost {
    PreciseDecimal total = PreciseDecimal.zero;
    for (final ing in _ingredients) {
      total += _calculateItemCost(ing);
    }
    return total;
  }

  PreciseDecimal get _costPerPortion {
    final portions = int.tryParse(_yieldPortionsController.text) ?? 1;
    if (portions <= 0) return _totalIngredientsCost;
    return _totalIngredientsCost / PreciseDecimal.fromInt(portions);
  }

  void _editIngredient(int index) {
    final item = _ingredients[index];
    final nameController = TextEditingController(text: item.name);
    final qtyController =
        TextEditingController(text: item.quantity.toString());
    final unitController = TextEditingController(text: item.unit);
    final sectionController = TextEditingController(text: item.section);
    final notesController = TextEditingController(text: item.notes ?? '');

    CulinaryUnit? matchedUnit = CulinaryUnit.tryParse(item.unit);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            key: const Key('dialog_edit_ai_ingredient'),
            title: Row(
              children: [
                const Icon(Icons.edit_note, color: AppColors.primaryCaramel),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editar Insumo: ${item.name}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('field_ai_edit_ingredient_name'),
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Insumo',
                      prefixIcon: Icon(Icons.egg_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          key: const Key('field_ai_edit_ingredient_qty'),
                          controller: qtyController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cantidad',
                            prefixIcon: Icon(Icons.scale_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<CulinaryUnit>(
                          key: const Key('dropdown_ai_edit_ingredient_unit'),
                          initialValue: matchedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unidad',
                            border: OutlineInputBorder(),
                          ),
                          items: CulinaryUnit.values.map((u) {
                            return DropdownMenuItem(
                              value: u,
                              child: Text(u.symbol),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                matchedUnit = val;
                                unitController.text = val.symbol;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('field_ai_edit_ingredient_section'),
                    controller: sectionController,
                    decoration: const InputDecoration(
                      labelText: 'Sección / Componente (ej. Base, Cobertura)',
                      prefixIcon: Icon(Icons.layers_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('field_ai_edit_ingredient_notes'),
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      prefixIcon: Icon(Icons.comment_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                key: const Key('btn_cancel_ai_edit_ingredient'),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                key: const Key('btn_save_ai_edit_ingredient'),
                onPressed: () {
                  final newName = nameController.text.trim();
                  final newQty = PreciseDecimal.tryParse(qtyController.text);
                  final newUnit = unitController.text.trim().isEmpty
                      ? item.unit
                      : unitController.text.trim();
                  final newSection = sectionController.text.trim().isEmpty
                      ? item.section
                      : sectionController.text.trim();
                  final newNotes = notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim();

                  if (newName.isNotEmpty &&
                      newQty != null &&
                      newQty > PreciseDecimal.zero) {
                    setState(() {
                      _ingredients[index] = item.copyWith(
                        name: newName,
                        quantity: newQty,
                        unit: newUnit,
                        section: newSection,
                        notes: newNotes,
                      );
                    });
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCaramel,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  Future<void> _saveAndCostRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La receta debe contener al menos un ingrediente.'),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final recipeId = const Uuid().v4();
      final recipeItems = <RecipeIngredientItem>[];

      for (final ing in _ingredients) {
        final cat = _getCatalogIngredient(ing.matchedCatalogIngredientId);
        if (cat == null) continue;

        recipeItems.add(
          RecipeIngredientItem(
            id: const Uuid().v4(),
            recipeId: recipeId,
            ingredientId: cat.id,
            ingredientName: cat.name,
            quantity: ing.quantity,
            unit: ing.unit,
            section: ing.section,
            unitCost: cat.minimumUnitCost,
            baseUnit: cat.minimumUnit,
            densityGPerMl: cat.densityGPerMl,
            notes: ing.notes,
          ),
        );
      }

      final yieldPortions =
          int.tryParse(_yieldPortionsController.text) ?? 1;
      final prepTime = int.tryParse(_prepTimeController.text) ?? 0;
      final bakeTime = int.tryParse(_bakeTimeController.text) ?? 0;
      final moldDim = _moldDimensionController.text.trim();
      final notes = _notesController.text.trim();

      final newRecipe = Recipe(
        id: recipeId,
        name: _titleController.text.trim(),
        description: notes.isNotEmpty ? notes : null,
        yieldPortions: yieldPortions > 0 ? yieldPortions : 1,
        prepTimeMinutes: prepTime >= 0 ? prepTime : 0,
        bakeTimeMinutes: bakeTime >= 0 ? bakeTime : 0,
        moldType: _moldType,
        moldDimension: moldDim.isNotEmpty ? moldDim : null,
        targetProfitMargin: PreciseDecimal.fromString('40.0'),
        status: AppConstants.recipeStatusActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ingredients: recipeItems,
      );

      await context.read<RecipeRepository>().saveRecipe(newRecipe);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        context.read<RecipesBloc>().add(const LoadRecipes());

        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RecipeFormScreen(recipeToEdit: newRecipe),
          ),
        );

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '¡Receta "${newRecipe.name}" guardada y costeada con éxito!',
            ),
            backgroundColor: AppColors.profitGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la receta: $e'),
            backgroundColor: AppColors.costRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      appBar: AppBar(
        title: const Text(
          'Previsualización de Receta (IA)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textEspresso,
          ),
        ),
        backgroundColor: AppColors.butterCream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textEspresso),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Preliminary Cost Summary Banner (BR-IA-09)
                _buildCostSummaryBanner(),
                const SizedBox(height: 16),

                // Recipe Metadata Card
                _buildMetadataCard(),
                const SizedBox(height: 16),

                // Sectioned Ingredients Card
                _buildIngredientsCard(),
                const SizedBox(height: 16),

                // Instructions & Notes Card
                _buildInstructionsCard(),
                const SizedBox(height: 24),

                // Save CTA
                ElevatedButton.icon(
                  key: const Key('btn_save_and_cost_recipe'),
                  onPressed: _isSaving ? null : _saveAndCostRecipe,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded,
                          color: Colors.white),
                  label: Text(
                    _isSaving ? 'Guardando y Costeando...' : 'Guardar y Costear Receta',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.profitGreen,
                    minimumSize:
                        const Size.fromHeight(AppConstants.minTouchTargetSize),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCostSummaryBanner() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.profitGreen.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.profitGreenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.profitGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Costeo Preliminar de Insumos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textEspresso,
                      ),
                    ),
                    Text(
                      'Calculado con los precios actualizados de tu catálogo',
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Costo Total Insumos',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${_totalIngredientsCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.profitGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.borderSubtle,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Costo por Porción',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${_costPerPortion.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryCaramel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información General',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textEspresso,
            ),
          ),
          const SizedBox(height: 14),

          // Title
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Nombre de la Receta *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cake_rounded),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Ingrese un nombre válido' : null,
          ),
          const SizedBox(height: 12),

          // Portions & Times
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _yieldPortionsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Porciones *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pie_chart_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Mín 1';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _prepTimeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prep (min)',
                    border: OutlineInputBorder(),
                    suffixText: 'm',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _bakeTimeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Horno (min)',
                    border: OutlineInputBorder(),
                    suffixText: 'm',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [6, 12, 18, 24].map((qty) {
              final isSelected =
                  (int.tryParse(_yieldPortionsController.text.trim()) ?? 1) ==
                      qty;
              return ChoiceChip(
                key: Key('ai_preview_yield_chip_$qty'),
                label: Text('$qty porciones'),
                selected: isSelected,
                selectedColor: AppColors.surfaceHighlight,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primaryDarkCaramel
                      : AppColors.textEspresso,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _yieldPortionsController.text = qty.toString();
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Mold Type & Dimension
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('ai_mold_type_dropdown_$_moldType'),
                  initialValue: _moldType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Molde',
                    border: OutlineInputBorder(),
                  ),
                  items: _moldTypes.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (val) => setState(() => _moldType = val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _moldDimensionController,
                  decoration: const InputDecoration(
                    labelText: 'Dimensión Molde',
                    hintText: 'ej. 20 cm / 8 in',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsCard() {
    // Group by section
    final Map<String, List<AiExtractedIngredient>> grouped = {};
    for (final ing in _ingredients) {
      final section = ing.section.isNotEmpty ? ing.section : 'Base';
      grouped.putIfAbsent(section, () => []).add(ing);
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ingredientes (${_ingredients.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textEspresso,
                ),
              ),
              Text(
                'Subtotal: \$${_totalIngredientsCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.profitGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          for (final entry in grouped.entries) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Sección: ${entry.key}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primaryDarkCaramel,
                ),
              ),
            ),
            ...entry.value.map((item) {
              final index = _ingredients.indexOf(item);
              final itemCost = _calculateItemCost(item);
              final catalogItem =
                  _getCatalogIngredient(item.matchedCatalogIngredientId);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textEspresso,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.quantity} ${item.normalizedUnit} • ${catalogItem != null ? 'Catálogo: ${catalogItem.name}' : 'Sin asociar'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${itemCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.profitGreen,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: Key('btn_edit_ai_ingredient_$index'),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              color: AppColors.primaryCaramel,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _editIngredient(index),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                              color: AppColors.costRed,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _removeIngredient(index),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Instrucciones y Notas de Preparación',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textEspresso,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Pasos de elaboración, horneado y observaciones...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
