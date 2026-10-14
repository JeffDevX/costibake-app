import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/culinary_units.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/utils/recipe_cycle_detector.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../catalog/domain/entities/ingredient.dart';
import '../../../catalog/domain/entities/packaging.dart';
import '../../../catalog/domain/repositories/ingredient_repository.dart';
import '../../../catalog/domain/repositories/packaging_repository.dart';
import '../../../../features/costing/domain/entities/cost_breakdown.dart';
import '../../../../features/costing/domain/services/costing_calculation_engine.dart';
import '../../../../features/costing/presentation/widgets/cost_distribution_widget.dart';
import '../../../../features/settings/domain/entities/business_config.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../../../features/settings/presentation/bloc/settings_state.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_item.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../bloc/recipes_bloc.dart';
import '../bloc/recipes_event.dart';

class RecipeFormScreen extends StatefulWidget {
  final Recipe? recipeToEdit;

  const RecipeFormScreen({super.key, this.recipeToEdit});

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _yieldController;
  late TextEditingController _prepTimeController;
  late TextEditingController _bakeTimeController;
  late TextEditingController _moldDimensionController;
  late TextEditingController _marginController;
  late TextEditingController _laborRateController;
  late TextEditingController _overheadController;

  bool _useCustomLaborRate = false;
  bool _useCustomOverhead = false;

  String? _selectedMoldType;
  String _selectedStatus = AppConstants.recipeStatusActive;

  final List<RecipeIngredientItem> _ingredients = [];
  final List<RecipeSubRecipeItem> _subRecipes = [];
  final List<RecipePackagingItem> _packaging = [];

  List<Ingredient> _availableIngredients = [];
  List<Packaging> _availablePackaging = [];
  List<Recipe> _availableSubRecipes = [];
  Map<String, List<String>> _dependencyGraph = {};

  bool _isLoadingLookups = true;
  String? _validationAlert;

  late TabController _tabController;

  static const List<String> _defaultSections = [
    'Base / Bizcocho',
    'Relleno',
    'Cobertura / Frosting',
    'Decoración',
  ];

  static const List<String> _moldTypes = [
    'Redondo',
    'Cuadrado',
    'Rectangular',
    'Plancha',
    'Cupcakes',
    'Individual',
    'Ninguno',
  ];

  bool get isEditing => widget.recipeToEdit != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final recipe = widget.recipeToEdit;
    _nameController = TextEditingController(text: recipe?.name ?? '');
    _descController = TextEditingController(text: recipe?.description ?? '');
    _yieldController = TextEditingController(
      text: recipe != null ? recipe.yieldPortions.toString() : '1',
    );
    _prepTimeController = TextEditingController(
      text: recipe != null ? recipe.prepTimeMinutes.toString() : '0',
    );
    _bakeTimeController = TextEditingController(
      text: recipe != null ? recipe.bakeTimeMinutes.toString() : '0',
    );
    _moldDimensionController =
        TextEditingController(text: recipe?.moldDimension ?? '');
    _marginController = TextEditingController(
      text: recipe != null
          ? recipe.targetProfitMargin.toStringAsFixed(2)
          : AppConstants.defaultTargetProfitMargin.toStringAsFixed(2),
    );

    _useCustomLaborRate = recipe?.laborHourlyRateOverride != null;
    _laborRateController = TextEditingController(
      text: recipe?.laborHourlyRateOverride != null
          ? recipe!.laborHourlyRateOverride!.toStringAsFixed(2)
          : '',
    );
    _laborRateController.addListener(() => setState(() {}));

    _useCustomOverhead = recipe?.overheadPercentageOverride != null;
    _overheadController = TextEditingController(
      text: recipe?.overheadPercentageOverride != null
          ? recipe!.overheadPercentageOverride!.toStringAsFixed(2)
          : '',
    );
    _overheadController.addListener(() => setState(() {}));

