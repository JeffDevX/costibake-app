import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../catalog/domain/entities/ingredient.dart';
import '../../../catalog/domain/repositories/ingredient_repository.dart';
import '../../../catalog/presentation/bloc/catalog_bloc.dart';
import '../../../catalog/presentation/bloc/catalog_event.dart';
import '../../domain/entities/ai_recipe_extraction.dart';
import '../../domain/services/ingredient_catalog_matcher.dart';

/// Interactive guided modal wizard ensuring 100% of AI-extracted recipe ingredients
/// exist in the catalog or are mapped to an existing catalog item before proceeding.
/// Implements BR-IA-05, BR-IA-06, BR-IA-07, BR-IA-08.
class MissingIngredientsWizardDialog extends StatefulWidget {
  final AiRecipeExtraction extraction;
  final List<Ingredient> catalog;
  final IngredientRepository ingredientRepository;

  const MissingIngredientsWizardDialog({
    super.key,
    required this.extraction,
    required this.catalog,
    required this.ingredientRepository,
  });

  /// Helper static method to open the wizard modal.
  static Future<AiRecipeExtraction?> show({
    required BuildContext context,
    required AiRecipeExtraction extraction,
    required List<Ingredient> catalog,
    required IngredientRepository ingredientRepository,
  }) {
    return Navigator.of(context).push<AiRecipeExtraction>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MissingIngredientsWizardDialog(
          extraction: extraction,
          catalog: catalog,
          ingredientRepository: ingredientRepository,
        ),
      ),
    );
  }

  @override
  State<MissingIngredientsWizardDialog> createState() =>
      _MissingIngredientsWizardDialogState();
}

