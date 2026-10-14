import '../constants/culinary_units.dart';
import '../errors/exceptions.dart';
import 'precise_decimal.dart';

/// Predefined culinary densities (g/ml) for pastry ingredients to prevent "1 cup = 250g" errors.
class CulinaryDensityMatrix {
  static final Map<String, PreciseDecimal> standardDensities = {
    'harina': PreciseDecimal.fromString('0.5072'), // 1 cup ~ 121.7 g (0.5072 g/ml)
    'harina_trigo': PreciseDecimal.fromString('0.5072'),
    'azucar_blanca': PreciseDecimal.fromString('0.8453'), // 1 cup ~ 200 g (0.8453 g/ml)
    'azucar_morena': PreciseDecimal.fromString('0.9299'), // 1 cup ~ 220 g (0.9299 g/ml)
    'azucar_glass': PreciseDecimal.fromString('0.5072'), // 1 cup ~ 120 g (0.5072 g/ml)
    'mantequilla': PreciseDecimal.fromString('0.9595'), // 1 cup ~ 227 g (0.9595 g/ml)
    'cacao_polvo': PreciseDecimal.fromString('0.4227'), // 1 cup ~ 100 g (0.4227 g/ml)
    'aceite_vegetal': PreciseDecimal.fromString('0.9214'), // 1 cup ~ 218 g (0.9214 g/ml)
    'leche_entera': PreciseDecimal.fromString('1.0300'), // 1 cup ~ 244 g (1.0300 g/ml)
    'agua': PreciseDecimal.fromString('1.0000'), // 1 cup ~ 240 g (1.0000 g/ml)
    'miel': PreciseDecimal.fromString('1.4371'), // 1 cup ~ 345 g (1.4371 g/ml)
  };

  static PreciseDecimal getDensity(String key, [PreciseDecimal? fallback]) {
    final normalized = key.toLowerCase().trim().replaceAll(' ', '_');
    return standardDensities[normalized] ??
        fallback ??
        PreciseDecimal.fromString('1.0000');
  }
}

/// Bidirectional culinary unit conversion engine with exact decimal arithmetic.
/// Conforms to RF-SYS-06, RF-SYS-07, RNF-02, BR-CNV-01, BR-CNV-02, BR-CNV-03, BR-CNV-04.
class UnitConverter {
  // Volume to ml factors (BR-CNV-02: Standard culinary metric / US pastry)
  static final PreciseDecimal mlPerLiter = PreciseDecimal.fromInt(1000);
  static final PreciseDecimal mlPerCup = PreciseDecimal.fromString('240.0'); // 2.5 tazas = 600 ml
  static final PreciseDecimal mlPerCupUsCustomary = PreciseDecimal.fromString('236.588');
  static final PreciseDecimal mlPerTablespoon = PreciseDecimal.fromString('15.0'); // 3 tbsp = 45 ml
  static final PreciseDecimal mlPerTeaspoon = PreciseDecimal.fromString('5.0'); // 9 tsp = 45 ml
  static final PreciseDecimal mlPerFluidOunce = PreciseDecimal.fromString('29.5735');
  static final PreciseDecimal mlPerGallon = PreciseDecimal.fromString('3785.41');

  // Mass to grams factors (BR-CNV-01: International Standards)
  static final PreciseDecimal gramsPerKilogram = PreciseDecimal.fromInt(1000);
  static final PreciseDecimal gramsPerPound = PreciseDecimal.fromString('453.59237');
  static final PreciseDecimal gramsPerOunce = PreciseDecimal.fromString('28.349523125');

  // Count factors
  static final PreciseDecimal unitsPerDozen = PreciseDecimal.fromInt(12);

  /// Helper to convert dynamic numeric inputs into [PreciseDecimal].
  static PreciseDecimal _toPrecise(dynamic val) {
    if (val is PreciseDecimal) return val;
    if (val is int) return PreciseDecimal.fromInt(val);
    if (val is double) return PreciseDecimal.fromDouble(val);
    if (val is num) return PreciseDecimal.fromDouble(val.toDouble());
    if (val is String) return PreciseDecimal.fromString(val);
    throw ArgumentError('No se puede convertir el valor "$val" a PreciseDecimal.');
  }

  /// Helper to resolve [CulinaryUnit] from enum or string identifier.
  static CulinaryUnit _resolveUnit(dynamic unit) {
    if (unit is CulinaryUnit) return unit;
    if (unit is String) return CulinaryUnit.fromString(unit);
    throw ArgumentError('Unidad inválida: $unit');
  }

