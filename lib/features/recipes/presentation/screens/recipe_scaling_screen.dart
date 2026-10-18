import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../domain/entities/mold_preset.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/scaled_recipe_result.dart';
import '../../domain/services/scaling_engine.dart';
import '../bloc/recipes_bloc.dart';
import '../bloc/recipes_event.dart';

/// Interactive screen for geometric and proportional recipe scaling (JEF-14, RF-SYS-12, RF-SYS-13, BR-ESC-01..04).
/// Supports:
/// 1. Circular Mold scaling (diameter & optional height)
/// 2. Rectangular Mold scaling (length x width & optional height)
/// 3. Direct Multiplier (0.5x, 1.5x, 2x, etc.)
/// 4. Target Portions scaling
/// Provides a live "Production of the Day" checklist view and "Save as Variant Recipe" persistence.
class RecipeScalingScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeScalingScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeScalingScreen> createState() => _RecipeScalingScreenState();
}

class _RecipeScalingScreenState extends State<RecipeScalingScreen> {
  late ScalingMode _scalingMode;

  // Circular mold state
  late MoldPreset _originCircularPreset;
  late MoldPreset _targetCircularPreset;
  late TextEditingController _originDiameterController;
  late TextEditingController _targetDiameterController;

  // Rectangular mold state
  late MoldPreset _originRectPreset;
  late MoldPreset _targetRectPreset;
  late TextEditingController _originLengthController;
  late TextEditingController _originWidthController;
  late TextEditingController _targetLengthController;
  late TextEditingController _targetWidthController;

  // Height variation state (RF-SYS-13)
  bool _useCustomHeight = false;
  late TextEditingController _originHeightController;
  late TextEditingController _targetHeightController;

  // Direct multiplier state
  late TextEditingController _multiplierController;

  // Target portions state
  late TextEditingController _targetPortionsController;

  // Labor time handling (JEF-24)
  bool _scaleLaborProportionally = false;
  late TextEditingController _prepTimeOverrideController;

  // Production checklist state (ingredient IDs checked off during kitchen prep)
  final Set<String> _checkedItemIds = {};

  static const List<String> _quickMultipliers = [
    '0.5',
    '1.5',
    '2',
    '2.5',
    '3',
    '4',
  ];

  static const List<int> _quickPortions = [6, 8, 12, 16, 20, 25, 30, 50];

