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
import '../../../../features/costing/domain/entities/pricing_strategy.dart';
import '../../../../features/costing/domain/services/costing_calculation_engine.dart';
import '../../../../features/costing/presentation/widgets/cost_distribution_widget.dart';
import '../../../../features/costing/presentation/widgets/dual_pricing_card.dart';
import '../../../../features/settings/domain/entities/business_config.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../../../features/settings/presentation/bloc/settings_state.dart';
import '../../domain/entities/mold_preset.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_item.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../bloc/recipes_bloc.dart';
import '../bloc/recipes_event.dart';
import '../widgets/recipe_delete_confirmation_dialog.dart';
import '../widgets/recipe_pdf_export_dialog.dart';
import 'recipe_scaling_screen.dart';

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

  late PricingMode _pricingMode;
  late RoundingRule _roundingRule;
  PreciseDecimal? _customBatchPrice;
  PreciseDecimal? _customPortionPrice;

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

  late final List<String> _moldTypes;

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

    _pricingMode = recipe?.pricingMode ?? PricingMode.markupOnCost;
    _roundingRule = recipe?.roundingRule ?? RoundingRule.none;
    _customBatchPrice = recipe?.customBatchPrice;
    _customPortionPrice = recipe?.customPortionPrice;

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

    final initialMold = recipe?.moldType?.trim();
    _moldTypes = List<String>.from(AppConstants.standardMoldTypes);
    if (initialMold != null && initialMold.isNotEmpty && !_moldTypes.contains(initialMold)) {
      _moldTypes.insert(_moldTypes.length - 1, initialMold);
    }
    _selectedMoldType = (initialMold != null && initialMold.isNotEmpty)
        ? initialMold
        : _moldTypes.first;
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
      pricingMode: _pricingMode,
      roundingRule: _roundingRule,
      customBatchPrice: _customBatchPrice,
      customPortionPrice: _customPortionPrice,
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
        pricingStrategyOverride: PricingStrategy(
          mode: _pricingMode,
          targetProfitMargin:
              margin >= PreciseDecimal.zero ? margin : PreciseDecimal.zero,
          roundingRule: _roundingRule,
          customBatchPrice: _customBatchPrice,
          customPortionPrice: _customPortionPrice,
        ),
        yieldPortionsOverride: yieldVal > 0 ? yieldVal : 1,
        prepTimeMinutesOverride: prepMinutes >= 0 ? prepMinutes : 0,
      );
    } catch (_) {
      return CostBreakdown.empty();
    }
  }

  bool _isIngredientOrphaned(RecipeIngredientItem ing) {
    if (ing.isOrphaned) return true;
    if (!_isLoadingLookups &&
        _availableIngredients.isNotEmpty &&
        !_availableIngredients.any((a) => a.id == ing.ingredientId)) {
      return true;
    }
    return false;
  }

  bool _isPackagingOrphaned(RecipePackagingItem pack) {
    if (pack.isOrphaned) return true;
    if (!_isLoadingLookups &&
        _availablePackaging.isNotEmpty &&
        !_availablePackaging.any((a) => a.id == pack.packagingId)) {
      return true;
    }
    return false;
  }

  List<RecipeIngredientItem> get _orphanedIngredients =>
      _ingredients.where(_isIngredientOrphaned).toList();

  List<RecipePackagingItem> get _orphanedPackaging =>
      _packaging.where(_isPackagingOrphaned).toList();

  bool get _hasOrphanedItems =>
      _orphanedIngredients.isNotEmpty || _orphanedPackaging.isNotEmpty;

  bool get _isRecipeIncomplete =>
      _selectedStatus == AppConstants.recipeStatusIncomplete ||
      _hasOrphanedItems;

  /// Automatically transitions the recipe lifecycle state (`BR-FRC-04`):
  /// - If orphaned items still exist, forces `INCOMPLETA_REQUIERE_REVISION`.
  /// - If all orphaned items have been replaced/resolved and the recipe has at
  ///   least one valid component, restores `ACTIVA`.
  void _syncLifecycleStatusAfterOrphanResolution() {
    if (_hasOrphanedItems) {
      _selectedStatus = AppConstants.recipeStatusIncomplete;
    } else if (_selectedStatus == AppConstants.recipeStatusIncomplete &&
        (_ingredients.isNotEmpty || _subRecipes.isNotEmpty)) {
      _selectedStatus = AppConstants.recipeStatusActive;
    }
  }

  String get _incompleteBannerMessage {
    final missingNames = <String>[
      ..._orphanedIngredients.map((i) => i.cleanHistoricalName),
      ..._orphanedPackaging.map((p) => p.cleanHistoricalName),
    ];
    final count = missingNames.isEmpty ? 1 : missingNames.length;
    final namesDetail =
        missingNames.isNotEmpty ? ' (${missingNames.join(', ')})' : '';
    if (count == 1) {
      return 'Receta incompleta: 1 ingrediente ha sido eliminado del catálogo$namesDetail. Asigne un sustituto para reactivar el costeo.';
    }
    return 'Receta incompleta: $count ingredientes han sido eliminados del catálogo$namesDetail. Asigne un sustituto para reactivar el costeo.';
  }

  void _showReplaceOrphanIngredientDialog(RecipeIngredientItem orphanItem) {
    if (_availableIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay insumos activos en el catálogo para asignar como sustituto.',
          ),
          backgroundColor: AppColors.costRed,
        ),
      );
      return;
    }

    Ingredient selectedSubstitute = _availableIngredients.first;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              key: const Key('replace_orphan_ingredient_dialog'),
              scrollable: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.primaryCaramel,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Asignar Sustituto',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textEspresso,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reemplazar "${orphanItem.cleanHistoricalName}" '
                    '(${orphanItem.quantity.toStringAsFixed(2)} ${orphanItem.unit} en ${orphanItem.section}) '
                    'por un insumo activo del catálogo (BR-FRC-04):',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<Ingredient>(
                    key: const Key('dropdown_substitute_ingredient'),
                    initialValue: selectedSubstitute,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Insumo Sustituto Activo',
                      prefixIcon: Icon(Icons.egg_outlined),
                    ),
                    items: _availableIngredients.map((i) {
                      return DropdownMenuItem<Ingredient>(
                        value: i,
                        child: Text(
                          '${i.name} (\$${i.minimumUnitCost}/${i.minimumUnit})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedSubstitute = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  height: 48,
                  child: TextButton(
                    key: const Key('btn_cancel_replace_orphan_ingredient'),
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('btn_confirm_replace_orphan_ingredient'),
                    onPressed: () {
                      final idx = _ingredients
                          .indexWhere((i) => i.id == orphanItem.id);
                      if (idx != -1) {
                        final replacement = RecipeIngredientItem(
                          id: orphanItem.id,
                          recipeId: orphanItem.recipeId,
                          ingredientId: selectedSubstitute.id,
                          ingredientName: selectedSubstitute.name,
                          quantity: orphanItem.quantity,
                          unit: orphanItem.unit,
                          section: orphanItem.section,
                          unitCost: selectedSubstitute.minimumUnitCost,
                          densityGPerMl: selectedSubstitute.densityGPerMl,
                          baseUnit: selectedSubstitute.minimumUnit,
                          notes: orphanItem.notes,
                          isDeleted: false,
                        );
                        setState(() {
                          _ingredients[idx] = replacement;
                          _syncLifecycleStatusAfterOrphanResolution();
                        });
                      }
                      Navigator.of(dialogCtx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isRecipeIncomplete
                                ? 'Sustituto "${selectedSubstitute.name}" asignado.'
                                : 'Sustituto "${selectedSubstitute.name}" asignado. Receta restaurada a estado ACTIVA.',
                          ),
                          backgroundColor: AppColors.profitGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirmar Sustituto'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReplaceOrphanPackagingDialog(RecipePackagingItem orphanPack) {
    if (_availablePackaging.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay empaques activos en el catálogo para asignar como sustituto.',
          ),
          backgroundColor: AppColors.costRed,
        ),
      );
      return;
    }

    Packaging selectedSubstitute = _availablePackaging.first;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              key: const Key('replace_orphan_packaging_dialog'),
              scrollable: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Asignar Empaque Sustituto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textEspresso,
                ),
              ),
              content: DropdownButtonFormField<Packaging>(
                key: const Key('dropdown_substitute_packaging'),
                initialValue: selectedSubstitute,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Empaque Sustituto Activo',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: _availablePackaging.map((p) {
                  return DropdownMenuItem<Packaging>(
                    value: p,
                    child: Text(
                      '${p.name} (\$${p.unitCost}/pz)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedSubstitute = val);
                  }
                },
              ),
              actions: [
                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('btn_confirm_replace_orphan_packaging'),
                    onPressed: () {
                      final idx =
                          _packaging.indexWhere((p) => p.id == orphanPack.id);
                      if (idx != -1) {
                        final replacement = RecipePackagingItem(
                          id: orphanPack.id,
                          recipeId: orphanPack.recipeId,
                          packagingId: selectedSubstitute.id,
                          packagingName: selectedSubstitute.name,
                          pieceQuantity: orphanPack.pieceQuantity,
                          unitCost: selectedSubstitute.unitCost,
                          isDeleted: false,
                        );
                        setState(() {
                          _packaging[idx] = replacement;
                          _syncLifecycleStatusAfterOrphanResolution();
                        });
                      }
                      Navigator.of(dialogCtx).pop();
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirmar Sustituto'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Recipe _buildRecipeFromForm() {
    final yieldValue = int.tryParse(_yieldController.text.trim()) ?? 1;
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

    return Recipe(
      id: recipeId,
      name: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (widget.recipeToEdit?.name ?? 'Receta sin nombre'),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      yieldPortions: yieldValue > 0 ? yieldValue : 1,
      prepTimeMinutes: int.tryParse(_prepTimeController.text.trim()) ?? 0,
      bakeTimeMinutes: int.tryParse(_bakeTimeController.text.trim()) ?? 0,
      moldType: _selectedMoldType,
      moldDimension: _moldDimensionController.text.trim().isEmpty
          ? null
          : _moldDimensionController.text.trim(),
      targetProfitMargin: marginValue,
      pricingMode: _pricingMode,
      roundingRule: _roundingRule,
      customBatchPrice: _customBatchPrice,
      customPortionPrice: _customPortionPrice,
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

    // Ensure lifecycle status reflects whether orphaned items remain (BR-FRC-04)
    _syncLifecycleStatusAfterOrphanResolution();

    final yieldValue = int.tryParse(_yieldController.text.trim()) ?? 0;
    if (yieldValue <= 0) {
      setState(() {
        _validationAlert =
            'El rendimiento base debe ser mayor a 0 porciones (BR-REC-02).';
      });
      _tabController.animateTo(0);
      return;
    }

    final recipe = _buildRecipeFromForm();

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
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Componente / Sección',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      items: _currentSections.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis));
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
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Unidad',
                            ),
                            items: CulinaryUnit.values.map((u) {
                              return DropdownMenuItem(
                                value: u,
                                child: Text(u.symbol, overflow: TextOverflow.ellipsis),
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

  void _showEditIngredientModal(RecipeIngredientItem item) {
    Ingredient? matchedCatalogIng;
    for (final ing in _availableIngredients) {
      if (ing.id == item.ingredientId) {
        matchedCatalogIng = ing;
        break;
      }
    }

    final selectedIng = matchedCatalogIng ??
        Ingredient(
          id: item.ingredientId,
          name: item.ingredientName,
          category: 'General',
          purchaseCost: item.unitCost,
          purchaseQuantity: PreciseDecimal.one,
          purchaseUnit: item.unit,
          wastePercentage: PreciseDecimal.zero,
          minimumUnitCost: item.unitCost,
          minimumUnit: item.baseUnit ?? item.unit,
          densityGPerMl: item.densityGPerMl,
          updatedAt: DateTime.now(),
        );

    String selectedSection = item.section;
    CulinaryUnit selectedUnit = CulinaryUnit.tryParse(item.unit) ?? CulinaryUnit.values.first;
    final qtyController = TextEditingController(text: item.quantity.toString());
    final noteController = TextEditingController(text: item.notes ?? '');

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
                    Row(
                      children: [
                        const Icon(Icons.edit_note, color: AppColors.primaryCaramel),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Editar Insumo: ${selectedIng.name}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textEspresso,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section selector
                    DropdownButtonFormField<String>(
                      initialValue: selectedSection,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Componente / Sección',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      items: _currentSections.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis));
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
                            key: const Key('field_edit_ingredient_quantity'),
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
                            key: const Key('dropdown_edit_ingredient_unit'),
                            initialValue: selectedUnit,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Unidad',
                            ),
                            items: CulinaryUnit.values.map((u) {
                              return DropdownMenuItem(
                                value: u,
                                child: Text(u.symbol, overflow: TextOverflow.ellipsis),
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

                    // Note field
                    TextFormField(
                      key: const Key('field_edit_ingredient_note'),
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Nota (opcional)',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
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

                    // Save Button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        key: const Key('btn_confirm_edit_ingredient'),
                        onPressed: () {
                          if (qty <= PreciseDecimal.zero) return;
                          final updatedItem = item.copyWith(
                            quantity: qty,
                            unit: selectedUnit.symbol,
                            section: selectedSection,
                            notes: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                          );
                          setState(() {
                            final currentIdx =
                                _ingredients.indexWhere((i) => i.id == item.id);
                            if (currentIdx != -1) {
                              _ingredients[currentIdx] = updatedItem;
                            }
                            _syncLifecycleStatusAfterOrphanResolution();
                          });
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Guardar Cambios'),
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

  void _showEditSubRecipeModal(RecipeSubRecipeItem sub) {
    String selectedSection = sub.section;
    final factorController =
        TextEditingController(text: sub.quantityFactor.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final factor = PreciseDecimal.tryParse(factorController.text) ??
                PreciseDecimal.zero;
            final subTotal = factor * sub.unitCost;

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
                    Row(
                      children: [
                        const Icon(Icons.layers, color: AppColors.primaryDarkCaramel),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Editar Sub-Receta: ${sub.childRecipeName}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textEspresso,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _currentSections.contains(selectedSection)
                          ? selectedSection
                          : _defaultSections.first,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Componente / Sección',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      items: _currentSections.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedSection = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      key: const Key('field_edit_subrecipe_factor'),
                      controller: factorController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Factor de Proporción (1.0 = lote completo)',
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
                        'Costo proporcional sub-receta: \$${subTotal.toStringAsFixed(4)}',
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
                        key: const Key('btn_confirm_edit_subrecipe'),
                        onPressed: () {
                          if (factor <= PreciseDecimal.zero) return;
                          final updated = sub.copyWith(
                            quantityFactor: factor,
                            section: selectedSection,
                          );
                          setState(() {
                            final idx =
                                _subRecipes.indexWhere((s) => s.id == sub.id);
                            if (idx != -1) {
                              _subRecipes[idx] = updated;
                            }
                          });
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Guardar Cambios'),
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

  void _showEditPackagingModal(RecipePackagingItem pack) {
    final qtyController =
        TextEditingController(text: pack.pieceQuantity.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final qty = int.tryParse(qtyController.text) ?? 0;
            final lineCost =
                PreciseDecimal.fromInt(qty) * pack.unitCost;

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
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            color: AppColors.primaryCaramel),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Editar Empaque: ${pack.cleanHistoricalName}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textEspresso,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      key: const Key('field_edit_packaging_qty'),
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
                        key: const Key('btn_confirm_edit_packaging'),
                        onPressed: () {
                          if (qty <= 0) return;
                          final updated = pack.copyWith(pieceQuantity: qty);
                          setState(() {
                            final idx =
                                _packaging.indexWhere((p) => p.id == pack.id);
                            if (idx != -1) {
                              _packaging[idx] = updated;
                            }
                          });
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Guardar Cambios'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Receta' : 'Formular Nueva Receta'),
        actions: [
          IconButton(
            key: const Key('btn_recipe_hide_keyboard'),
            icon: const Icon(Icons.keyboard_hide),
            tooltip: 'Ocultar Teclado',
            onPressed: () => FocusScope.of(context).unfocus(),
          ),
          if (isEditing && widget.recipeToEdit != null) ...[
            IconButton(
              key: const Key('btn_delete_recipe_form'),
              tooltip: 'Eliminar Receta',
              icon: const Icon(Icons.delete_outline, color: AppColors.costRed),
              onPressed: () {
                RecipeDeleteConfirmationDialog.show(
                  context,
                  recipe: widget.recipeToEdit!,
                  onDeleted: () {
                    Navigator.pop(context);
                  },
                );
              },
            ),
            IconButton(
              key: const Key('btn_export_recipe_pdf'),
              tooltip: 'Exportar Ficha Técnica / Producción en PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () {
                final currentRecipe = _buildRecipeFromForm();
                RecipePdfExportDialog.show(
                  context,
                  recipe: currentRecipe,
                  businessConfig: _effectiveBusinessConfig,
                  costBreakdown: _currentBreakdown,
                );
              },
            ),
            IconButton(
              key: const Key('btn_open_scaling_screen'),
              tooltip: 'Escalar Receta / Molde',
              icon: const Icon(Icons.aspect_ratio_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RecipeScalingScreen(recipe: widget.recipeToEdit!),
                  ),
                );
              },
            ),
          ],
        ],
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
              child: Column(
                children: [
                  if (_isRecipeIncomplete) _buildIncompleteRecipeBanner(),
                  Expanded(
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
                ],
              ),
            ),
    );
  }

  Widget _buildIncompleteRecipeBanner() {
    return Container(
      key: const Key('incomplete_recipe_warning_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.costRedLight,
        border: Border(
          bottom: BorderSide(
            color: AppColors.costRed.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.maxContentWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.costRed,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _incompleteBannerMessage,
                key: const Key('incomplete_recipe_warning_text'),
                style: const TextStyle(
                  color: AppColors.costRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ),
            if (_orphanedIngredients.isNotEmpty ||
                _orphanedPackaging.isNotEmpty) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: TextButton(
                  key: const Key('btn_banner_resolve_orphan'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.costRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () {
                    if (_orphanedIngredients.isNotEmpty) {
                      _tabController.animateTo(1);
                      _showReplaceOrphanIngredientDialog(
                        _orphanedIngredients.first,
                      );
                    } else if (_orphanedPackaging.isNotEmpty) {
                      _tabController.animateTo(2);
                      _showReplaceOrphanPackagingDialog(
                        _orphanedPackaging.first,
                      );
                    }
                  },
                  child: const Text(
                    'Sustituir',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ResponsiveCenter(
      maxWidth: AppBreakpoints.maxContentWidth,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                          key: ValueKey('status_dropdown_$_selectedStatus'),
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
                            DropdownMenuItem(
                              value: AppConstants.recipeStatusIncomplete,
                              child: Text('INCOMPLETA'),
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
                          key: ValueKey('mold_type_dropdown_$_selectedMoldType'),
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
                          decoration: InputDecoration(
                            labelText: 'Dimensión / Capacidad',
                            prefixIcon: const Icon(Icons.straighten),
                            hintText: (_selectedMoldType == 'Individual' ||
                                    _selectedMoldType == 'Cupcakes / Muffins')
                                ? 'Ej: Vasito 4 oz, 6 oz, etc.'
                                : '20 cm / 8"',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Vasitos y Envases Individuales (oz / ml):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDarkCaramel,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: MoldPreset.individualPresets.map((preset) {
                      final isSelected = _moldDimensionController.text.trim() ==
                          preset.dimensionLabel;
                      return ActionChip(
                        key: Key('form_mold_preset_${preset.id}'),
                        label: Text(
                          preset.dimensionLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: isSelected
                            ? AppColors.butterCream
                            : AppColors.surfaceWarm,
                        onPressed: () {
                          setState(() {
                            if (!_moldTypes.contains(preset.moldTypeLabel)) {
                              _moldTypes.insert(
                                  _moldTypes.length - 1, preset.moldTypeLabel);
                            }
                            _selectedMoldType = preset.moldTypeLabel;
                            _moldDimensionController.text =
                                preset.dimensionLabel;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Moldes estándar de torta y plancha:',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...MoldPreset.circularPresets.sublist(1, 6), // 6", 8", 9", 10", 12"
                      MoldPreset.rectangularPresets[2], // 20x30 cm
                      MoldPreset.rectangularPresets[4], // 30x40 cm
                    ].map((preset) {
                      final isSelected = _moldDimensionController.text.trim() ==
                          preset.dimensionLabel;
                      return ActionChip(
                        key: Key('form_mold_preset_${preset.id}'),
                        label: Text(
                          '${preset.moldTypeLabel} ${preset.dimensionLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: isSelected
                            ? AppColors.butterCream
                            : AppColors.surfaceWarm,
                        onPressed: () {
                          setState(() {
                            if (!_moldTypes.contains(preset.moldTypeLabel)) {
                              _moldTypes.insert(_moldTypes.length - 1, preset.moldTypeLabel);
                            }
                            _selectedMoldType = preset.moldTypeLabel;
                            _moldDimensionController.text =
                                preset.dimensionLabel;
                          });
                        },
                      );
                    }).toList(),
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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
              Builder(
                builder: (context) {
                  final isOrphaned = _isIngredientOrphaned(ing);
                  if (isOrphaned) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.costRedLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.costRed.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: AppColors.costRed,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ing.ingredientName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.costRed,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    Text(
                                      '${ing.quantity.toStringAsFixed(2)} ${ing.unit} • Eliminado del catálogo (Costo excluido)',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.costRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: AppColors.costRed,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _ingredients.remove(ing);
                                    _syncLifecycleStatusAfterOrphanResolution();
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 40,
                            child: TextButton.icon(
                              key: Key(
                                  'btn_replace_orphan_ingredient_${ing.id}'),
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.costRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                              ),
                              onPressed: () =>
                                  _showReplaceOrphanIngredientDialog(ing),
                              icon: const Icon(Icons.swap_horiz, size: 16),
                              label: const Text(
                                'Asignar Sustituto',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _showEditIngredientModal(ing),
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
                          key: Key('btn_edit_recipe_ingredient_${ing.id}'),
                          icon: const Icon(Icons.edit_outlined,
                              size: 20, color: AppColors.primaryCaramel),
                          tooltip: 'Editar Insumo / Cantidad',
                          onPressed: () => _showEditIngredientModal(ing),
                        ),
                        IconButton(
                          key: Key('btn_delete_recipe_ingredient_${ing.id}'),
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: AppColors.costRed),
                          onPressed: () {
                            setState(() {
                              _ingredients.remove(ing);
                              _syncLifecycleStatusAfterOrphanResolution();
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // List sub-recipes in this section
            for (final sub in sectionSubs) ...[
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () => _showEditSubRecipeModal(sub),
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
                      key: Key('btn_edit_subrecipe_${sub.id}'),
                      icon: const Icon(Icons.edit_outlined,
                          size: 20, color: AppColors.primaryDarkCaramel),
                      tooltip: 'Editar Factor de Sub-receta',
                      onPressed: () => _showEditSubRecipeModal(sub),
                    ),
                    IconButton(
                      key: Key('btn_delete_subrecipe_${sub.id}'),
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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  final isOrphaned = _isPackagingOrphaned(pack);
                  if (isOrphaned) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppColors.costRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pack.packagingName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.costRed,
                                      ),
                                    ),
                                    Text(
                                      '${pack.pieceQuantity} pz • Eliminado del catálogo',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.costRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: AppColors.costRed),
                                onPressed: () {
                                  setState(() {
                                    _packaging.removeAt(index);
                                    _syncLifecycleStatusAfterOrphanResolution();
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 40,
                            child: TextButton.icon(
                              key: Key(
                                  'btn_replace_orphan_packaging_${pack.id}'),
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.costRed,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  _showReplaceOrphanPackagingDialog(pack),
                              icon: const Icon(Icons.swap_horiz, size: 16),
                              label: const Text(
                                'Asignar Sustituto',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListTile(
                    dense: true,
                    onTap: () => _showEditPackagingModal(pack),
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
                          key: Key('btn_edit_packaging_${pack.id}'),
                          icon: const Icon(Icons.edit_outlined,
                              size: 20, color: AppColors.primaryCaramel),
                          tooltip: 'Editar Cantidad de Empaque',
                          onPressed: () => _showEditPackagingModal(pack),
                        ),
                        IconButton(
                          key: Key('btn_delete_packaging_${pack.id}'),
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: AppColors.costRed),
                          onPressed: () {
                            setState(() {
                              _packaging.removeAt(index);
                              _syncLifecycleStatusAfterOrphanResolution();
                            });
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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          if (_isRecipeIncomplete) ...[
            Card(
              key: const Key('incomplete_pricing_disabled_card'),
              color: AppColors.costRedLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.costRed.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.block_outlined,
                          color: AppColors.costRed,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Precio de Venta Sugerido Deshabilitado (BR-FRC-03)',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.costRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _incompleteBannerMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textEspresso,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

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

          // Dual Suggested Pricing & Margin Strategy Card (JEF-16 / BR-FRC-03)
          if (!_isRecipeIncomplete)
            DualPricingCard(
              key: const Key('recipe_form_dual_pricing_card'),
              totalProductionCost: breakdown.totalProductionCost,
              yieldPortions: breakdown.yieldPortions,
              currencySymbol: config.currencySymbol,
              initialStrategy: PricingStrategy(
                mode: _pricingMode,
                targetProfitMargin:
                    PreciseDecimal.tryParse(_marginController.text.trim()) ??
                        PreciseDecimal.fromDouble(
                            AppConstants.defaultTargetProfitMargin),
                roundingRule: _roundingRule,
                customBatchPrice: _customBatchPrice,
                customPortionPrice: _customPortionPrice,
              ),
              onStrategyChanged: (newStrategy) {
                setState(() {
                  _pricingMode = newStrategy.mode;
                  _roundingRule = newStrategy.roundingRule;
                  _customBatchPrice = newStrategy.customBatchPrice;
                  _customPortionPrice = newStrategy.customPortionPrice;
                  _marginController.text =
                      newStrategy.targetProfitMargin.toStringAsFixed(0);
                });
              },
            ),
          const SizedBox(height: 16),

          // Botón Exportar PDF (BR-EXP-01)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('btn_export_pdf_costing_tab'),
              onPressed: () {
                final currentRecipe = _buildRecipeFromForm();
                RecipePdfExportDialog.show(
                  context,
                  recipe: currentRecipe,
                  businessConfig: _effectiveBusinessConfig,
                  costBreakdown: _currentBreakdown,
                );
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text(
                'Exportar Ficha Técnica / Producción en PDF',
                style: TextStyle(fontWeight: FontWeight.bold),
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
