import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';

/// Geometric shape classification for baking pans/molds (RF-SYS-12).
enum MoldShape {
  circular,
  rectangular,
  individual,
}

/// Available recipe scaling modes (BR-ESC-02).
enum ScalingMode {
  /// 1. Por Molde Redondo (ej. 6" -> 10", 8" -> 12")
  circularMold,

  /// 2. Por Molde Rectangular (Largo x Ancho x Alto)
  rectangularMold,

  /// 3. Por Vasitos / Envases Individuales (oz / ml)
  individualContainers,

  /// 4. Por Factor Multiplicador Directo (ej. 0.5x, 1.5x, 2x)
  directMultiplier,

  /// 5. Por Número de Porciones Deseadas
  targetPortions;

  String get displayName {
    switch (this) {
      case ScalingMode.circularMold:
        return 'Molde Redondo';
      case ScalingMode.rectangularMold:
        return 'Molde Rectangular';
      case ScalingMode.individualContainers:
        return 'Vasitos / Envases (oz)';
      case ScalingMode.directMultiplier:
        return 'Multiplicador (x)';
      case ScalingMode.targetPortions:
        return 'Porciones';
    }
  }
}

/// Pre-configured standard pastry mold preset (JEF-14, RF-SYS-12).
class MoldPreset extends Equatable {
  final String id;
  final String name;
  final MoldShape shape;
  final String moldTypeLabel;
  final String dimensionLabel;
  final PreciseDecimal? diameterInches;
  final PreciseDecimal? diameterCm;
  final PreciseDecimal? lengthCm;
  final PreciseDecimal? widthCm;
  final PreciseDecimal? volumeOz;
  final PreciseDecimal? volumeMl;
  final PreciseDecimal defaultHeightCm;
  final int estimatedPortions;

  const MoldPreset({
    required this.id,
    required this.name,
    required this.shape,
    required this.moldTypeLabel,
    required this.dimensionLabel,
    this.diameterInches,
    this.diameterCm,
    this.lengthCm,
    this.widthCm,
    this.volumeOz,
    this.volumeMl,
    required this.defaultHeightCm,
    required this.estimatedPortions,
  });

  /// Standard circular baking pan presets (inches & centimeters).
  static final List<MoldPreset> circularPresets = [
    MoldPreset(
      id: 'round_4in',
      name: '4" (10 cm) • Mini',
      shape: MoldShape.circular,
      moldTypeLabel: 'Redondo',
      dimensionLabel: '4" (10 cm)',
      diameterInches: PreciseDecimal.fromInt(4),
      diameterCm: PreciseDecimal.fromInt(10),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 4,
    ),
    MoldPreset(
      id: 'round_6in',
      name: '6" (15 cm) • Pequeño',
      shape: MoldShape.circular,
      moldTypeLabel: 'Redondo',
      dimensionLabel: '6" (15 cm)',
      diameterInches: PreciseDecimal.fromInt(6),
      diameterCm: PreciseDecimal.fromInt(15),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 8,
    ),
    MoldPreset(
      id: 'round_8in',
      name: '8" (20 cm) • Estándar',
      shape: MoldShape.circular,
      moldTypeLabel: 'Redondo',
      dimensionLabel: '8" (20 cm)',
      diameterInches: PreciseDecimal.fromInt(8),
      diameterCm: PreciseDecimal.fromInt(20),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 14,
    ),
    MoldPreset(
      id: 'round_9in',
      name: '9" (23 cm) • Mediano',
      shape: MoldShape.circular,
      moldTypeLabel: 'Redondo',
      dimensionLabel: '9" (23 cm)',
      diameterInches: PreciseDecimal.fromInt(9),
      diameterCm: PreciseDecimal.fromInt(23),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 18,
    ),
    MoldPreset(
      id: 'round_10in',
      name: '10" (25 cm) • Grande',
      shape: MoldShape.circular,
      moldTypeLabel: 'Redondo',
      dimensionLabel: '10" (25 cm)',
      diameterInches: PreciseDecimal.fromInt(10),
      diameterCm: PreciseDecimal.fromInt(25),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 25,
    ),
    MoldPreset(
      id: 'round_12in',
      name: '12" (30 cm) • Evento',
      shape: MoldShape.circular,
      moldTypeLabel: 'Redondo',
      dimensionLabel: '12" (30 cm)',
      diameterInches: PreciseDecimal.fromInt(12),
      diameterCm: PreciseDecimal.fromInt(30),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 40,
    ),
    MoldPreset(
      id: 'round_14in',
      name: '14" (35 cm) • Banquete',
      shape: MoldShape.circular,
      moldTypeLabel: 'Redondo',
      dimensionLabel: '14" (35 cm)',
      diameterInches: PreciseDecimal.fromInt(14),
      diameterCm: PreciseDecimal.fromInt(35),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 60,
    ),
  ];