  /// General bidirectional culinary unit converter.
  ///
  /// Supports:
  /// - Intra-dimensional conversions: Mass <-> Mass, Volume <-> Volume, Count <-> Count.
  /// - Cross-dimensional Mass <-> Volume: requires [density] (in g/ml) per BR-CNV-03.
  /// - Cross-dimensional Count <-> Mass: requires [standardWeight] (in g/unit) per BR-CNV-04.
  /// - Cross-dimensional Count <-> Volume: requires both [standardWeight] and [density].
  static PreciseDecimal convertUnit(
    dynamic value,
    dynamic fromUnit,
    dynamic toUnit, {
    dynamic density,
    dynamic standardWeight,
  }) {
    final qty = _toPrecise(value);
    final from = _resolveUnit(fromUnit);
    final to = _resolveUnit(toUnit);

    if (qty.isZero) return PreciseDecimal.zero;
    if (from == to) return qty;

    final densityDecimal = density != null ? _toPrecise(density) : null;
    final weightDecimal = standardWeight != null ? _toPrecise(standardWeight) : null;

    // 1. Same dimension (Intra-dimensional conversion)
    if (from.isSameDimension(to)) {
      final baseQty = qty * from.baseFactor;
      return baseQty / to.baseFactor;
    }

    // 2. Cross-dimension: Mass <-> Volume (BR-CNV-03)
    if ((from.dimension == UnitDimension.mass && to.dimension == UnitDimension.volume) ||
        (from.dimension == UnitDimension.volume && to.dimension == UnitDimension.mass)) {
      if (densityDecimal == null || densityDecimal <= PreciseDecimal.zero) {
        throw CrossDimensionConversionException(
          fromUnit: from.symbol,
          toUnit: to.symbol,
          message:
              'No se puede convertir entre masa ("${from.displayName}") y volumen ("${to.displayName}") '
              'sin especificar la densidad del insumo (g/ml). Regla BR-CNV-03.',
        );
      }

      if (from.dimension == UnitDimension.volume) {
        // Volume to Mass: volume(ml) * density(g/ml) = mass(g)
        final volumeMl = qty * from.baseFactor;
        final massGrams = volumeMl * densityDecimal;
        return massGrams / to.baseFactor;
      } else {
        // Mass to Volume: mass(g) / density(g/ml) = volume(ml)
        final massGrams = qty * from.baseFactor;
        final volumeMl = massGrams / densityDecimal;
        return volumeMl / to.baseFactor;
      }
    }

    // 3. Cross-dimension: Count <-> Mass (BR-CNV-04)
    if ((from.dimension == UnitDimension.count && to.dimension == UnitDimension.mass) ||
        (from.dimension == UnitDimension.mass && to.dimension == UnitDimension.count)) {
      if (weightDecimal == null || weightDecimal <= PreciseDecimal.zero) {
        throw IncompatibleUnitDimensionException(
          fromUnit: from.symbol,
          toUnit: to.symbol,
          message:
              'No se puede convertir entre conteo ("${from.displayName}") y masa ("${to.displayName}") '
              'sin el peso unitario estándar de la pieza (g/unidad). Regla BR-CNV-04.',
        );
      }

      if (from.dimension == UnitDimension.count) {
        // Count to Mass: count(units) * weight(g/unit) = mass(g)
        final countUnits = qty * from.baseFactor;
        final massGrams = countUnits * weightDecimal;
        return massGrams / to.baseFactor;
      } else {
        // Mass to Count: mass(g) / weight(g/unit) = count(units)
        final massGrams = qty * from.baseFactor;
        final countUnits = massGrams / weightDecimal;
        return countUnits / to.baseFactor;
      }
    }

    // 4. Cross-dimension: Count <-> Volume (BR-CNV-03 & BR-CNV-04)
    if ((from.dimension == UnitDimension.count && to.dimension == UnitDimension.volume) ||
        (from.dimension == UnitDimension.volume && to.dimension == UnitDimension.count)) {
      if (weightDecimal == null || weightDecimal <= PreciseDecimal.zero) {
        throw IncompatibleUnitDimensionException(
          fromUnit: from.symbol,
          toUnit: to.symbol,
          message:
              'No se puede convertir entre conteo ("${from.displayName}") y volumen ("${to.displayName}") '
              'sin el peso unitario estándar de la pieza (g/unidad). Regla BR-CNV-04.',
        );
      }
      if (densityDecimal == null || densityDecimal <= PreciseDecimal.zero) {
        throw CrossDimensionConversionException(
          fromUnit: from.symbol,
          toUnit: to.symbol,
          message:
              'No se puede convertir entre conteo ("${from.displayName}") y volumen ("${to.displayName}") '
              'sin especificar la densidad del insumo (g/ml). Reglas BR-CNV-03 y BR-CNV-04.',
        );
      }

      if (from.dimension == UnitDimension.count) {
        // Count -> Mass -> Volume
        final countUnits = qty * from.baseFactor;
        final massGrams = countUnits * weightDecimal;
        final volumeMl = massGrams / densityDecimal;
        return volumeMl / to.baseFactor;
      } else {
        // Volume -> Mass -> Count
        final volumeMl = qty * from.baseFactor;
        final massGrams = volumeMl * densityDecimal;
        final countUnits = massGrams / weightDecimal;
        return countUnits / to.baseFactor;
      }
    }

    throw IncompatibleUnitDimensionException(
      fromUnit: from.symbol,
      toUnit: to.symbol,
      message: 'Conversión no soportada entre "${from.displayName}" y "${to.displayName}".',
    );
  }