    _selectedMoldType = recipe?.moldType ?? _moldTypes.first;
    _selectedStatus = recipe?.status ?? AppConstants.recipeStatusActive;

    if (recipe != null) {
      _ingredients.addAll(recipe.ingredients);
      _subRecipes.addAll(recipe.subRecipes);
      _packaging.addAll(recipe.packaging);
    }

    _loadLookups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _yieldController.dispose();
    _prepTimeController.dispose();
    _bakeTimeController.dispose();
    _moldDimensionController.dispose();
    _marginController.dispose();
    _laborRateController.dispose();
    _overheadController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final ingRepo = context.read<IngredientRepository>();
      final packRepo = context.read<PackagingRepository>();
      final recipeRepo = context.read<RecipeRepository>();

      final ings = await ingRepo.getAllIngredients();
      final packs = await packRepo.getAllPackaging();
      final recipes = await recipeRepo.getAllRecipes();
      final graph = await recipeRepo.getSubRecipeDependencyGraph();

      if (!mounted) return;
      setState(() {
        _availableIngredients = ings;
        _availablePackaging = packs;
        _availableSubRecipes = recipes;
        _dependencyGraph = graph;
        _isLoadingLookups = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingLookups = false);
    }
  }

  PreciseDecimal get _totalIngredientsCost {
    PreciseDecimal total = PreciseDecimal.zero;
    for (final ing in _ingredients) {
      total += ing.calculateItemCost();
    }
    return total;
  }

  PreciseDecimal get _totalSubRecipesCost {
    PreciseDecimal total = PreciseDecimal.zero;
    for (final sub in _subRecipes) {
      total += sub.calculateItemCost();
    }
    return total;
  }

  PreciseDecimal get _totalPackagingCost {
    PreciseDecimal total = PreciseDecimal.zero;
    for (final pack in _packaging) {
      total += pack.calculateItemCost();
    }
    return total;
  }

  Set<String> get _currentSections {
    final set = <String>{..._defaultSections};
    for (final ing in _ingredients) {
      set.add(ing.section);
    }
    for (final sub in _subRecipes) {
      set.add(sub.section);
    }
    return set;
  }

  BusinessConfig get _effectiveBusinessConfig {
    try {
      final state = context.read<SettingsBloc>().state;
      if (state is SettingsLoaded) {
        return state.config;
      }
    } catch (_) {}
    return BusinessConfig(
      id: 'default',
      businessName: 'CostiBake',
      currencySymbol: AppConstants.defaultCurrencySymbol,
      laborHourlyRate:
          PreciseDecimal.fromDouble(AppConstants.defaultLaborRatePerHour),
      overheadPercentage:
          PreciseDecimal.fromDouble(AppConstants.defaultOverheadPercentage),
      updatedAt: DateTime.now(),
    );
  }

  CostBreakdown get _currentBreakdown {
    final config = _effectiveBusinessConfig;

    final laborOverride = _useCustomLaborRate &&
            _laborRateController.text.trim().isNotEmpty
        ? PreciseDecimal.tryParse(_laborRateController.text.trim())
        : null;

    final overheadOverride = _useCustomOverhead &&
            _overheadController.text.trim().isNotEmpty
        ? PreciseDecimal.tryParse(_overheadController.text.trim())
        : null;

    final prepMinutes = int.tryParse(_prepTimeController.text.trim()) ?? 0;
    final yieldVal = int.tryParse(_yieldController.text.trim()) ?? 1;
    final margin = PreciseDecimal.tryParse(_marginController.text.trim()) ??
        PreciseDecimal.fromDouble(AppConstants.defaultTargetProfitMargin);

    final recipeId = widget.recipeToEdit?.id ?? 'temp_costing';

    final tempRecipe = Recipe(
      id: recipeId,
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      yieldPortions: yieldVal > 0 ? yieldVal : 1,
      prepTimeMinutes: prepMinutes >= 0 ? prepMinutes : 0,
      bakeTimeMinutes: int.tryParse(_bakeTimeController.text.trim()) ?? 0,
      targetProfitMargin:
          margin >= PreciseDecimal.zero ? margin : PreciseDecimal.zero,
      status: _selectedStatus,
      createdAt: widget.recipeToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      laborHourlyRateOverride: laborOverride,
      overheadPercentageOverride: overheadOverride,
      ingredients: _ingredients,
      subRecipes: _subRecipes,
      packaging: _packaging,
    );

    try {
      return CostingCalculationEngine.calculate(
        recipe: tempRecipe,
        config: config,
        laborHourlyRateOverride: laborOverride,
        overheadPercentageOverride: overheadOverride,
        targetProfitMarginOverride: margin,
        yieldPortionsOverride: yieldVal > 0 ? yieldVal : 1,
        prepTimeMinutesOverride: prepMinutes >= 0 ? prepMinutes : 0,
      );
    } catch (_) {
      return CostBreakdown.empty();
    }
  }

  void _saveRecipe() {
    setState(() => _validationAlert = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Business Rule BR-REC-01: Recipe must have at least 1 ingredient or 1 sub-recipe component
    if (_ingredients.isEmpty && _subRecipes.isEmpty) {
      setState(() {
        _validationAlert =
            'La receta debe contener al menos un ingrediente o un componente modular hijo (BR-REC-01).';
      });
      _tabController.animateTo(1);
      return;
    }

    final yieldValue = int.tryParse(_yieldController.text.trim()) ?? 0;
    if (yieldValue <= 0) {
      setState(() {
        _validationAlert =
            'El rendimiento base debe ser mayor a 0 porciones (BR-REC-02).';
      });
      _tabController.animateTo(0);
      return;
    }

    final marginValue =
        PreciseDecimal.tryParse(_marginController.text.trim()) ??
            PreciseDecimal.fromDouble(AppConstants.defaultTargetProfitMargin);

    final laborOverride = _useCustomLaborRate &&
            _laborRateController.text.trim().isNotEmpty
        ? PreciseDecimal.tryParse(_laborRateController.text.trim())
        : null;

    final overheadOverride = _useCustomOverhead &&
            _overheadController.text.trim().isNotEmpty
        ? PreciseDecimal.tryParse(_overheadController.text.trim())
        : null;

    final now = DateTime.now();
    final recipeId = widget.recipeToEdit?.id ?? const Uuid().v4();

    final recipe = Recipe(
      id: recipeId,
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      yieldPortions: yieldValue,
      prepTimeMinutes: int.tryParse(_prepTimeController.text.trim()) ?? 0,
      bakeTimeMinutes: int.tryParse(_bakeTimeController.text.trim()) ?? 0,
      moldType: _selectedMoldType,
      moldDimension: _moldDimensionController.text.trim().isEmpty
          ? null
          : _moldDimensionController.text.trim(),
      targetProfitMargin: marginValue,
      laborHourlyRateOverride: laborOverride,
      overheadPercentageOverride: overheadOverride,
      status: _selectedStatus,
      createdAt: widget.recipeToEdit?.createdAt ?? now,
      updatedAt: now,
      ingredients: _ingredients
          .map((i) => i.copyWith(recipeId: recipeId))
          .toList(),
      subRecipes: _subRecipes
          .map((s) => s.copyWith(parentRecipeId: recipeId))
          .toList(),
      packaging: _packaging
          .map((p) => p.copyWith(recipeId: recipeId))
          .toList(),
    );

    final bloc = context.read<RecipesBloc>();
    if (isEditing) {
      bloc.add(UpdateRecipe(recipe));
    } else {
      bloc.add(CreateRecipe(recipe));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing
              ? 'Receta "${recipe.name}" actualizada con éxito'
              : 'Receta "${recipe.name}" creada con éxito',
        ),
        backgroundColor: AppColors.primaryCaramel,
      ),
    );

    Navigator.pop(context, true);
  }

  void _showAddIngredientModal() {
    if (_availableIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay insumos registrados en el catálogo.'),
          backgroundColor: AppColors.costRed,
        ),
      );
      return;
    }

    Ingredient selectedIng = _availableIngredients.first;
    String selectedSection = _defaultSections.first;
    CulinaryUnit selectedUnit = CulinaryUnit.values.first;
    final qtyController = TextEditingController(text: '1');
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final qty = PreciseDecimal.tryParse(qtyController.text) ??
                PreciseDecimal.zero;

            PreciseDecimal lineCost = PreciseDecimal.zero;
            String previewText = '';
            try {
              final targetUnit = selectedIng.minimumUnit;
              final normalizedQty = UnitConverter.convertUnit(
                qty,
                selectedUnit.symbol,
                targetUnit,
                density: selectedIng.densityGPerMl,
              );
              lineCost = normalizedQty * selectedIng.minimumUnitCost;
              previewText =
                  '${qty.toStringAsFixed(2)} ${selectedUnit.symbol} ≈ ${normalizedQty.toStringAsFixed(2)} $targetUnit • Costo: \$${lineCost.toStringAsFixed(4)}';
            } catch (_) {
              lineCost = qty * selectedIng.minimumUnitCost;
              previewText = 'Costo estimado directo: \$${lineCost.toStringAsFixed(4)}';
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
                top: 20,
                left: 16,
                right: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Agregar Insumo a la Receta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textEspresso,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Insumo selector
                    DropdownButtonFormField<Ingredient>(
                      initialValue: selectedIng,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar Insumo',
                        prefixIcon: Icon(Icons.egg_outlined),
                      ),
                      isExpanded: true,
                      items: _availableIngredients.map((i) {
                        return DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${i.name} (\$$i.minimumUnitCost/${i.minimumUnit})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedIng = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Section selector
                    DropdownButtonFormField<String>(
                      initialValue: selectedSection,
                      decoration: const InputDecoration(
                        labelText: 'Componente / Sección',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      items: _currentSections.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedSection = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Quantity and Unit Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: qtyController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                              prefixIcon: Icon(Icons.scale_outlined),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<CulinaryUnit>(
                            initialValue: selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unidad',
                            ),
                            items: CulinaryUnit.values.map((u) {
                              return DropdownMenuItem(
                                value: u,
                                child: Text('${u.symbol} (${u.dimension.name})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedUnit = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Real-time prorate preview badge
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.butterCream,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_graph,
                              color: AppColors.primaryCaramel, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              previewText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDarkCaramel,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Add Button (>= 48px height)
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        key: const Key('btn_confirm_add_ingredient'),
                        onPressed: () {
                          if (qty <= PreciseDecimal.zero) return;
                          final item = RecipeIngredientItem(
                            id: const Uuid().v4(),
                            recipeId: widget.recipeToEdit?.id ?? '',
                            ingredientId: selectedIng.id,
                            ingredientName: selectedIng.name,
                            quantity: qty,
                            unit: selectedUnit.symbol,
                            section: selectedSection,
                            unitCost: selectedIng.minimumUnitCost,
                            densityGPerMl: selectedIng.densityGPerMl,
                            baseUnit: selectedIng.minimumUnit,
                            notes: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                          );
                          setState(() {
                            _ingredients.add(item);
                            _validationAlert = null;
                          });
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar a la Receta'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddSubRecipeModal() {
    final currentRecipeId = widget.recipeToEdit?.id ?? 'NEW_RECIPE';
    final eligibleSubRecipes = _availableSubRecipes.where((r) {
      if (r.id == currentRecipeId) return false;
      return RecipeCycleDetector.canAddSubRecipe(
        parentRecipeId: currentRecipeId,
        candidateChildId: r.id,
        dependencyGraph: _dependencyGraph,
      );
    }).toList();

    if (eligibleSubRecipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay otras recetas disponibles o elegibles sin formar referencias circulares (BR-REC-05).',
          ),
          backgroundColor: AppColors.costRed,
        ),
      );
      return;
    }

    Recipe selectedSub = eligibleSubRecipes.first;
    String selectedSection = 'Componente';
    final factorController = TextEditingController(text: '1.0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final factor = PreciseDecimal.tryParse(factorController.text) ??
                PreciseDecimal.zero;
            final subTotal = factor * selectedSub.totalDirectCost;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
                top: 20,
                left: 16,
                right: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Agregar Sub-Receta Modular (Componente)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textEspresso,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<Recipe>(
                      initialValue: selectedSub,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar Sub-Receta',
                        prefixIcon: Icon(Icons.bakery_dining_outlined),
                      ),
                      isExpanded: true,
                      items: eligibleSubRecipes.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(
                            '${r.name} (Lote: \$${r.totalDirectCost.toStringAsFixed(2)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedSub = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _currentSections.contains(selectedSection)
                          ? selectedSection
                          : _defaultSections.first,
                      decoration: const InputDecoration(
                        labelText: 'Componente / Sección',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      items: _currentSections.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedSection = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: factorController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Factor de Proporción (1.0 = Lote completo)',
                        prefixIcon: Icon(Icons.pie_chart_outline),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.butterCream,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        'Costo proporcional agregado: \$${subTotal.toStringAsFixed(4)} (Lote base: \$${selectedSub.totalDirectCost.toStringAsFixed(2)})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDarkCaramel,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        key: const Key('btn_confirm_add_subrecipe'),
                        onPressed: () {
                          if (factor <= PreciseDecimal.zero) return;
                          final item = RecipeSubRecipeItem(
                            id: const Uuid().v4(),
                            parentRecipeId: widget.recipeToEdit?.id ?? '',
                            childRecipeId: selectedSub.id,
                            childRecipeName: selectedSub.name,
                            quantityFactor: factor,
                            section: selectedSection,
                            unitCost: selectedSub.totalDirectCost,
                          );
                          setState(() {
                            _subRecipes.add(item);
                            _validationAlert = null;
                          });
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar Sub-Receta'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddPackagingModal() {
    if (_availablePackaging.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay materiales de empaque registrados.'),
          backgroundColor: AppColors.costRed,
        ),
      );
      return;
    }

    Packaging selectedPack = _availablePackaging.first;
    final qtyController = TextEditingController(text: '1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final qty = int.tryParse(qtyController.text) ?? 1;
            final lineCost =
                PreciseDecimal.fromInt(qty) * selectedPack.unitCost;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
                top: 20,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Agregar Material de Empaque',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<Packaging>(
                    initialValue: selectedPack,
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar Empaque',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    isExpanded: true,
                    items: _availablePackaging.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(
                          '${p.name} (\$$p.unitCost/pz)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedPack = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad de Piezas',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.butterCream,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      'Costo total de empaque: \$${lineCost.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDarkCaramel,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('btn_confirm_add_packaging'),
                      onPressed: () {
                        if (qty <= 0) return;
                        final item = RecipePackagingItem(
                          id: const Uuid().v4(),
                          recipeId: widget.recipeToEdit?.id ?? '',
                          packagingId: selectedPack.id,
                          packagingName: selectedPack.name,
                          pieceQuantity: qty,
                          unitCost: selectedPack.unitCost,
                        );
                        setState(() => _packaging.add(item));
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Empaque'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Receta' : 'Formular Nueva Receta'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryDarkCaramel,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryCaramel,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'General'),
            Tab(icon: Icon(Icons.pie_chart_outline), text: 'Ingredientes'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Empaques'),
            Tab(icon: Icon(Icons.calculate_outlined), text: 'Costeo'),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.butterCream,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Costo Integral (CTP)',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_effectiveBusinessConfig.currencySymbol}${_currentBreakdown.totalProductionCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textEspresso,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_effectiveBusinessConfig.currencySymbol}${_currentBreakdown.costPerPortion.toStringAsFixed(2)} / porción',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryDarkCaramel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 6,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('btn_save_recipe'),
                    onPressed: _saveRecipe,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.save, size: 20),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isEditing ? 'Actualizar Receta' : 'Guardar Receta',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoadingLookups
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(),
                  _buildIngredientsTab(),
                  _buildPackagingTab(),
                  _buildCostingTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildGeneralTab() {
    return ResponsiveCenter(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_validationAlert != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.costRedLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.costRed),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.costRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _validationAlert!,
                      style: const TextStyle(
                        color: AppColors.costRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Card Datos Principales
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Identificación y Rendimiento',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la Receta *',
                      prefixIcon: Icon(Icons.menu_book),
                      hintText: 'Ej: Torta Selva Negra 20cm',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'El nombre de la receta es obligatorio.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Notas Técnicas',
                      prefixIcon: Icon(Icons.notes),
                      hintText: 'Bizcocho húmedo de chocolate, almíbar de cereza...',
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _yieldController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Rendimiento (Porciones) *',
                            prefixIcon: Icon(Icons.pie_chart),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            final y = int.tryParse(val?.trim() ?? '');
                            if (y == null || y <= 0) {
                              return 'Debe ser > 0 (BR-REC-02)';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: AppConstants.recipeStatusActive,
                              child: Text('ACTIVA'),
                            ),
                            DropdownMenuItem(
                              value: AppConstants.recipeStatusDraft,
                              child: Text('BORRADOR'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedStatus = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Card Tiempos y Molde
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tiempos y Parámetros de Molde',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _prepTimeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Preparación (min)',
                            prefixIcon: Icon(Icons.timer_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _bakeTimeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Horneado (min)',
                            prefixIcon: Icon(Icons.microwave_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedMoldType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Molde',
                            prefixIcon: Icon(Icons.crop_square_outlined),
                          ),
                          items: _moldTypes.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedMoldType = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _moldDimensionController,
                          decoration: const InputDecoration(
                            labelText: 'Dimensión Molde',
                            prefixIcon: Icon(Icons.straighten),
                            hintText: '20 cm / 8"',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _marginController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Margen de Ganancia Objetivo (%)',
                      prefixIcon: Icon(Icons.trending_up),
                      suffixText: '%',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsTab() {
    final sections = _currentSections.toList();

    return ResponsiveCenter(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_validationAlert != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.costRedLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.costRed),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.costRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _validationAlert!,
                      style: const TextStyle(
                        color: AppColors.costRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons bar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('btn_add_ingredient_item'),
                    onPressed: _showAddIngredientModal,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('+ Insumo'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('btn_add_subrecipe_item'),
                    onPressed: _showAddSubRecipeModal,
                    icon: const Icon(Icons.layers),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('+ Sub-Receta'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_ingredients.isEmpty && _subRecipes.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.pie_chart_outline,
                      size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'No hay ingredientes ni sub-recetas agregadas.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Usa los botones superiores para estructurar tu receta en bloques modulares.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Render each section with its items
            for (final section in sections) ...[
              _buildSectionCard(section),
            ],
          ],

          const SizedBox(height: 16),
          // Total direct ingredients & subrecipes subtotal
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.butterCream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Subtotal Insumos + Sub-recetas:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '\$${(_totalIngredientsCost + _totalSubRecipesCost).toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primaryDarkCaramel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String section) {
    final sectionIngs =
        _ingredients.where((i) => i.section == section).toList();
    final sectionSubs =
        _subRecipes.where((s) => s.section == section).toList();

    if (sectionIngs.isEmpty && sectionSubs.isEmpty) {
      return const SizedBox.shrink();
    }

    PreciseDecimal sectionCost = PreciseDecimal.zero;
    for (final i in sectionIngs) {
      sectionCost += i.calculateItemCost();
    }
    for (final s in sectionSubs) {
      sectionCost += s.calculateItemCost();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_outlined,
                    size: 20, color: AppColors.primaryCaramel),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.butterCream,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Subtotal: \$${sectionCost.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDarkCaramel,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),

            // List ingredients in this section
            for (final ing in sectionIngs) ...[
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle,
                    size: 8, color: AppColors.primaryCaramel),
                title: Text(
                  ing.ingredientName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${ing.quantity.toStringAsFixed(2)} ${ing.unit}'
                  '${ing.notes != null ? ' • ${ing.notes}' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\$${ing.calculateItemCost().toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textEspresso,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.costRed),
                      onPressed: () {
                        setState(() => _ingredients.remove(ing));
                      },
                    ),
                  ],
                ),
              ),
            ],

            // List sub-recipes in this section
            for (final sub in sectionSubs) ...[
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.layers,
                    size: 16, color: AppColors.primaryDarkCaramel),
                title: Text(
                  'Sub-receta: ${sub.childRecipeName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDarkCaramel,
                  ),
                ),
                subtitle: Text(
                  'Factor de porción: ${sub.quantityFactor.toStringAsFixed(2)}x',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\$${sub.calculateItemCost().toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDarkCaramel,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.costRed),
                      onPressed: () {
                        setState(() => _subRecipes.remove(sub));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPackagingTab() {
    return ResponsiveCenter(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('btn_add_packaging_item'),
              onPressed: _showAddPackagingModal,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('+ Agregar Material de Empaque'),
            ),
          ),
          const SizedBox(height: 16),

          if (_packaging.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'No hay empaques o descartables asociados.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Agrega cajas para pastel, blondas, lazos o capacillos requeridos para este producto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ] else ...[
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemCount: _packaging.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final pack = _packaging[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      pack.packagingName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${pack.pieceQuantity} pz • \$${pack.unitCost}/pz',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${pack.calculateItemCost().toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textEspresso,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: AppColors.costRed),
                          onPressed: () {
                            setState(() => _packaging.removeAt(index));
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.butterCream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Subtotal Empaques Directos:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '\$${_totalPackagingCost.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primaryDarkCaramel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostingTab() {
    final breakdown = _currentBreakdown;
    final config = _effectiveBusinessConfig;

    return ResponsiveCenter(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: ListView(
        key: const Key('recipe_form_costing_tab_list'),
        padding: const EdgeInsets.all(16),
        children: [
          // Visual Cost Distribution (Progress bar & legend)
          CostDistributionWidget(
            key: const Key('cost_distribution_widget'),
            breakdown: breakdown,
            currencySymbol: config.currencySymbol,
          ),
          const SizedBox(height: 16),

          // Overrides Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Parámetros Financieros y Sobrescrituras',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Personaliza la mano de obra o costos indirectos para esta receta en particular (RF-SYS-15, RF-SYS-16).',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const Divider(height: 24),

                  // Switch Labor Rate
                  SwitchListTile(
                    key: const Key('switch_custom_labor_rate'),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primaryCaramel,
                    title: const Text(
                      'Sobrescribir Tarifa de Mano de Obra',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Tarifa global: ${config.currencySymbol}${config.laborHourlyRate.toStringAsFixed(2)}/h',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    value: _useCustomLaborRate,
                    onChanged: (val) {
                      setState(() {
                        _useCustomLaborRate = val;
                        if (val && _laborRateController.text.trim().isEmpty) {
                          _laborRateController.text =
                              config.laborHourlyRate.toStringAsFixed(2);
                        }
                      });
                    },
                  ),
                  if (_useCustomLaborRate) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('field_labor_rate_override'),
                      controller: _laborRateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText:
                            'Tarifa Horaria Específica (${config.currencySymbol}/hora)',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        hintText: 'Ej: 15.00',
                      ),
                      validator: (val) {
                        if (_useCustomLaborRate) {
                          final v = PreciseDecimal.tryParse(val?.trim());
                          if (v == null || v < PreciseDecimal.zero) {
                            return 'Ingrese una tarifa válida >= 0';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Switch Overhead
                  SwitchListTile(
                    key: const Key('switch_custom_overhead'),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primaryCaramel,
                    title: const Text(
                      'Sobrescribir % de Overhead',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Overhead global: ${config.overheadPercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    value: _useCustomOverhead,
                    onChanged: (val) {
                      setState(() {
                        _useCustomOverhead = val;
                        if (val && _overheadController.text.trim().isEmpty) {
                          _overheadController.text =
                              config.overheadPercentage.toStringAsFixed(1);
                        }
                      });
                    },
                  ),
                  if (_useCustomOverhead) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('field_overhead_override'),
                      controller: _overheadController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Porcentaje Overhead Específico (%)',
                        prefixIcon: Icon(Icons.percent),
                        hintText: 'Ej: 20.0',
                      ),
                      validator: (val) {
                        if (_useCustomOverhead) {
                          final v = PreciseDecimal.tryParse(val?.trim());
                          if (v == null ||
                              v < PreciseDecimal.zero ||
                              v > PreciseDecimal.fromInt(100)) {
                            return 'Ingrese un porcentaje entre 0 y 100';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quadruple Cost Elements Breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Desglose Cuádruple de Costos (CTP)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCostRow(
                    'Insumos Directos (CI):',
                    breakdown.rawMaterialsCost
                        .toCurrencyString(symbol: config.currencySymbol),
                  ),
                  if (breakdown.subRecipesCost > PreciseDecimal.zero)
                    _buildCostRow(
                      'Sub-recetas Modulares:',
                      breakdown.subRecipesCost
                          .toCurrencyString(symbol: config.currencySymbol),
                    ),
                  _buildCostRow(
                    'Empaques y Descartables (CE):',
                    breakdown.packagingCost
                        .toCurrencyString(symbol: config.currencySymbol),
                  ),
                  _buildCostRow(
                    'Mano de Obra (CMO - ${breakdown.prepTimeMinutes} min @ ${breakdown.effectiveLaborRatePerHour.toCurrencyString(symbol: config.currencySymbol)}/h):',
                    breakdown.laborCost
                        .toCurrencyString(symbol: config.currencySymbol),
                  ),
                  _buildCostRow(
                    'Overhead (COH - ${breakdown.effectiveOverheadPercentage.toStringAsFixed(1)}%):',
                    breakdown.overheadCost
                        .toCurrencyString(symbol: config.currencySymbol),
                  ),
                  const Divider(height: 20),
                  _buildCostRow(
                    'Costo Total de Producción (CTP):',
                    breakdown.totalProductionCost
                        .toCurrencyString(symbol: config.currencySymbol),
                    isBold: true,
                  ),
                  _buildCostRow(
                    'Costo Unitario por Porción (${breakdown.yieldPortions} pzas):',
                    breakdown.costPerPortion
                        .toCurrencyString(symbol: config.currencySymbol),
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Profitability & Dual Suggested Pricing Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Sugerencia de Precios y Ganancia',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textEspresso,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.profitGreenLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${_marginController.text.trim()}% Markup',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.profitGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LOTE COMPLETO',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  breakdown.suggestedBatchPrice
                                      .toCurrencyString(symbol: config.currencySymbol),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryCaramel,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ganancia: +${breakdown.netProfitBatch.toCurrencyString(symbol: config.currencySymbol)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.profitGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 48,
                          color: AppColors.borderWarm,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PORCIÓN (${breakdown.yieldPortions} PZAS)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  breakdown.suggestedPortionPrice
                                      .toCurrencyString(symbol: config.currencySymbol),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.profitGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ganancia: +${breakdown.netProfitPortion.toCurrencyString(symbol: config.currencySymbol)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.profitGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCostRow(String title, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? AppColors.textEspresso : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: AppColors.textEspresso,
            ),
          ),
        ],
      ),
    );
  }
}