  /// Standard rectangular, square, and sheet pan presets.
  static final List<MoldPreset> rectangularPresets = [
    MoldPreset(
      id: 'sq_15x15',
      name: 'Cuadrado 15x15 cm (6"x6")',
      shape: MoldShape.rectangular,
      moldTypeLabel: 'Cuadrado',
      dimensionLabel: '15x15 cm',
      lengthCm: PreciseDecimal.fromInt(15),
      widthCm: PreciseDecimal.fromInt(15),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 9,
    ),
    MoldPreset(
      id: 'sq_20x20',
      name: 'Cuadrado 20x20 cm (8"x8")',
      shape: MoldShape.rectangular,
      moldTypeLabel: 'Cuadrado',
      dimensionLabel: '20x20 cm',
      lengthCm: PreciseDecimal.fromInt(20),
      widthCm: PreciseDecimal.fromInt(20),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 16,
    ),
    MoldPreset(
      id: 'rect_20x30',
      name: 'Rectangular 20x30 cm (1/4 Plancha)',
      shape: MoldShape.rectangular,
      moldTypeLabel: 'Rectangular',
      dimensionLabel: '20x30 cm',
      lengthCm: PreciseDecimal.fromInt(30),
      widthCm: PreciseDecimal.fromInt(20),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 24,
    ),
    MoldPreset(
      id: 'rect_25x35',
      name: 'Rectangular 25x35 cm',
      shape: MoldShape.rectangular,
      moldTypeLabel: 'Rectangular',
      dimensionLabel: '25x35 cm',
      lengthCm: PreciseDecimal.fromInt(35),
      widthCm: PreciseDecimal.fromInt(25),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 30,
    ),
    MoldPreset(
      id: 'rect_30x40',
      name: 'Media Plancha 30x40 cm',
      shape: MoldShape.rectangular,
      moldTypeLabel: 'Plancha',
      dimensionLabel: '30x40 cm',
      lengthCm: PreciseDecimal.fromInt(40),
      widthCm: PreciseDecimal.fromInt(30),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 48,
    ),
    MoldPreset(
      id: 'rect_40x60',
      name: 'Plancha Completa 40x60 cm',
      shape: MoldShape.rectangular,
      moldTypeLabel: 'Plancha',
      dimensionLabel: '40x60 cm',
      lengthCm: PreciseDecimal.fromInt(60),
      widthCm: PreciseDecimal.fromInt(40),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 96,
    ),
  ];

  /// Standard individual portion and container presets (vasitos de onzas, cupcakes, carlotas).
  static final List<MoldPreset> individualPresets = [
    MoldPreset(
      id: 'cup_2oz',
      name: 'Vasito 2 oz (60 ml) • Shot / Mini',
      shape: MoldShape.individual,
      moldTypeLabel: 'Individual',
      dimensionLabel: '2 oz (60 ml)',
      volumeOz: PreciseDecimal.fromInt(2),
      volumeMl: PreciseDecimal.fromInt(60),
      defaultHeightCm: PreciseDecimal.fromInt(4),
      estimatedPortions: 1,
    ),
    MoldPreset(
      id: 'cup_4oz',
      name: 'Vasito 4 oz (120 ml) • Carlota Pequeña',
      shape: MoldShape.individual,
      moldTypeLabel: 'Individual',
      dimensionLabel: '4 oz (120 ml)',
      volumeOz: PreciseDecimal.fromInt(4),
      volumeMl: PreciseDecimal.fromInt(120),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 1,
    ),
    MoldPreset(
      id: 'cup_5oz',
      name: 'Vasito 5 oz (150 ml) • Postre',
      shape: MoldShape.individual,
      moldTypeLabel: 'Individual',
      dimensionLabel: '5 oz (150 ml)',
      volumeOz: PreciseDecimal.fromInt(5),
      volumeMl: PreciseDecimal.fromInt(150),
      defaultHeightCm: PreciseDecimal.fromInt(5),
      estimatedPortions: 1,
    ),
    MoldPreset(
      id: 'cup_6oz',
      name: 'Vasito 6 oz (180 ml) • Carlota / Mousse Estándar',
      shape: MoldShape.individual,
      moldTypeLabel: 'Individual',
      dimensionLabel: '6 oz (180 ml)',
      volumeOz: PreciseDecimal.fromInt(6),
      volumeMl: PreciseDecimal.fromInt(180),
      defaultHeightCm: PreciseDecimal.fromInt(6),
      estimatedPortions: 1,
    ),
    MoldPreset(
      id: 'cup_7oz',
      name: 'Vasito 7 oz (210 ml) • Domo Mediano',
      shape: MoldShape.individual,
      moldTypeLabel: 'Individual',
      dimensionLabel: '7 oz (210 ml)',
      volumeOz: PreciseDecimal.fromInt(7),
      volumeMl: PreciseDecimal.fromInt(210),
      defaultHeightCm: PreciseDecimal.fromInt(6),
      estimatedPortions: 1,
    ),
    MoldPreset(
      id: 'cup_8oz',
      name: 'Vasito 8 oz (240 ml) • Domo Carlota Grande',
      shape: MoldShape.individual,
      moldTypeLabel: 'Individual',
      dimensionLabel: '8 oz (240 ml)',
      volumeOz: PreciseDecimal.fromInt(8),
      volumeMl: PreciseDecimal.fromInt(240),
      defaultHeightCm: PreciseDecimal.fromInt(7),
      estimatedPortions: 1,
    ),
    MoldPreset(
      id: 'cupcake_std',
      name: 'Cupcake / Muffin Estándar (~50 g)',
      shape: MoldShape.individual,
      moldTypeLabel: 'Cupcakes / Muffins',
      dimensionLabel: 'Estándar (~50 g)',
      volumeOz: PreciseDecimal.fromString('2.5'),
      volumeMl: PreciseDecimal.fromInt(75),
      defaultHeightCm: PreciseDecimal.fromInt(4),
      estimatedPortions: 1,
    ),
    MoldPreset(
      id: 'mini_cupcake',
      name: 'Mini Cupcake (~25 g)',
      shape: MoldShape.individual,
      moldTypeLabel: 'Cupcakes / Muffins',
      dimensionLabel: 'Mini (~25 g)',
      volumeOz: PreciseDecimal.fromString('1.2'),
      volumeMl: PreciseDecimal.fromInt(35),
      defaultHeightCm: PreciseDecimal.fromInt(3),
      estimatedPortions: 1,
    ),
  ];

