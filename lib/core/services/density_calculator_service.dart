import '../constants/culinary_units.dart';
import '../errors/exceptions.dart';
import '../utils/precise_decimal.dart';
import '../utils/unit_converter.dart';
import '../../features/catalog/domain/entities/culinary_density.dart';
import '../../features/catalog/domain/repositories/density_repository.dart';

/// Domain service for inter-dimensional volume-to-mass conversions in pastry arts.
/// Conforms to RF-SYS-08, RNF-02, BR-DEN-01, BR-DEN-02, BR-DEN-03, BR-DEN-04.
class DensityCalculatorService {
  final DensityRepository? densityRepository;

  const DensityCalculatorService({this.densityRepository});

  /// Resolves the density in g/ml from density parameter, gramsPerCup, or standard matrix lookup.
  PreciseDecimal? resolveDensity({
    PreciseDecimal? densityGPerMl,
    PreciseDecimal? gramsPerCup,
    String? ingredientKey,
  }) {
    if (densityGPerMl != null && densityGPerMl > PreciseDecimal.zero) {
      return densityGPerMl;
    }
    if (gramsPerCup != null && gramsPerCup > PreciseDecimal.zero) {
      return gramsPerCup / UnitConverter.mlPerCup;
    }
    if (ingredientKey != null && ingredientKey.trim().isNotEmpty) {
      final normalized = ingredientKey.toLowerCase().trim().replaceAll(' ', '_');
      if (CulinaryDensityMatrix.standardDensities.containsKey(normalized)) {
        return CulinaryDensityMatrix.getDensity(normalized);
      }
    }
    return null;
  }

  /// Converts volume quantity to mass with high precision.
  /// Formula: Mass (g) = Volume (ml) * Density (g/ml) (BR-DEN-04).
  ///
  /// If [densityGPerMl], [gramsPerCup], and [ingredientKey] are all null,
  /// throws [CrossDimensionConversionException] per BR-DEN-03.
  PreciseDecimal volumeToMass({
    required dynamic volume,
    required dynamic volumeUnit,
    PreciseDecimal? densityGPerMl,
    PreciseDecimal? gramsPerCup,
    String? ingredientKey,
    CulinaryDensity? densityEntity,
    CulinaryUnit targetMassUnit = CulinaryUnit.gram,
  }) {
    final vUnit = volumeUnit is CulinaryUnit
        ? volumeUnit
        : CulinaryUnit.fromString(volumeUnit.toString());
    if (vUnit.dimension != UnitDimension.volume) {
      throw ArgumentError('La unidad origen "$volumeUnit" debe ser de volumen.');
    }

    final resolvedDensity = densityEntity?.densityGPerMl ??
        resolveDensity(
          densityGPerMl: densityGPerMl,
          gramsPerCup: gramsPerCup,
          ingredientKey: ingredientKey,
        );

    if (resolvedDensity == null || resolvedDensity <= PreciseDecimal.zero) {
      throw CrossDimensionConversionException(
        fromUnit: vUnit.symbol,
        toUnit: targetMassUnit.symbol,
        message:
            'El insumo "${ingredientKey ?? 'sin especificar'}" no posee densidad configurada. '
            'Se requiere especificar la densidad (g/ml) o gramos por taza. Regla BR-DEN-03.',
      );
    }

    // Special exact-shortcut for standard cups with known grams per cup
    // e.g. 1 taza de harina con 125 g/taza -> exact 125.00 g (no floating inaccuracy)
    final resolvedGramsPerCup = densityEntity?.gramsPerCup ??
        (gramsPerCup ??
            (ingredientKey != null
                ? CulinaryDensityMatrix.standardGramsPerCup[
                    ingredientKey.toLowerCase().trim().replaceAll(' ', '_')]
                : null));

    if (vUnit == CulinaryUnit.cup &&
        targetMassUnit == CulinaryUnit.gram &&
        resolvedGramsPerCup != null) {
      final volDecimal = volume is PreciseDecimal
          ? volume
          : (volume is num
              ? PreciseDecimal.fromDouble(volume.toDouble())
              : PreciseDecimal.fromString(volume.toString()));
      return volDecimal * resolvedGramsPerCup;
    }

    return UnitConverter.convertUnit(
      volume,
      vUnit,
      targetMassUnit,
      density: resolvedDensity,
    );
  }