  /// Converts culinary volume (cups, tbsp, tsp, ml, l, gal) to milliliters.
  static PreciseDecimal toMilliliters(PreciseDecimal quantity, String unit) {
    final parsed = CulinaryUnit.tryParse(unit);
    if (parsed != null && parsed.dimension == UnitDimension.volume) {
      return quantity * parsed.baseFactor;
    }

    // Fallback switch for extra resilience
    switch (unit.toLowerCase().trim()) {
      case 'ml':
      case 'mililitro':
      case 'mililitros':
        return quantity;
      case 'l':
      case 'litro':
      case 'litros':
        return quantity * mlPerLiter;
      case 'gal':
      case 'galon':
      case 'galón':
      case 'galones':
        return quantity * mlPerGallon;
      case 'taza':
      case 'tazas':
      case 'cup':
      case 'cups':
        return quantity * mlPerCup;
      case 'cda':
      case 'cucharada':
      case 'cucharadas':
      case 'tbsp':
        return quantity * mlPerTablespoon;
      case 'cdta':
      case 'cucharadita':
      case 'cucharaditas':
      case 'tsp':
        return quantity * mlPerTeaspoon;
      case 'fl_oz':
      case 'onza_liquida':
        return quantity * mlPerFluidOunce;
      default:
        return quantity;
    }
  }

  /// Converts culinary mass (kg, g, lb, oz) to grams.
  static PreciseDecimal toGrams(PreciseDecimal quantity, String unit) {
    final parsed = CulinaryUnit.tryParse(unit);
    if (parsed != null && parsed.dimension == UnitDimension.mass) {
      return quantity * parsed.baseFactor;
    }

    switch (unit.toLowerCase().trim()) {
      case 'g':
      case 'gramo':
      case 'gramos':
        return quantity;
      case 'kg':
      case 'kilo':
      case 'kilogramo':
      case 'kilogramos':
        return quantity * gramsPerKilogram;
      case 'lb':
      case 'libra':
      case 'libras':
        return quantity * gramsPerPound;
      case 'oz':
      case 'onza':
      case 'onzas':
        return quantity * gramsPerOunce;
      default:
        return quantity;
    }
  }

  /// Converts count items (docena, unidad) to single units.
  static PreciseDecimal toUnits(PreciseDecimal quantity, String unit) {
    final parsed = CulinaryUnit.tryParse(unit);
    if (parsed != null && parsed.dimension == UnitDimension.count) {
      return quantity * parsed.baseFactor;
    }

    switch (unit.toLowerCase().trim()) {
      case 'docena':
      case 'docenas':
      case 'dz':
        return quantity * unitsPerDozen;
      case 'unidad':
      case 'unidades':
      case 'u':
      case 'pza':
      case 'pzas':
      default:
        return quantity;
    }
  }

  /// Returns standard base unit code: 'g' for mass, 'ml' for volume, 'unidad' for count.
  static String determineBaseUnit(String unit) {
    final parsed = CulinaryUnit.tryParse(unit);
    if (parsed != null) {
      switch (parsed.dimension) {
        case UnitDimension.mass:
          return 'g';
        case UnitDimension.volume:
          return 'ml';
        case UnitDimension.count:
          return 'unidad';
      }
    }

    final u = unit.toLowerCase().trim();
    if (['kg', 'kilo', 'kilogramo', 'kilogramos', 'g', 'gramo', 'gramos', 'lb', 'libra', 'libras', 'oz', 'onza', 'onzas'].contains(u)) {
      return 'g';
    }
    if (['l', 'litro', 'litros', 'ml', 'mililitro', 'mililitros', 'gal', 'galon', 'galón', 'galones', 'taza', 'cda', 'cdta', 'fl_oz'].contains(u)) {
      return 'ml';
    }
    return 'unidad';
  }

  /// Converts commercial quantity to base SI or count quantity (g, ml, or units).
  static PreciseDecimal convertToBaseQuantity(PreciseDecimal quantity, String unit) {
    final base = determineBaseUnit(unit);
    if (base == 'g') {
      return toGrams(quantity, unit);
    } else if (base == 'ml') {
      return toMilliliters(quantity, unit);
    } else {
      return toUnits(quantity, unit);
    }
  }

  /// Converts volume (in ml) to mass (in g) using ingredient density (g/ml).
  static PreciseDecimal volumeToMass(
      PreciseDecimal volumeMl, PreciseDecimal densityGPerMl) {
    return volumeMl * densityGPerMl;
  }

  /// Converts mass (in g) to volume (in ml) using ingredient density (g/ml).
  static PreciseDecimal massToVolume(
      PreciseDecimal massG, PreciseDecimal densityGPerMl) {
    if (densityGPerMl.isZero) return PreciseDecimal.zero;
    return massG / densityGPerMl;
  }
}