  static List<MoldPreset> get allPresets => [
        ...circularPresets,
        ...rectangularPresets,
        ...individualPresets,
      ];

  /// Attempts to match a preset from a recipe's `moldType` and `moldDimension`.
  static MoldPreset? tryMatchFromRecipe(
    String? moldType,
    String? moldDimension,
  ) {
    if (moldDimension == null || moldDimension.trim().isEmpty) {
      return null;
    }
    final normDim = moldDimension.toLowerCase().trim();

    for (final preset in allPresets) {
      if (preset.dimensionLabel.toLowerCase() == normDim ||
          preset.name.toLowerCase() == normDim) {
        return preset;
      }
    }

    final normType = moldType?.toLowerCase().trim() ?? '';

    // Matching for individual presets (e.g. "4 oz", "4oz", "6 oz", "vasito", "cupcake")
    for (final preset in individualPresets) {
      final pName = preset.name.toLowerCase();
      final pDim = preset.dimensionLabel.toLowerCase();
      if (normDim == pDim ||
          normDim == pName ||
          normDim.contains(pDim) ||
          pDim.contains(normDim) ||
          normDim.contains(pName) ||
          pName.contains(normDim)) {
        return preset;
      }
      final oz = preset.volumeOz?.toStringAsFixed(0);
      if (oz != null &&
          (normDim.contains('${oz}oz') ||
              normDim.contains('$oz oz') ||
              normDim.contains('$oz onzas'))) {
        return preset;
      }
      if ((normDim.contains('cupcake') || normType.contains('cupcake')) &&
          preset.id == 'cupcake_std' &&
          !normDim.contains('mini')) {
        return preset;
      }
    }

    // Heuristic matching for circular presets (e.g. "20 cm", "8 in", "8\"")
    for (final preset in circularPresets) {
      final inStr = '${preset.diameterInches?.toStringAsFixed(0)}"';
      final inWord = '${preset.diameterInches?.toStringAsFixed(0)} in';
      final cmStr = '${preset.diameterCm?.toStringAsFixed(0)} cm';
      final cmTight = '${preset.diameterCm?.toStringAsFixed(0)}cm';
      if (normDim.contains(inStr) ||
          normDim.contains(inWord) ||
          normDim.contains(cmStr) ||
          normDim.contains(cmTight)) {
        return preset;
      }
    }

    // Heuristic matching for rectangular presets (e.g. "20x30")
    for (final preset in rectangularPresets) {
      final w = preset.widthCm?.toStringAsFixed(0);
      final l = preset.lengthCm?.toStringAsFixed(0);
      if (w != null &&
          l != null &&
          (normDim.contains('${w}x$l') || normDim.contains('${l}x$w'))) {
        return preset;
      }
    }

    return null;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        shape,
        moldTypeLabel,
        dimensionLabel,
        diameterInches,
        diameterCm,
        lengthCm,
        widthCm,
        volumeOz,
        volumeMl,
        defaultHeightCm,
        estimatedPortions,
      ];
}