  @override
  void initState() {
    super.initState();

    // Determine initial mold preset from recipe if available
    final matchedPreset = MoldPreset.tryMatchFromRecipe(
      widget.recipe.moldType,
      widget.recipe.moldDimension,
    );

    if (matchedPreset != null &&
        matchedPreset.shape == MoldShape.rectangular) {
      _scalingMode = ScalingMode.rectangularMold;
      _originRectPreset = matchedPreset;
    } else {
      _scalingMode = ScalingMode.circularMold;
      _originRectPreset = MoldPreset.rectangularPresets[1]; // 20x20 cm default
    }

    if (matchedPreset != null && matchedPreset.shape == MoldShape.circular) {
      _originCircularPreset = matchedPreset;
    } else {
      // Default origin circular preset: 6" (15 cm) or 8" (20 cm)
      _originCircularPreset = MoldPreset.circularPresets[1]; // 6" (15 cm)
    }

    // Default target circular preset: 10" (25 cm) if origin is 6", else 10" or 12"
    _targetCircularPreset = _originCircularPreset.id == 'round_10in'
        ? MoldPreset.circularPresets[5] // 12"
        : MoldPreset.circularPresets[4]; // 10" (25 cm)

    _targetRectPreset = _originRectPreset.id == 'rect_20x30'
        ? MoldPreset.rectangularPresets[4] // 30x40 cm
        : MoldPreset.rectangularPresets[2]; // 20x30 cm

    _originDiameterController = TextEditingController(
      text: _originCircularPreset.diameterInches?.toStringAsFixed(0) ?? '6',
    );
    _targetDiameterController = TextEditingController(
      text: _targetCircularPreset.diameterInches?.toStringAsFixed(0) ?? '10',
    );

    _originLengthController = TextEditingController(
      text: _originRectPreset.lengthCm?.toStringAsFixed(0) ?? '20',
    );
    _originWidthController = TextEditingController(
      text: _originRectPreset.widthCm?.toStringAsFixed(0) ?? '20',
    );
    _targetLengthController = TextEditingController(
      text: _targetRectPreset.lengthCm?.toStringAsFixed(0) ?? '30',
    );
    _targetWidthController = TextEditingController(
      text: _targetRectPreset.widthCm?.toStringAsFixed(0) ?? '20',
    );

    _originHeightController = TextEditingController(text: '5');
    _targetHeightController = TextEditingController(text: '5');

    _multiplierController = TextEditingController(text: '2');
    _targetPortionsController = TextEditingController(
      text: (widget.recipe.yieldPortions * 2).toString(),
    );
    _prepTimeOverrideController = TextEditingController(
      text: widget.recipe.prepTimeMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _originDiameterController.dispose();
    _targetDiameterController.dispose();
    _originLengthController.dispose();
    _originWidthController.dispose();
    _targetLengthController.dispose();
    _targetWidthController.dispose();
    _originHeightController.dispose();
    _targetHeightController.dispose();
    _multiplierController.dispose();
    _targetPortionsController.dispose();
    _prepTimeOverrideController.dispose();
    super.dispose();
  }

  BusinessConfig get _effectiveBusinessConfig {
    try {
      final state = context.watch<SettingsBloc>().state;
      if (state is SettingsLoaded) {
        return state.config;
      }
    } catch (_) {
      // Fallback when SettingsBloc is not provided in isolated widget tests
    }
    return BusinessConfig(
      id: 'default',
      businessName: 'Mi Taller de Repostería',
      currencySymbol: r'$',
      laborHourlyRate: PreciseDecimal.fromInt(10),
      overheadPercentage: PreciseDecimal.fromInt(15),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  PreciseDecimal _computeActiveScaleFactor() {
    final hOrig = _useCustomHeight
        ? PreciseDecimal.tryParse(_originHeightController.text.trim())
        : null;
    final hTarg = _useCustomHeight
        ? PreciseDecimal.tryParse(_targetHeightController.text.trim())
        : null;
    final validHeights = hOrig != null &&
        hTarg != null &&
        hOrig > PreciseDecimal.zero &&
        hTarg > PreciseDecimal.zero;

    switch (_scalingMode) {
      case ScalingMode.circularMold:
        final dOrig =
            PreciseDecimal.tryParse(_originDiameterController.text.trim()) ??
                PreciseDecimal.fromInt(6);
        final dTarg =
            PreciseDecimal.tryParse(_targetDiameterController.text.trim()) ??
                PreciseDecimal.fromInt(10);
        if (dOrig <= PreciseDecimal.zero || dTarg <= PreciseDecimal.zero) {
          return PreciseDecimal.one;
        }
        return ScalingEngine.calculateCircularScaleFactor(
          dOrig,
          dTarg,
          hOrigin: validHeights ? hOrig : null,
          hTarget: validHeights ? hTarg : null,
        );

      case ScalingMode.rectangularMold:
        final lOrig =
            PreciseDecimal.tryParse(_originLengthController.text.trim()) ??
                PreciseDecimal.fromInt(20);
        final wOrig =
            PreciseDecimal.tryParse(_originWidthController.text.trim()) ??
                PreciseDecimal.fromInt(20);
        final lTarg =
            PreciseDecimal.tryParse(_targetLengthController.text.trim()) ??
                PreciseDecimal.fromInt(30);
        final wTarg =
            PreciseDecimal.tryParse(_targetWidthController.text.trim()) ??
                PreciseDecimal.fromInt(20);
        if (lOrig <= PreciseDecimal.zero ||
            wOrig <= PreciseDecimal.zero ||
            lTarg <= PreciseDecimal.zero ||
            wTarg <= PreciseDecimal.zero) {
          return PreciseDecimal.one;
        }
        return ScalingEngine.calculateRectangularScaleFactor(
          lOrigin: lOrig,
          wOrigin: wOrig,
          lTarget: lTarg,
          wTarget: wTarg,
          hOrigin: validHeights ? hOrig : null,
          hTarget: validHeights ? hTarg : null,
        );

      case ScalingMode.directMultiplier:
        final mult =
            PreciseDecimal.tryParse(_multiplierController.text.trim()) ??
                PreciseDecimal.one;
        if (mult <= PreciseDecimal.zero) return PreciseDecimal.one;
        return mult;

      case ScalingMode.targetPortions:
        final targetP =
            int.tryParse(_targetPortionsController.text.trim()) ??
                widget.recipe.yieldPortions;
        if (targetP <= 0 || widget.recipe.yieldPortions <= 0) {
          return PreciseDecimal.one;
        }
        return ScalingEngine.calculatePortionsScaleFactor(
          widget.recipe.yieldPortions,
          targetP,
        );
    }
  }

  String _resolveTargetMoldType() {
    switch (_scalingMode) {
      case ScalingMode.circularMold:
        return 'Redondo';
      case ScalingMode.rectangularMold:
        return _targetRectPreset.moldTypeLabel;
      case ScalingMode.directMultiplier:
      case ScalingMode.targetPortions:
        return widget.recipe.moldType ?? 'Personalizado';
    }
  }

  String _resolveTargetMoldDimension() {
    switch (_scalingMode) {
      case ScalingMode.circularMold:
        final dTarg = _targetDiameterController.text.trim();
        // Check if matches a circular preset
        for (final preset in MoldPreset.circularPresets) {
          if (preset.diameterInches?.toStringAsFixed(0) == dTarg) {
            return preset.dimensionLabel;
          }
        }
        return '$dTarg"';
      case ScalingMode.rectangularMold:
        final l = _targetLengthController.text.trim();
        final w = _targetWidthController.text.trim();
        return '${w}x$l cm';
      case ScalingMode.directMultiplier:
        return '${_multiplierController.text.trim()}x Lote';
      case ScalingMode.targetPortions:
        return '${_targetPortionsController.text.trim()} porciones';
    }
  }

  ScaledRecipeResult _buildScaledResult() {
    final factor = _computeActiveScaleFactor();
    final int? targetPortionsOverride =
        _scalingMode == ScalingMode.targetPortions
            ? int.tryParse(_targetPortionsController.text.trim())
            : null;
    final int? customPrep = !_scaleLaborProportionally
        ? int.tryParse(_prepTimeOverrideController.text.trim())
        : null;

    return ScalingEngine.scaleRecipe(
      recipe: widget.recipe,
      scalingMode: _scalingMode,
      scaleFactor: factor,
      businessConfig: _effectiveBusinessConfig,
      targetYieldPortionsOverride: targetPortionsOverride,
      targetMoldType: _resolveTargetMoldType(),
      targetMoldDimension: _resolveTargetMoldDimension(),
      customPrepTimeMinutes: customPrep,
      scaleLaborProportionally: _scaleLaborProportionally,
    );
  }

  String _suggestVariantName(ScaledRecipeResult result) {
    final dim = result.targetMoldDimension ??
        '${result.scaleFactor.toStringAsFixed(2)}x';
    return '${widget.recipe.name} ($dim)';
  }

  Future<void> _showSaveVariantDialog(ScaledRecipeResult result) async {
    final nameController = TextEditingController(
      text: _suggestVariantName(result),
    );

    final confirmedName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Guardar como Receta Variante'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se creará una nueva receta independiente en tu recetario con las cantidades y molde escalados:',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('field_variant_recipe_name'),
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Nueva Receta',
                  prefixIcon: Icon(Icons.menu_book),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              key: const Key('btn_confirm_save_variant'),
              onPressed: () {
                final text = nameController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(ctx, text);
                }
              },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Guardar Variante'),
            ),
          ],
        );
      },
    );

    if (confirmedName != null && mounted) {
      const uuid = Uuid();
      final variantRecipe = result.toVariantRecipe(
        newRecipeId: uuid.v4(),
        variantName: confirmedName,
        idGenerator: () => uuid.v4(),
      );

      try {
        context.read<RecipesBloc>().add(CreateRecipe(variantRecipe));
      } catch (_) {
        // Ignore if RecipesBloc is not mounted in standalone widget tests
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receta variante "$confirmedName" guardada con éxito.'),
          backgroundColor: AppColors.profitGreen,
        ),
      );
      Navigator.pop(context, variantRecipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _buildScaledResult();
    final currency = _effectiveBusinessConfig.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escalar Receta y Molde'),
        actions: [
          IconButton(
            key: const Key('btn_scaling_hide_keyboard'),
            icon: const Icon(Icons.keyboard_hide),
            tooltip: 'Ocultar Teclado',
            onPressed: () => FocusScope.of(context).unfocus(),
          ),
        ],
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
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('btn_production_only'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.checklist_rtl, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Solo Producción'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('btn_save_as_variant'),
                    onPressed: () => _showSaveVariantDialog(result),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Guardar Variante'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: AppBreakpoints.maxContentWidth,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Base Recipe Header Card
              _buildOriginRecipeSummaryCard(currency, result),
              const SizedBox(height: 16),

              // 2. Scaling Mode Selector & Geometric Inputs Card
              _buildScalingControlsCard(),
              const SizedBox(height: 16),

              // 3. Real-time Factor & Financial Cost Comparison Banner (BR-ESC-04)
              _buildScaleFactorAndCostComparisonCard(result, currency),
              const SizedBox(height: 16),

              // 4. Scaled Ingredients & Production Checklist (BR-ESC-01, BR-ESC-03)
              _buildScaledIngredientsCard(result, currency),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOriginRecipeSummaryCard(
    String currency,
    ScaledRecipeResult result,
  ) {
    final origMold = widget.recipe.moldDimension != null &&
            widget.recipe.moldDimension!.trim().isNotEmpty
        ? '${widget.recipe.moldType ?? 'Molde'} ${widget.recipe.moldDimension}'
        : (widget.recipe.moldType ?? 'Sin molde especificado');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cake_outlined,
                  color: AppColors.primaryCaramel,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.recipe.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Base: $origMold • ${widget.recipe.yieldPortions} porciones • Costo Base: ${result.originalCostBreakdown.totalProductionCost.toCurrencyString(symbol: currency)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScalingControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modo de Escalado Geométrico / Proporcional',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textEspresso,
              ),
            ),
            const SizedBox(height: 10),

            // Mode selector chips (BR-ESC-02)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ScalingMode.values.map((mode) {
                final isSelected = _scalingMode == mode;
                return ChoiceChip(
                  key: Key('scaling_mode_chip_${mode.name}'),
                  label: Text(mode.displayName),
                  selected: isSelected,
                  selectedColor: AppColors.butterCream,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primaryDarkCaramel
                        : AppColors.textEspresso,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryCaramel
                        : AppColors.borderWarm,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _scalingMode = mode);
                    }
                  },
                );
              }).toList(),
            ),
            const Divider(height: 24),

            // Mode-specific configuration
            if (_scalingMode == ScalingMode.circularMold)
              _buildCircularMoldControls(),
            if (_scalingMode == ScalingMode.rectangularMold)
              _buildRectangularMoldControls(),
            if (_scalingMode == ScalingMode.directMultiplier)
              _buildDirectMultiplierControls(),
            if (_scalingMode == ScalingMode.targetPortions)
              _buildTargetPortionsControls(),

            const SizedBox(height: 12),

            // Labor time rule control (JEF-24)
            _buildLaborTimeScalingControl(),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularMoldControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fórmula Área Circular: Factor = (Diámetro Destino / Diámetro Origen)²',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),

        // Origin Circular Mold
        DropdownButtonFormField<MoldPreset>(
          key: const Key('dropdown_origin_circular_mold'),
          initialValue: _originCircularPreset,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Molde Redondo Origen (Receta Base)',
            prefixIcon: Icon(Icons.radio_button_unchecked),
          ),
          items: MoldPreset.circularPresets.map((preset) {
            return DropdownMenuItem(
              value: preset,
              child: Text(
                preset.name,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (preset) {
            if (preset != null) {
              setState(() {
                _originCircularPreset = preset;
                _originDiameterController.text =
                    preset.diameterInches?.toStringAsFixed(0) ?? '6';
              });
            }
          },
        ),
        const SizedBox(height: 12),

        // Target Circular Mold
        DropdownButtonFormField<MoldPreset>(
          key: const Key('dropdown_target_circular_mold'),
          initialValue: _targetCircularPreset,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Molde Redondo Destino (Nuevo Tamaño)',
            prefixIcon: Icon(Icons.adjust),
          ),
          items: MoldPreset.circularPresets.map((preset) {
            return DropdownMenuItem(
              value: preset,
              child: Text(
                preset.name,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (preset) {
            if (preset != null) {
              setState(() {
                _targetCircularPreset = preset;
                _targetDiameterController.text =
                    preset.diameterInches?.toStringAsFixed(0) ?? '10';
              });
            }
          },
        ),
        const SizedBox(height: 10),

        // Quick Target Diameter Preset Chips
        const Text(
          'Selección rápida de molde destino:',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: MoldPreset.circularPresets.map((preset) {
            final inVal = preset.diameterInches?.toStringAsFixed(0) ?? '';
            final isSelected = _targetDiameterController.text.trim() == inVal;
            return FilterChip(
              key: Key('quick_circular_target_$inVal'),
              label: Text(preset.dimensionLabel),
              selected: isSelected,
              selectedColor: AppColors.butterCream,
              onSelected: (_) {
                setState(() {
                  _targetCircularPreset = preset;
                  _targetDiameterController.text = inVal;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Direct custom diameter inputs (inches or cm; ratio is unit-invariant!)
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('field_origin_diameter'),
                controller: _originDiameterController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Diámetro Origen',
                  suffixText: 'in/cm',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: const Key('field_target_diameter'),
                controller: _targetDiameterController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Diámetro Destino',
                  suffixText: 'in/cm',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildHeightVariationSection(),
      ],
    );
  }

  Widget _buildRectangularMoldControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fórmula Rectangular: Factor = (Largo₂ × Ancho₂) / (Largo₁ × Ancho₁)',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<MoldPreset>(
          key: const Key('dropdown_origin_rect_mold'),
          initialValue: _originRectPreset,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Molde Rectangular Origen',
            prefixIcon: Icon(Icons.crop_square),
          ),
          items: MoldPreset.rectangularPresets.map((preset) {
            return DropdownMenuItem(
              value: preset,
              child: Text(preset.name, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (preset) {
            if (preset != null) {
              setState(() {
                _originRectPreset = preset;
                _originLengthController.text =
                    preset.lengthCm?.toStringAsFixed(0) ?? '20';
                _originWidthController.text =
                    preset.widthCm?.toStringAsFixed(0) ?? '20';
              });
            }
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('field_origin_length'),
                controller: _originLengthController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Largo Origen (cm)',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                key: const Key('field_origin_width'),
                controller: _originWidthController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Ancho Origen (cm)',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        DropdownButtonFormField<MoldPreset>(
          key: const Key('dropdown_target_rect_mold'),
          initialValue: _targetRectPreset,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Molde Rectangular Destino',
            prefixIcon: Icon(Icons.crop_16_9),
          ),
          items: MoldPreset.rectangularPresets.map((preset) {
            return DropdownMenuItem(
              value: preset,
              child: Text(preset.name, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (preset) {
            if (preset != null) {
              setState(() {
                _targetRectPreset = preset;
                _targetLengthController.text =
                    preset.lengthCm?.toStringAsFixed(0) ?? '30';
                _targetWidthController.text =
                    preset.widthCm?.toStringAsFixed(0) ?? '20';
              });
            }
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('field_target_length'),
                controller: _targetLengthController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Largo Destino (cm)',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                key: const Key('field_target_width'),
                controller: _targetWidthController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Ancho Destino (cm)',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildHeightVariationSection(),
      ],
    );
  }

  Widget _buildHeightVariationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterChip(
          key: const Key('toggle_custom_height'),
          label: const Text('Incluir variación de altura de molde (Volumen 3D)'),
          selected: _useCustomHeight,
          selectedColor: AppColors.butterCream,
          onSelected: (val) => setState(() => _useCustomHeight = val),
        ),
        if (_useCustomHeight) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('field_origin_height'),
                  controller: _originHeightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Altura Origen (cm)',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const Key('field_target_height'),
                  controller: _targetHeightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Altura Destino (cm)',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDirectMultiplierControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona un factor multiplicador directo sobre el lote:',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _quickMultipliers.map((m) {
            final isSelected = _multiplierController.text.trim() == m;
            return ChoiceChip(
              key: Key('multiplier_chip_$m'),
              label: Text('${m}x'),
              selected: isSelected,
              selectedColor: AppColors.butterCream,
              onSelected: (_) {
                setState(() => _multiplierController.text = m);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('field_direct_multiplier'),
          controller: _multiplierController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Factor Multiplicador Personalizado',
            prefixIcon: Icon(Icons.close),
            suffixText: 'x',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildTargetPortionsControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rendimiento original de la receta: ${widget.recipe.yieldPortions} porciones',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _quickPortions.map((p) {
            final isSelected =
                _targetPortionsController.text.trim() == p.toString();
            return ChoiceChip(
              key: Key('portions_chip_$p'),
              label: Text('$p porc.'),
              selected: isSelected,
              selectedColor: AppColors.butterCream,
              onSelected: (_) {
                setState(() => _targetPortionsController.text = p.toString());
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('field_target_portions'),
          controller: _targetPortionsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número de Porciones Deseadas',
            prefixIcon: Icon(Icons.pie_chart_outline),
            suffixText: 'porciones',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildLaborTimeScalingControl() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: AppColors.primaryDarkCaramel,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Tiempo de Mano de Obra al Escalar (JEF-24)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textEspresso,
                  ),
                ),
              ),
              FilterChip(
                key: const Key('chip_scale_labor'),
                label: const Text(
                  'Proporcional',
                  style: TextStyle(fontSize: 11),
                ),
                selected: _scaleLaborProportionally,
                selectedColor: AppColors.butterCream,
                visualDensity: VisualDensity.compact,
                onSelected: (val) {
                  setState(() => _scaleLaborProportionally = val);
                },
              ),
            ],
          ),
          if (!_scaleLaborProportionally) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Minutos de preparación para este lote:',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    key: const Key('field_scaled_prep_time'),
                    controller: _prepTimeOverrideController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: const InputDecoration(
                      suffixText: 'min',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScaleFactorAndCostComparisonCard(
    ScaledRecipeResult result,
    String currency,
  ) {
    final factorFormatted = result.scaleFactor.toStringAsFixed(4);
    final shortFactor = result.scaleFactor.toStringAsFixed(2);
    final suggestedBatchPrice =
        result.scaledCostBreakdown.pricing?.effectiveBatchPrice ??
            result.scaledCostBreakdown.suggestedBatchPrice;
    final suggestedPortionPrice =
        result.scaledCostBreakdown.pricing?.effectivePortionPrice ??
            result.scaledCostBreakdown.suggestedPortionPrice;

    return Container(
      key: const Key('card_scaling_summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.butterCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryCaramel, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'FACTOR DE ESCALADO GEOMÉTRICO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.primaryDarkCaramel,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryCaramel,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  key: const Key('text_exact_scale_factor'),
                  '${factorFormatted}x ($shortFactor×)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          _buildSummaryMetricRow(
            'Molde / Destino:',
            '${result.targetMoldType ?? ''} ${result.targetMoldDimension ?? ''} (${result.targetYieldPortions} porciones)',
          ),
          _buildSummaryMetricRow(
            'Costo Directo Insumos:',
            '${result.originalCostBreakdown.rawMaterialsCost.toCurrencyString(symbol: currency)} → ${result.scaledCostBreakdown.rawMaterialsCost.toCurrencyString(symbol: currency)}',
            highlightValue: true,
          ),
          if (result.scaledSubRecipes.isNotEmpty)
            _buildSummaryMetricRow(
              'Costo Sub-Recetas:',
              '${result.originalCostBreakdown.subRecipesCost.toCurrencyString(symbol: currency)} → ${result.scaledCostBreakdown.subRecipesCost.toCurrencyString(symbol: currency)}',
            ),
          _buildSummaryMetricRow(
            'Costo Total Lote (CTP):',
            '${result.originalCostBreakdown.totalProductionCost.toCurrencyString(symbol: currency)} → ${result.scaledCostBreakdown.totalProductionCost.toCurrencyString(symbol: currency)}',
            highlightValue: true,
          ),
          _buildSummaryMetricRow(
            'Precio Venta Lote Sugerido:',
            suggestedBatchPrice.toCurrencyString(symbol: currency),
            valueColor: AppColors.profitGreen,
          ),
          _buildSummaryMetricRow(
            'Precio Venta por Porción:',
            '${suggestedPortionPrice.toCurrencyString(symbol: currency)} / porción',
            valueColor: AppColors.profitGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetricRow(
    String label,
    String value, {
    bool highlightValue = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textEspresso,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: highlightValue ? 13 : 12,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.textEspresso,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaledIngredientsCard(
    ScaledRecipeResult result,
    String currency,
  ) {
    // Group ingredients by section
    final Map<String, List<ScaledIngredientItem>> bySection = {};
    for (final item in result.scaledIngredients) {
      bySection.putIfAbsent(item.originalItem.section, () => []).add(item);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.scale_outlined,
                  color: AppColors.primaryCaramel,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Fórmula Escalada para Producción',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                ),
                if (_checkedItemIds.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _checkedItemIds.clear()),
                    child: const Text(
                      'Limpiar marcas',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const Text(
              'Marca cada ingrediente a medida que lo pesas en cocina.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),

            ...bySection.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 8, top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: AppColors.primaryDarkCaramel,
                      ),
                    ),
                  ),
                  ...entry.value.map(
                    (scaledItem) =>
                        _buildScaledIngredientTile(scaledItem, currency),
                  ),
                ],
              );
            }),

            if (result.scaledSubRecipes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SUB-RECETAS / COMPONENTES MODULARES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: AppColors.primaryDarkCaramel,
                  ),
                ),
              ),
              ...result.scaledSubRecipes.map((sub) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    Icons.layers_outlined,
                    color: AppColors.primaryCaramel,
                  ),
                  title: Text(
                    sub.originalItem.childRecipeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Original: ${sub.originalItem.quantityFactor.toStringAsFixed(2)}x → Escalado: ${sub.scaledFactor.toStringAsFixed(2)}x lote',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    sub.scaledItemCost.toCurrencyString(symbol: currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScaledIngredientTile(
    ScaledIngredientItem item,
    String currency,
  ) {
    final orig = item.originalItem;
    final isChecked = _checkedItemIds.contains(orig.id);
    final suggestion = item.indivisibleSuggestionText;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isChecked ? AppColors.surfaceWarm : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.hasFractionalIndivisible
              ? AppColors.honeyAccent
              : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Checkbox(
                  value: isChecked,
                  activeColor: AppColors.profitGreen,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _checkedItemIds.add(orig.id);
                      } else {
                        _checkedItemIds.remove(orig.id);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orig.ingredientName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration:
                            isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked
                            ? AppColors.textMuted
                            : AppColors.textEspresso,
                      ),
                    ),
                    Text(
                      'Base: ${orig.quantity.toStringAsFixed(2)} ${orig.unit} → Escalado: ${item.scaledQuantity.toStringAsFixed(2)} ${orig.unit}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDarkCaramel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.scaledItemCost.toCurrencyString(symbol: currency),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textEspresso,
                ),
              ),
            ],
          ),

          // Indivisible ingredient helper banner (BR-ESC-03)
          if (suggestion != null) ...[
            const SizedBox(height: 6),
            Container(
              key: Key('indivisible_badge_${orig.id}'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.honeyAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.egg_outlined,
                    size: 16,
                    color: AppColors.primaryDarkCaramel,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDarkCaramel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
