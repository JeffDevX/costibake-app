import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../domain/entities/packaging.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';

class PackagingFormScreen extends StatefulWidget {
  final Packaging? packaging;

  const PackagingFormScreen({super.key, this.packaging});

  @override
  State<PackagingFormScreen> createState() => _PackagingFormScreenState();
}

class _PackagingFormScreenState extends State<PackagingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _costController;
  late TextEditingController _unitsController;
  late TextEditingController _notesController;

  late String _selectedCategory;

  // Real-time calculation preview state
  PreciseDecimal _previewUnitCost = PreciseDecimal.zero;

  static const List<String> categories = [
    'Cajas para Pastel',
    'Bases y Blondas',
    'Domos y Contenedores',
    'Capacillos y Pirotines',
    'Cintas y Decoración',
    'Bolsas y Mangas',
    'Otros Descartables',
  ];

  static const List<int> commonUnitPresets = [1, 10, 12, 20, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    final p = widget.packaging;
    _nameController = TextEditingController(text: p?.name ?? '');
    _costController = TextEditingController(
      text: p != null ? p.packageCost.toString() : '',
    );
    _unitsController = TextEditingController(
      text: p != null ? p.unitsPerPackage.toString() : '',
    );
    _notesController = TextEditingController(text: p?.notes ?? '');

    _selectedCategory = p?.category ?? categories.first;

    _recalculateUnitCost();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _unitsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recalculateUnitCost() {
    final costStr = _costController.text.trim();
    final unitsStr = _unitsController.text.trim();

    try {
      final cost = costStr.isNotEmpty
          ? PreciseDecimal.fromString(costStr)
          : PreciseDecimal.zero;
      final units = unitsStr.isNotEmpty ? int.tryParse(unitsStr) ?? 0 : 0;

      if (cost > PreciseDecimal.zero && units > 0) {
        final unitCost = Packaging.calculateUnitCost(
          packageCost: cost,
          unitsPerPackage: units,
        );

        setState(() {
          _previewUnitCost = unitCost;
        });
        return;
      }
    } catch (_) {
      // Ignored for incomplete typing
    }

    setState(() {
      _previewUnitCost = PreciseDecimal.zero;
    });
  }

  void _savePackaging() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final cost = PreciseDecimal.fromString(_costController.text.trim());
    final units = int.parse(_unitsController.text.trim());
    final notes = _notesController.text.trim();

    final unitCost = Packaging.calculateUnitCost(
      packageCost: cost,
      unitsPerPackage: units,
    );

    final isEditing = widget.packaging != null;
    final packagingToSave = Packaging(
      id: widget.packaging?.id ?? const Uuid().v4(),
      name: name,
      category: _selectedCategory,
      packageCost: cost,
      unitsPerPackage: units,
      unitCost: unitCost,
      notes: notes.isNotEmpty ? notes : null,
      updatedAt: DateTime.now(),
    );

    if (isEditing) {
      context.read<CatalogBloc>().add(UpdatePackaging(packagingToSave));
    } else {
      context.read<CatalogBloc>().add(AddPackaging(packagingToSave));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing
              ? 'Empaque "$name" actualizado exitosamente (${unitCost.toCurrencyString()}/u)'
              : 'Empaque "$name" registrado exitosamente (${unitCost.toCurrencyString()}/u)',
        ),
        backgroundColor: AppColors.profitGreen,
      ),
    );

    Navigator.pop(context);
  }

  void _confirmDelete() {
    final p = widget.packaging;
    if (p == null) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Eliminar Empaque'),
          content: Text(
            '¿Estás seguro de que deseas eliminar "${p.name}"? '
            'Si está siendo utilizado en recetas formuladas, el sistema bloqueará el borrado para proteger tus costos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.costRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                context.read<CatalogBloc>().add(DeletePackaging(p.id));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Empaque "${p.name}" eliminado.'),
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
    final isEditing = widget.packaging != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Empaque' : 'Registrar Empaque'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.costRed),
              tooltip: 'Eliminar Empaque',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: AppBreakpoints.maxFormWidth,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // Banner de Cálculo Unitario en Tiempo Real (BR-EMP-01, BR-EMP-04)
              _buildUnitCostBanner(),
              const SizedBox(height: 20),

              // Nombre del Empaque
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Empaque / Descartable *',
                  hintText: 'Ej. Caja para Pastel 10", Domo Cupcakes x6',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'El nombre del empaque es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Categoría del Empaque
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoría de Empaque *',
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

              // Disposición Adaptativa: Costo del Paquete y Unidades por Paquete
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 450;

                  final costField = TextFormField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Costo Total del Paquete *',
                      hintText: 'Ej. 25.00, 3.50',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    onChanged: (_) => _recalculateUnitCost(),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'El costo es obligatorio';
                      }
                      try {
                        final parsed = PreciseDecimal.fromString(val.trim());
                        if (parsed <= PreciseDecimal.zero) {
                          return 'Debe ser > 0';
                        }
                      } catch (_) {
                        return 'Monto inválido';
                      }
                      return null;
                    },
                  );

                  final unitsField = TextFormField(
                    controller: _unitsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Unidades por Paquete *',
                      hintText: 'Ej. 50, 100, 12',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                    onChanged: (_) => _recalculateUnitCost(),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Requerido';
                      }
                      final parsed = int.tryParse(val.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Entero > 0';
                      }
                      return null;
                    },
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        costField,
                        const SizedBox(height: 16),
                        unitsField,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: costField),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: unitsField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),

              // Presets rápidos de unidades comunes
              Wrap(
                spacing: 8,
                children: commonUnitPresets.map((preset) {
                  return ActionChip(
                    label: Text('$preset pzas'),
                    onPressed: () {
                      _unitsController.text = preset.toString();
                      _recalculateUnitCost();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Dimensiones / Notas (BR-EMP-03)
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Dimensiones / Notas (Opcional)',
                  hintText: 'Ej. Compatible molde 10", base MDF dorada 3mm, marca X',
                  prefixIcon: Icon(Icons.straighten_outlined),
                ),
              ),
              const SizedBox(height: 28),

              // Botón de Guardado (Kitchen touch standard >= 48px)
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _savePackaging,
                  icon: const Icon(Icons.save),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isEditing ? 'Actualizar Empaque' : 'Registrar Empaque',
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

  Widget _buildUnitCostBanner() {
    final hasValidCalculation = _previewUnitCost > PreciseDecimal.zero;

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
                  'Costo Unitario por Pieza (RF-SYS-03, BR-EMP-01)',
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
                        ? '\$${_previewUnitCost.toStringAsFixed(4)} / pieza'
                        : '-- / pieza',
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
                  hasValidCalculation
                      ? '${_previewUnitCost.toCurrencyString()}/u'
                      : 'Sin calcular',
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
              'Prorrateo: ${_costController.text.trim()} pagados entre ${_unitsController.text.trim()} piezas',
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
}