class _MissingIngredientsWizardDialogState
    extends State<MissingIngredientsWizardDialog>
    with SingleTickerProviderStateMixin {
  late List<AiExtractedIngredient> _ingredients;
  late List<Ingredient> _catalog;
  int _currentIndex = 0;

  late TabController _tabController;

  // Alta Express Form State
  final _expressFormKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _costController;
  late TextEditingController _pkgQtyController;
  late TextEditingController _wasteController;
  String _selectedCategory = 'Harinas y Secos';
  String _selectedUnit = 'kg';

  // Vincular Form State
  late TextEditingController _searchController;
  Ingredient? _selectedExistingIngredient;
  List<ScoredIngredient> _predictiveSuggestions = [];
  List<Ingredient> _filteredCatalog = [];

  // Feedback preview
  PreciseDecimal _previewUnitCost = PreciseDecimal.zero;
  String _previewBaseUnit = 'g';

  static const List<String> _categories = [
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

  static const List<Map<String, String>> _commercialUnits = [
    {'value': 'kg', 'label': 'Kilogramos (kg)'},
    {'value': 'g', 'label': 'Gramos (g)'},
    {'value': 'lb', 'label': 'Libras (lb)'},
    {'value': 'oz', 'label': 'Onzas (oz)'},
    {'value': 'l', 'label': 'Litros (l)'},
    {'value': 'ml', 'label': 'Mililitros (ml)'},
    {'value': 'unidad', 'label': 'Unidad / Pieza (u)'},
    {'value': 'docena', 'label': 'Docena (doc)'},
  ];

  @override
  void initState() {
    super.initState();
    _ingredients = List.from(widget.extraction.ingredients);
    _catalog = List.from(widget.catalog);
    _tabController = TabController(length: 2, vsync: this);

    _nameController = TextEditingController();
    _costController = TextEditingController();
    _pkgQtyController = TextEditingController(text: '1');
    _wasteController = TextEditingController(text: '0');
    _searchController = TextEditingController();

    // Jump to the first unresolved ingredient
    _currentIndex = _ingredients.indexWhere((i) => !i.isResolved);
    if (_currentIndex == -1) _currentIndex = 0;

    _loadCurrentIngredientIntoForms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _costController.dispose();
    _pkgQtyController.dispose();
    _wasteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<AiExtractedIngredient> get _unresolvedItems =>
      _ingredients.where((i) => !i.isResolved).toList();

  int get _unresolvedCount => _unresolvedItems.length;

  bool get _isAllResolved => _unresolvedCount == 0;

  AiExtractedIngredient? get _currentIngredient {
    if (_currentIndex >= 0 && _currentIndex < _ingredients.length) {
      return _ingredients[_currentIndex];
    }
    return null;
  }

  void _loadCurrentIngredientIntoForms() {
    final current = _currentIngredient;
    if (current == null) return;

    _nameController.text = current.name;
    _costController.clear();
    _wasteController.text = '0';
    _selectedExistingIngredient = null;

    // Pick sensible default unit based on detected recipe unit
    final unitLower = current.unit.toLowerCase().trim();
    if (unitLower == 'g' || unitLower == 'taza' || unitLower == 'cda' || unitLower == 'cdta') {
      _selectedUnit = 'kg';
      _pkgQtyController.text = '1';
    } else if (unitLower == 'ml' || unitLower == 'l') {
      _selectedUnit = 'l';
      _pkgQtyController.text = '1';
    } else if (unitLower == 'unidad' || unitLower == 'u' || unitLower == 'pieza') {
      _selectedUnit = 'unidad';
      _pkgQtyController.text = '1';
    } else if (_commercialUnits.any((u) => u['value'] == unitLower)) {
      _selectedUnit = unitLower;
      _pkgQtyController.text = '1';
    } else {
      _selectedUnit = 'kg';
      _pkgQtyController.text = '1';
    }

    _calculatePreviewCost();

    // Compute predictive suggestions for vincular
    final matchResult = IngredientCatalogMatcher.match(
      extractedName: current.name,
      catalog: _catalog,
    );
    _predictiveSuggestions = matchResult.suggestions;
    _filteredCatalog = List.from(_catalog);
    _searchController.clear();
  }

  void _calculatePreviewCost() {
    final cost = PreciseDecimal.tryParse(_costController.text);
    final qty = PreciseDecimal.tryParse(_pkgQtyController.text);
    final waste = PreciseDecimal.tryParse(_wasteController.text) ?? PreciseDecimal.zero;

    if (cost != null && cost > PreciseDecimal.zero && qty != null && qty > PreciseDecimal.zero) {
      final unitCost = Ingredient.calculateMinimumUnitCost(
        purchaseCost: cost,
        purchaseQuantity: qty,
        purchaseUnit: _selectedUnit,
        wastePercentage: waste,
      );
      final baseUnit = Ingredient.determineMinimumUnit(_selectedUnit);
      setState(() {
        _previewUnitCost = unitCost;
        _previewBaseUnit = baseUnit;
      });
    } else {
      setState(() {
        _previewUnitCost = PreciseDecimal.zero;
      });
    }
  }

  void _onSearchCatalog(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredCatalog = List.from(_catalog);
      });
      return;
    }

    final normalized = IngredientCatalogMatcher.normalize(query);
    setState(() {
      _filteredCatalog = _catalog.where((item) {
        return IngredientCatalogMatcher.normalize(item.name).contains(normalized);
      }).toList();
    });
  }

  Future<void> _submitAltaExpress() async {
    if (!_expressFormKey.currentState!.validate()) return;

    final current = _currentIngredient;
    if (current == null) return;

    final cost = PreciseDecimal.tryParse(_costController.text)!;
    final qty = PreciseDecimal.tryParse(_pkgQtyController.text)!;
    final waste = PreciseDecimal.tryParse(_wasteController.text) ?? PreciseDecimal.zero;
    final name = _nameController.text.trim();
    final newId = const Uuid().v4();

    final minUnit = Ingredient.determineMinimumUnit(_selectedUnit);
    final minCost = Ingredient.calculateMinimumUnitCost(
      purchaseCost: cost,
      purchaseQuantity: qty,
      purchaseUnit: _selectedUnit,
      wastePercentage: waste,
    );

    final newIngredient = Ingredient(
      id: newId,
      name: name,
      category: _selectedCategory,
      purchaseCost: cost,
      purchaseQuantity: qty,
      purchaseUnit: _selectedUnit,
      wastePercentage: waste,
      minimumUnitCost: minCost,
      minimumUnit: minUnit,
      notes: 'Alta Express desde receta con IA',
      updatedAt: DateTime.now(),
    );

    try {
      await widget.ingredientRepository.saveIngredient(newIngredient);

      // Sync with CatalogBloc if mounted
      if (mounted) {
        try {
          context.read<CatalogBloc>().add(const LoadCatalog());
        } catch (_) {}
      }

      // Add to local catalog list for subsequent matches
      _catalog.add(newIngredient);

      // Mark current ingredient resolved
      setState(() {
        _ingredients[_currentIndex] = current.copyWith(
          name: name,
          matchedCatalogIngredientId: newId,
          matchedCatalogIngredientName: name,
          isNewIngredient: true,
          purchasePrice: cost,
          commercialPackageQuantity: qty,
          commercialPackageUnit: _selectedUnit,
          wastePercentage: waste,
        );
      });

      _advanceToNextUnresolved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el insumo: $e'),
            backgroundColor: AppColors.costRed,
          ),
        );
      }
    }
  }

  void _submitVincular() {
    final selected = _selectedExistingIngredient;
    final current = _currentIngredient;
    if (selected == null || current == null) return;

    setState(() {
      _ingredients[_currentIndex] = current.copyWith(
        matchedCatalogIngredientId: selected.id,
        matchedCatalogIngredientName: selected.name,
        isNewIngredient: false,
      );
    });

    _advanceToNextUnresolved();
  }

  void _advanceToNextUnresolved() {
    final nextUnresolvedIndex = _ingredients.indexWhere((i) => !i.isResolved);
    if (nextUnresolvedIndex != -1) {
      setState(() {
        _currentIndex = nextUnresolvedIndex;
      });
      _loadCurrentIngredientIntoForms();
    } else {
      setState(() {});
    }
  }

  void _finishWizard() {
    if (!_isAllResolved) return;
    final updatedExtraction = widget.extraction.copyWith(
      ingredients: _ingredients,
    );
    Navigator.of(context).pop(updatedExtraction);
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIngredient;
    final totalCount = _ingredients.length;
    final resolvedCount = _ingredients.where((i) => i.isResolved).length;
    final progress = totalCount > 0 ? (resolvedCount / totalCount) : 1.0;

    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      appBar: AppBar(
        title: const Text(
          'Conciliar Insumos Faltantes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textEspresso,
          ),
        ),
        backgroundColor: AppColors.butterCream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textEspresso),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isAllResolved
                      ? AppColors.profitGreenLight
                      : AppColors.warningAmberLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAllResolved
                        ? AppColors.profitGreen
                        : AppColors.warningAmber,
                  ),
                ),
                child: Text(
                  '$resolvedCount/$totalCount listos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isAllResolved
                        ? AppColors.profitGreen
                        : AppColors.warningAmber,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.borderSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isAllResolved ? AppColors.profitGreen : AppColors.primaryCaramel,
                ),
              ),
              Expanded(
                child: current == null || _isAllResolved
                    ? _buildAllResolvedView()
                    : _buildCurrentIngredientResolution(current),
              ),
              _buildBottomActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllResolvedView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.profitGreenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: AppColors.profitGreen,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Todos los insumos están conciliados!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textEspresso,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Los ${_ingredients.length} ingredientes de la receta ya cuentan con costo base asociado y catálogo vinculado.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const Key('btn_confirm_reconciliation_center'),
              onPressed: _finishWizard,
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              label: const Text(
                'Continuar a Previsualización',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.profitGreen,
                minimumSize: const Size(260, AppConstants.minTouchTargetSize),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentIngredientResolution(AiExtractedIngredient current) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Detected Info Card
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmberLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warningAmber,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              current.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textEspresso,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Sección: ${current.section}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requerido en receta: ${current.quantity} ${current.normalizedUnit}${current.notes != null ? ' (${current.notes})' : ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryDarkCaramel,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action tabs: Alta Express vs Vincular
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryDarkCaramel,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primaryCaramel,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.add_circle_outline_rounded, size: 20),
                  text: 'Alta Express',
                ),
                Tab(
                  icon: Icon(Icons.link_rounded, size: 20),
                  text: 'Vincular Existente',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab content
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              return _tabController.index == 0
                  ? _buildAltaExpressForm(current)
                  : _buildVincularExistenteForm(current);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAltaExpressForm(AiExtractedIngredient current) {
    return Form(
      key: _expressFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Insumo Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre del Insumo en Catálogo *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.kitchen_rounded),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Ingrese un nombre válido' : null,
          ),
          const SizedBox(height: 12),

          // Category Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category_rounded),
            ),
            items: _categories.map((c) {
              return DropdownMenuItem(value: c, child: Text(c));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategory = val);
            },
          ),
          const SizedBox(height: 12),

          // Commercial Purchase Unit & Quantity
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Presentación',
                    border: OutlineInputBorder(),
                  ),
                  items: _commercialUnits.map((u) {
                    return DropdownMenuItem(
                      value: u['value'],
                      child: Text(u['label']!, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedUnit = val);
                      _calculatePreviewCost();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _pkgQtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cant. Compra *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _calculatePreviewCost(),
                  validator: (v) {
                    final d = PreciseDecimal.tryParse(v);
                    if (d == null || d <= PreciseDecimal.zero) {
                      return 'Inválido';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Price and Waste
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio de Compra (\$) *',
                    border: OutlineInputBorder(),
                    prefixText: r'$ ',
                  ),
                  onChanged: (_) => _calculatePreviewCost(),
                  validator: (v) {
                    final d = PreciseDecimal.tryParse(v);
                    if (d == null || d <= PreciseDecimal.zero) {
                      return 'Requerido';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _wasteController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '% Merma',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                  onChanged: (_) => _calculatePreviewCost(),
                  validator: (v) {
                    final d = PreciseDecimal.tryParse(v);
                    if (d != null && (d < PreciseDecimal.zero || d >= PreciseDecimal.fromInt(100))) {
                      return '0-99%';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Unit cost preview card
          if (_previewUnitCost > PreciseDecimal.zero)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.profitGreenLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.profitGreen.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calculate_rounded, color: AppColors.profitGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Costo Base Calculado: \$${_previewUnitCost.toStringAsFixed(4)} / $_previewBaseUnit',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.profitGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            key: const Key('btn_save_express_ingredient'),
            onPressed: _submitAltaExpress,
            icon: const Icon(Icons.save_rounded, color: Colors.white),
            label: const Text(
              'Guardar en Catálogo y Vincular',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCaramel,
              minimumSize: const Size.fromHeight(AppConstants.minTouchTargetSize),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVincularExistenteForm(AiExtractedIngredient current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Selecciona un insumo de tu catálogo para asociarlo a esta receta:',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),

        // Live search bar
        TextField(
          controller: _searchController,
          onChanged: _onSearchCatalog,
          decoration: InputDecoration(
            hintText: 'Buscar en catálogo (${_catalog.length} disponibles)...',
            prefixIcon: const Icon(Icons.search_rounded),
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchCatalog('');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),

        // Predictive suggestions section
        if (_searchController.text.trim().isEmpty && _predictiveSuggestions.isNotEmpty) ...[
          const Text(
            'Sugerencias predictivas basadas en el nombre:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDarkCaramel,
            ),
          ),
          const SizedBox(height: 6),
          ..._predictiveSuggestions.take(3).map((s) {
            final isSelected = _selectedExistingIngredient?.id == s.ingredient.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.surfaceHighlight : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primaryCaramel : AppColors.borderWarm,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                dense: true,
                title: Text(
                  s.ingredient.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${s.ingredient.category} • Costo: \$${s.ingredient.minimumUnitCost.toStringAsFixed(4)}/${s.ingredient.minimumUnit}',
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryCaramel)
                    : const Icon(Icons.radio_button_unchecked_rounded),
                onTap: () {
                  setState(() => _selectedExistingIngredient = s.ingredient);
                },
              ),
            );
          }),
          const Divider(height: 20),
        ],

        // General catalog list (or search results)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: _filteredCatalog.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No se encontraron insumos coincidentes en el catálogo.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredCatalog.length,
                  itemBuilder: (context, index) {
                    final item = _filteredCatalog[index];
                    final isSelected = _selectedExistingIngredient?.id == item.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.surfaceHighlight : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryCaramel : AppColors.borderSubtle,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.category} • \$${item.minimumUnitCost.toStringAsFixed(4)}/${item.minimumUnit}',
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryCaramel)
                            : null,
                        onTap: () {
                          setState(() => _selectedExistingIngredient = item);
                        },
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 14),

        ElevatedButton.icon(
          key: const Key('btn_link_existing_ingredient'),
          onPressed: _selectedExistingIngredient != null ? _submitVincular : null,
          icon: const Icon(Icons.link_rounded, color: Colors.white),
          label: Text(
            _selectedExistingIngredient != null
                ? 'Vincular a "${_selectedExistingIngredient!.name}"'
                : 'Selecciona un insumo para vincular',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDarkCaramel,
            disabledBackgroundColor: AppColors.borderWarm,
            minimumSize: const Size.fromHeight(AppConstants.minTouchTargetSize),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderWarm)),
      ),
      child: Row(
        children: [
          // Previous / Next item navigation
          if (_ingredients.length > 1) ...[
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Insumo anterior',
              onPressed: _currentIndex > 0
                  ? () {
                      setState(() => _currentIndex--);
                      _loadCurrentIngredientIntoForms();
                    }
                  : null,
            ),
            Text(
              '${_currentIndex + 1} de ${_ingredients.length}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textEspresso,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Insumo siguiente',
              onPressed: _currentIndex < _ingredients.length - 1
                  ? () {
                      setState(() => _currentIndex++);
                      _loadCurrentIngredientIntoForms();
                    }
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ElevatedButton.icon(
              key: const Key('btn_confirm_reconciliation'),
              onPressed: _isAllResolved ? _finishWizard : null,
              icon: Icon(
                _isAllResolved ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                _isAllResolved
                    ? 'Continuar a Previsualización'
                    : 'Faltan $_unresolvedCount insumos',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isAllResolved ? AppColors.profitGreen : AppColors.borderWarm,
                disabledBackgroundColor: AppColors.borderWarm,
                minimumSize: const Size.fromHeight(AppConstants.minTouchTargetSize),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