  /// Converts mass quantity to volume with high precision.
  /// Formula: Volume (ml) = Mass (g) / Density (g/ml) (BR-DEN-04).
  PreciseDecimal massToVolume({
    required dynamic mass,
    required dynamic massUnit,
    PreciseDecimal? densityGPerMl,
    PreciseDecimal? gramsPerCup,
    String? ingredientKey,
    CulinaryDensity? densityEntity,
    CulinaryUnit targetVolumeUnit = CulinaryUnit.milliliter,
  }) {
    final mUnit = massUnit is CulinaryUnit
        ? massUnit
        : CulinaryUnit.fromString(massUnit.toString());
    if (mUnit.dimension != UnitDimension.mass) {
      throw ArgumentError('La unidad origen "$massUnit" debe ser de masa.');
    }

    final resolvedDensity = densityEntity?.densityGPerMl ??
        resolveDensity(
          densityGPerMl: densityGPerMl,
          gramsPerCup: gramsPerCup,
          ingredientKey: ingredientKey,
        );

    if (resolvedDensity == null || resolvedDensity <= PreciseDecimal.zero) {
      throw CrossDimensionConversionException(
        fromUnit: mUnit.symbol,
        toUnit: targetVolumeUnit.symbol,
        message:
            'El insumo "${ingredientKey ?? 'sin especificar'}" no posee densidad configurada. '
            'Se requiere especificar la densidad (g/ml) o gramos por taza. Regla BR-DEN-03.',
      );
    }

    return UnitConverter.convertUnit(
      mass,
      mUnit,
      targetVolumeUnit,
      density: resolvedDensity,
    );
  }

  /// Translates a recipe ingredient amount to grams exact.
  ///
  /// Examples:
  /// - "1 taza de harina" -> 125.00 g exactos.
  /// - "1 taza de azúcar común" -> 200.00 g exactos.
  /// - "1/2 taza de miel" -> 170.00 g exactos.
  PreciseDecimal translateRecipeIngredientToGrams({
    required dynamic quantity,
    required dynamic fromUnit,
    String? ingredientNameOrKey,
    PreciseDecimal? customDensityGPerMl,
    PreciseDecimal? customGramsPerCup,
  }) {
    final unit = fromUnit is CulinaryUnit
        ? fromUnit
        : CulinaryUnit.fromString(fromUnit.toString());

    if (unit.dimension == UnitDimension.mass) {
      return UnitConverter.convertUnit(quantity, unit, CulinaryUnit.gram);
    }

    if (unit.dimension == UnitDimension.volume) {
      return volumeToMass(
        volume: quantity,
        volumeUnit: unit,
        densityGPerMl: customDensityGPerMl,
        gramsPerCup: customGramsPerCup,
        ingredientKey: ingredientNameOrKey,
        targetMassUnit: CulinaryUnit.gram,
      );
    }

    throw IncompatibleUnitDimensionException(
      fromUnit: unit.symbol,
      toUnit: 'g',
      message:
          'No se puede convertir unidad de conteo "${unit.displayName}" a gramos '
          'sin peso estándar por pieza asignado. Regla BR-CNV-04.',
    );
  }

  /// Calculates prorated cost of volume ingredients against bulk weight purchase.
  ///
  /// Example: Recipe requires 1 cup of flour, purchased in 5 lb bag at $3.00.
  /// - 1 cup flour = 125 g
  /// - 5 lb bag = 2267.96185 g
  /// - Cost per gram = $3.00 / 2267.96185 g
  /// - Recipe cost = 125 g * cost per gram
  PreciseDecimal calculateRecipeVolumeCost({
    required dynamic recipeVolume,
    required dynamic recipeVolumeUnit,
    required String ingredientKey,
    required PreciseDecimal bulkPurchaseCost,
    required dynamic bulkPurchaseQuantity,
    required dynamic bulkPurchaseUnit,
    PreciseDecimal? wastePercentage,
  }) {
    // 1. Translate recipe volume to grams
    final requiredGrams = translateRecipeIngredientToGrams(
      quantity: recipeVolume,
      fromUnit: recipeVolumeUnit,
      ingredientNameOrKey: ingredientKey,
    );

    // 2. Normalize purchase quantity to grams
    final bulkGrams = UnitConverter.convertUnit(
      bulkPurchaseQuantity,
      bulkPurchaseUnit,
      CulinaryUnit.gram,
    );

    // 3. Apply waste if present
    final waste = wastePercentage ?? PreciseDecimal.zero;
    final usableMultiplier = PreciseDecimal.fromInt(1) -
        (waste / PreciseDecimal.fromInt(100));
    final effectiveGrams = bulkGrams * usableMultiplier;

    if (effectiveGrams.isZero) return PreciseDecimal.zero;

    final costPerGram = bulkPurchaseCost / effectiveGrams;
    return requiredGrams * costPerGram;
  }
}
