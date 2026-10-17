import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:costibake_app/core/constants/app_breakpoints.dart';
import 'package:costibake_app/core/theme/app_colors.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/core/utils/unit_converter.dart';
import 'package:costibake_app/core/widgets/responsive_center.dart';
import '../../domain/entities/dependency_block_info.dart';
import '../../domain/entities/ingredient.dart';
import '../../../recipes/presentation/bloc/recipes_bloc.dart';
import '../../../recipes/presentation/bloc/recipes_event.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../widgets/dependency_protection_dialog.dart';

class IngredientFormScreen extends StatefulWidget {
  final Ingredient? ingredient;
  final String? initialName;

  const IngredientFormScreen({
    super.key,
    this.ingredient,
    this.initialName,
  });

  @override
  State<IngredientFormScreen> createState() => _IngredientFormScreenState();
}

class _IngredientFormScreenState extends State<IngredientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _costController;
  late TextEditingController _wasteController;
  late TextEditingController _notesController;
  late TextEditingController _densityController;

  late String _selectedCategory;
  late String _selectedUnit;
  String? _selectedDensityPresetKey;

  // Calculation state preview
  PreciseDecimal _previewMinCost = PreciseDecimal.zero;
  String _previewBaseUnit = 'g';
  PreciseDecimal _previewBaseQty = PreciseDecimal.zero;
  PreciseDecimal _previewEffectiveQty = PreciseDecimal.zero;

  static const List<Map<String, dynamic>> densityPresets = [
    {
      'label': 'Sin densidad preconfigurada',
      'key': null,
      'gPerCup': null,
      'gPerMl': null,
    },
    {
      'label': 'Harina de trigo todo uso (125 g/taza)',
      'key': 'harina_trigo',
      'gPerCup': '125.0',
      'gPerMl': '0.520833',
    },
    {
      'label': 'Azúcar refinada / blanca (200 g/taza)',
      'key': 'azucar_blanca',
      'gPerCup': '200.0',
      'gPerMl': '0.833333',
    },
    {
      'label': 'Azúcar glass / impalpable (120 g/taza)',
      'key': 'azucar_glass',
      'gPerCup': '120.0',
      'gPerMl': '0.500000',
    },
    {
      'label': 'Mantequilla (227 g/taza)',
      'key': 'mantequilla',
      'gPerCup': '227.0',
      'gPerMl': '0.945833',
    },
    {
      'label': 'Aceite vegetal (218 g/taza)',
      'key': 'aceite_vegetal',
      'gPerCup': '218.0',
      'gPerMl': '0.908333',
    },
    {
      'label': 'Miel de abeja / jarabe (340 g/taza)',
      'key': 'miel',
      'gPerCup': '340.0',
      'gPerMl': '1.416667',
    },
    {
      'label': 'Cacao en polvo (100 g/taza)',
      'key': 'cacao_polvo',
      'gPerCup': '100.0',
      'gPerMl': '0.416667',
    },
    {
      'label': 'Leche entera (245 g/taza)',
      'key': 'leche_entera',
      'gPerCup': '245.0',
      'gPerMl': '1.020833',
    },
    {
      'label': 'Agua pura (240 g/taza)',
      'key': 'agua_pura',
      'gPerCup': '240.0',
      'gPerMl': '1.000000',
    },
    {
      'label': 'Personalizado (ingresar g/ml)',
      'key': 'custom',
      'gPerCup': null,
      'gPerMl': null,
    },
  ];

  static const List<String> categories = [
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

  static const List<Map<String, String>> commercialUnits = [
    // Masa / Peso
    {'value': 'kg', 'label': 'Kilogramos (kg)', 'group': 'Peso'},
    {'value': 'lb', 'label': 'Libras (lb)', 'group': 'Peso'},
    {'value': 'g', 'label': 'Gramos (g)', 'group': 'Peso'},
    {'value': 'oz', 'label': 'Onzas (oz)', 'group': 'Peso'},
    // Volumen
    {'value': 'l', 'label': 'Litros (l)', 'group': 'Volumen'},
    {'value': 'gal', 'label': 'Galones (gal)', 'group': 'Volumen'},
    {'value': 'ml', 'label': 'Mililitros (ml)', 'group': 'Volumen'},
    // Conteo
    {'value': 'docena', 'label': 'Docena (12 u)', 'group': 'Conteo'},
    {'value': 'unidad', 'label': 'Piezas / Unidad (u)', 'group': 'Conteo'},
  ];

  @override
  void initState() {
    super.initState();
    final ing = widget.ingredient;
    _nameController =
        TextEditingController(text: ing?.name ?? widget.initialName ?? '');
    _quantityController = TextEditingController(
      text: ing != null ? ing.purchaseQuantity.toString() : '',
    );
    _costController = TextEditingController(
      text: ing != null ? ing.purchaseCost.toString() : '',
    );
    _wasteController = TextEditingController(
      text: ing != null ? ing.wastePercentage.toString() : '0',
    );
    _notesController = TextEditingController(text: ing?.notes ?? '');
    _densityController = TextEditingController(
      text: ing?.densityGPerMl != null ? ing!.densityGPerMl!.toString() : '',
    );

    if (ing?.densityGPerMl != null) {
      final currentGPerMl = ing!.densityGPerMl!.toStringAsFixed(4);
      final match = densityPresets.firstWhere(
        (p) =>
            p['gPerMl'] != null &&
            (p['gPerMl'] as String).startsWith(currentGPerMl.substring(0, 4)),
        orElse: () => {'key': 'custom'},
      );
      _selectedDensityPresetKey = match['key'] as String?;
    } else {
      _selectedDensityPresetKey = null;
    }

    _selectedCategory = ing?.category ?? categories.first;
    _selectedUnit = ing?.purchaseUnit ?? 'kg';

    _recalculateNormalization();
  }


  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _wasteController.dispose();
    _notesController.dispose();
    _densityController.dispose();
    super.dispose();
  }

  void _recalculateNormalization() {
    final costStr = _costController.text.trim();
    final qtyStr = _quantityController.text.trim();
    final wasteStr = _wasteController.text.trim();

    try {
      final cost = costStr.isNotEmpty
          ? PreciseDecimal.fromString(costStr)
          : PreciseDecimal.zero;
      final qty = qtyStr.isNotEmpty
          ? PreciseDecimal.fromString(qtyStr)
          : PreciseDecimal.zero;
      final waste = wasteStr.isNotEmpty
          ? PreciseDecimal.fromString(wasteStr)
          : PreciseDecimal.zero;

      if (qty > PreciseDecimal.zero && cost > PreciseDecimal.zero) {
        final baseUnit = UnitConverter.determineBaseUnit(_selectedUnit);
        final baseQty = UnitConverter.convertToBaseQuantity(qty, _selectedUnit);
        final usableMultiplier = PreciseDecimal.fromInt(1) -
            (waste / PreciseDecimal.fromInt(100));
        final effectiveQty = baseQty * usableMultiplier;

        final minCost = Ingredient.calculateMinimumUnitCost(
          purchaseCost: cost,
          purchaseQuantity: qty,
          purchaseUnit: _selectedUnit,
          wastePercentage: waste,
        );

        setState(() {
          _previewMinCost = minCost;
          _previewBaseUnit = baseUnit;
          _previewBaseQty = baseQty;
          _previewEffectiveQty = effectiveQty;
        });
        return;
      }
    } catch (_) {
      // Ignored for partial typing
    }

    setState(() {
      _previewMinCost = PreciseDecimal.zero;
      _previewBaseUnit = UnitConverter.determineBaseUnit(_selectedUnit);
      _previewBaseQty = PreciseDecimal.zero;
      _previewEffectiveQty = PreciseDecimal.zero;
    });
  }

  void _saveIngredient() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final cost = PreciseDecimal.fromString(_costController.text.trim());
    final qty = PreciseDecimal.fromString(_quantityController.text.trim());
    final waste = _wasteController.text.trim().isNotEmpty
        ? PreciseDecimal.fromString(_wasteController.text.trim())
        : PreciseDecimal.zero;
    final notes = _notesController.text.trim();
    final baseUnit = UnitConverter.determineBaseUnit(_selectedUnit);

    final minCost = Ingredient.calculateMinimumUnitCost(
      purchaseCost: cost,
      purchaseQuantity: qty,
      purchaseUnit: _selectedUnit,
      wastePercentage: waste,
    );

    final densityText = _densityController.text.trim();
    final density = densityText.isNotEmpty
        ? PreciseDecimal.fromString(densityText)
        : null;

    final isEditing = widget.ingredient != null;
    final ingredientToSave = Ingredient(
      id: widget.ingredient?.id ?? const Uuid().v4(),
      name: name,
      category: _selectedCategory,
      purchaseCost: cost,
      purchaseQuantity: qty,
      purchaseUnit: _selectedUnit,
      wastePercentage: waste,
      minimumUnitCost: minCost,
      minimumUnit: baseUnit,
      densityGPerMl: density,
      notes: notes.isNotEmpty ? notes : null,
      updatedAt: DateTime.now(),
    );


    if (isEditing) {
      context.read<CatalogBloc>().add(UpdateIngredient(ingredientToSave));
      try {
        context.read<RecipesBloc>().add(const LoadRecipes());
      } catch (_) {}
    } else {
      context.read<CatalogBloc>().add(AddIngredient(ingredientToSave));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insumo "$name" registrado exitosamente (${minCost.toCurrencyString()}/$baseUnit)',
          ),
          backgroundColor: AppColors.profitGreen,
        ),
      );
    }

    Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final ing = widget.ingredient;
    if (ing == null) return;

    final bloc = context.read<CatalogBloc>();
    final affectedRecipes = await bloc.checkIngredientDependencies(ing.id);
    if (!mounted) return;

    // RF-SYS-21, RF-SYS-22, BR-INT-01, BR-INT-02: Block deletion if in use
    if (affectedRecipes.isNotEmpty) {
      await DependencyProtectionDialog.show(
        context,
        blockInfo: DependencyBlockInfo(
          itemId: ing.id,
          itemName: ing.name,
          isPackaging: false,
          affectedRecipeNames: affectedRecipes,
        ),
      );
      return;
    }

    // BR-INT-03: Simple confirmation when 0 active dependencies
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          key: const Key('simple_delete_confirm_dialog'),
          title: const Text('Eliminar Insumo'),
          content: Text(
            '¿Estás seguro de que deseas eliminar "${ing.name}"? Esta acción es permanente (0 recetas afectadas).',
          ),
          actions: [
            TextButton(
              key: const Key('btn_cancel_simple_delete'),
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const Key('btn_confirm_simple_delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.costRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                bloc.add(DeleteIngredient(id: ing.id));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Insumo "${ing.name}" eliminado.'),
                    backgroundColor: AppColors.textEspresso,
                  ),
                );
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.ingredient != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Insumo' : 'Registrar Insumo a Granel'),
        actions: [
          IconButton(
            key: const Key('btn_ingredient_hide_keyboard'),
            icon: const Icon(Icons.keyboard_hide),
            tooltip: 'Ocultar Teclado',
            onPressed: () => FocusScope.of(context).unfocus(),
          ),
          if (isEditing)
            IconButton(
              key: const Key('btn_delete_ingredient_form'),
              icon: const Icon(Icons.delete_outline, color: AppColors.costRed),
              tooltip: 'Eliminar Insumo',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: AppBreakpoints.maxFormWidth,
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // Banner de Normalización en Tiempo Real
              _buildNormalizationBanner(),
              const SizedBox(height: 20),

              // Nombre
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Insumo *',
                  hintText: 'Ej. Harina de Trigo Especial, Leche Entera',
                  prefixIcon: Icon(Icons.bakery_dining_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'El nombre del insumo es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Categoría
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoría Culinaria *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),

              // Unidad Comercial de Compra y Cantidad (Adaptive Stack or Row)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 450;

                  final unitDropdown = DropdownButtonFormField<String>(
                    initialValue: _selectedUnit,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unidad Comercial *',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                    items: commercialUnits.map((item) {
                      return DropdownMenuItem(
                        value: item['value']!,
                        child: Text(
                          '${item['label']} [${item['group']}]',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedUnit = val);
                        _recalculateNormalization();
                      }
                    },
                  );

                  final quantityField = TextFormField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad *',
                      hintText: 'Ej. 50, 1, 30',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                    onChanged: (_) => _recalculateNormalization(),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Requerido';
                      }
                      try {
                        final parsed = PreciseDecimal.fromString(val.trim());
                        if (parsed <= PreciseDecimal.zero) {
                          return 'Debe ser > 0';
                        }
                      } catch (_) {
                        return 'Número inválido';
                      }
                      return null;
                    },
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        unitDropdown,
                        const SizedBox(height: 16),
                        quantityField,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: unitDropdown,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: quantityField,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

            // Costo Total Pagado
            TextFormField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Costo Total Pagado de Adquisición *',
                hintText: 'Ej. 45.00, 1.50, 6.00',
                prefixIcon: Icon(Icons.attach_money),
              ),
              onChanged: (_) => _recalculateNormalization(),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'El costo pagado es obligatorio';
                }
                try {
                  final parsed = PreciseDecimal.fromString(val.trim());
                  if (parsed <= PreciseDecimal.zero) {
                    return 'El costo debe ser estrictamente > 0';
                  }
                } catch (_) {
                  return 'Monto decimal no válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Porcentaje de Merma / Desperdicio
            TextFormField(
              controller: _wasteController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Porcentaje de Merma (%)',
                hintText: 'Ej. 0, 5.0, 10.0',
                suffixText: '%',
                prefixIcon: Icon(Icons.delete_sweep_outlined),
              ),
              onChanged: (_) => _recalculateNormalization(),
              validator: (val) {
                if (val != null && val.trim().isNotEmpty) {
                  try {
                    final parsed = PreciseDecimal.fromString(val.trim());
                    if (parsed < PreciseDecimal.zero ||
                        parsed >= PreciseDecimal.fromInt(100)) {
                      return 'Merma debe estar entre 0% y 99.9%';
                    }
                  } catch (_) {
                    return 'Porcentaje inválido';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Chips rápidos de merma
            Wrap(
              spacing: 8,
              children: [0, 2, 5, 10, 15].map((preset) {
                return ActionChip(
                  label: Text('$preset%'),
                  onPressed: () {
                    _wasteController.text = preset.toString();
                    _recalculateNormalization();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Matriz de Densidad Culinaria (BR-DEN-01, BR-DEN-02, BR-DEN-03)
            Card(
              elevation: 0,
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.scale_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Matriz de Densidad Culinaria (Volumen a Peso)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Permite costear con exactitud recetas en tazas, cucharadas o ml cuando compras por kilo o libra.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // Preajuste dropdown
                    DropdownButtonFormField<String?>(
                      key: const Key('density_preset_dropdown'),
                      isExpanded: true,
                      initialValue: _selectedDensityPresetKey,
                      decoration: const InputDecoration(
                        labelText: 'Preajuste de Densidad Pastelera',
                        prefixIcon: Icon(Icons.bookmark_added_outlined),
                      ),
                      items: densityPresets.map((preset) {
                        return DropdownMenuItem<String?>(
                          value: preset['key'] as String?,
                          child: Text(
                            preset['label'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedDensityPresetKey = val;
                          if (val != null && val != 'custom') {
                            final match = densityPresets.firstWhere(
                              (p) => p['key'] == val,
                              orElse: () => {},
                            );
                            if (match['gPerMl'] != null) {
                              _densityController.text = match['gPerMl'] as String;
                            }
                          } else if (val == null) {
                            _densityController.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Campo de densidad en g/ml
                    TextFormField(
                      key: const Key('density_g_ml_input'),
                      controller: _densityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Densidad del Insumo (g/ml)',
                        hintText: 'Ej. 0.5208 (125 g/taza), 0.8333, 1.0000',
                        prefixIcon: const Icon(Icons.science_outlined),
                        suffixText: 'g/ml',
                        helperText: _getDensityHelperText(),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          try {
                            final d = PreciseDecimal.fromString(val.trim());
                            if (d <= PreciseDecimal.zero) {
                              return 'La densidad debe ser estrictamente > 0';
                            }
                          } catch (_) {
                            return 'Densidad numérica no válida';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notas opcionales
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: const InputDecoration(
                labelText: 'Notas u Observaciones (Opcional)',
                hintText: 'Marca comercial, proveedor o lote',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),

            const SizedBox(height: 28),

            // Botón de Guardar (Touch Target >= 48px)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                key: const Key('btn_save_ingredient'),
                onPressed: _saveIngredient,
                icon: const Icon(Icons.save),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isEditing ? 'Actualizar Insumo' : 'Registrar Insumo a Granel',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildNormalizationBanner() {
    final hasValidCalculation = _previewMinCost > PreciseDecimal.zero;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasValidCalculation
            ? AppColors.surfaceHighlight
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValidCalculation
              ? AppColors.primaryCaramel
              : AppColors.borderWarm,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calculate_outlined,
                color: hasValidCalculation
                    ? AppColors.primaryDarkCaramel
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Normalización Automática a Unidad Mínima (RF-SYS-02)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textEspresso,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hasValidCalculation
                        ? '\$${_previewMinCost.toStringAsFixed(6)} / $_previewBaseUnit'
                        : '-- / $_previewBaseUnit',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: hasValidCalculation
                          ? AppColors.primaryDarkCaramel
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.borderWarm.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Base: $_previewBaseUnit',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          if (hasValidCalculation) ...[
            const SizedBox(height: 8),
            Text(
              'Conversión: ${_quantityController.text.trim()} $_selectedUnit = ${_previewBaseQty.toStringAsFixed(2)} $_previewBaseUnit brutas'
              '${_previewEffectiveQty < _previewBaseQty ? ' (Efectivas con merma: ${_previewEffectiveQty.toStringAsFixed(2)} $_previewBaseUnit)' : ''}',
              softWrap: true,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _getDensityHelperText() {
    final text = _densityController.text.trim();
    if (text.isEmpty) {
      return 'Opcional. Permite convertir tazas o ml a gramos exactos.';
    }
    try {
      final d = PreciseDecimal.fromString(text);
      if (d > PreciseDecimal.zero) {
        final gPerCup = d * UnitConverter.mlPerCup;
        return '≈ ${gPerCup.toStringAsFixed(1)} g por taza estándar (240 ml)';
      }
    } catch (_) {}
    return null;
  }
}

