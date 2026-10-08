import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../domain/entities/ingredient.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';

class IngredientFormScreen extends StatefulWidget {
  final Ingredient? ingredient;

  const IngredientFormScreen({super.key, this.ingredient});

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

  late String _selectedCategory;
  late String _selectedUnit;

  // Calculation state preview
  PreciseDecimal _previewMinCost = PreciseDecimal.zero;
  String _previewBaseUnit = 'g';
  PreciseDecimal _previewBaseQty = PreciseDecimal.zero;
  PreciseDecimal _previewEffectiveQty = PreciseDecimal.zero;

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
    _nameController = TextEditingController(text: ing?.name ?? '');
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
      notes: notes.isNotEmpty ? notes : null,
      updatedAt: DateTime.now(),
    );

    if (isEditing) {
      context.read<CatalogBloc>().add(UpdateIngredient(ingredientToSave));
    } else {
      context.read<CatalogBloc>().add(AddIngredient(ingredientToSave));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing
              ? 'Insumo "$name" actualizado exitosamente (${minCost.toCurrencyString()}/$baseUnit)'
              : 'Insumo "$name" registrado exitosamente (${minCost.toCurrencyString()}/$baseUnit)',
        ),
        backgroundColor: AppColors.profitGreen,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.ingredient != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Insumo' : 'Registrar Insumo a Granel'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Banner de Normalización en Tiempo Real
            _buildNormalizationBanner(),
            const SizedBox(height: 20),

            // Nombre
            TextFormField(
              controller: _nameController,
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
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoría Culinaria *',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: categories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),

            // Fila: Unidad Comercial de Compra y Cantidad
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unidad Comercial *',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                    items: commercialUnits.map((item) {
                      return DropdownMenuItem(
                        value: item['value']!,
                        child: Text('${item['label']} [${item['group']}]'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedUnit = val);
                        _recalculateNormalization();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad *',
                      hintText: 'Ej. 50, 1, 30',
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Costo Total Pagado
            TextFormField(
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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

            // Notas opcionales
            TextFormField(
              controller: _notesController,
              maxLines: 2,
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
                onPressed: _saveIngredient,
                icon: const Icon(Icons.save),
                label: Text(
                  isEditing ? 'Actualizar Insumo' : 'Registrar Insumo a Granel',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
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
            : AppColors.backgroundCard,
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
              const Text(
                'Normalización Automática a Unidad Mínima (RF-SYS-02)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textEspresso,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
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
              Text(
                'Base: $_previewBaseUnit',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (hasValidCalculation) ...[
            const SizedBox(height: 6),
            Text(
              'Conversión: ${_quantityController.text.trim()} $_selectedUnit = ${_previewBaseQty.toStringAsFixed(2)} $_previewBaseUnit brutas'
              '${_previewEffectiveQty < _previewBaseQty ? ' (Efectivas con merma: ${_previewEffectiveQty.toStringAsFixed(2)} $_previewBaseUnit)' : ''}',
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
}
