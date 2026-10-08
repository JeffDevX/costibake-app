import 'precise_decimal.dart';

/// Predefined culinary densities (g/ml) for pastry ingredients to prevent "1 cup = 250g" errors.
class CulinaryDensityMatrix {
  static final Map<String, PreciseDecimal> standardDensities = {
    'harina': PreciseDecimal.fromString('0.5072'), // 1 cup ~ 120 g
    'harina_trigo': PreciseDecimal.fromString('0.5072'),
    'azucar_blanca': PreciseDecimal.fromString('0.8453'), // 1 cup ~ 200 g
    'azucar_morena': PreciseDecimal.fromString('0.9299'), // 1 cup ~ 220 g
    'azucar_glass': PreciseDecimal.fromString('0.5072'), // 1 cup ~ 120 g
    'mantequilla': PreciseDecimal.fromString('0.9595'), // 1 cup ~ 227 g
    'cacao_polvo': PreciseDecimal.fromString('0.4227'), // 1 cup ~ 100 g
    'aceite_vegetal': PreciseDecimal.fromString('0.9214'), // 1 cup ~ 218 g
    'leche_entera': PreciseDecimal.fromString('1.0300'), // 1 cup ~ 244 g
    'agua': PreciseDecimal.fromString('1.0000'), // 1 cup ~ 237 g
    'miel': PreciseDecimal.fromString('1.4371'), // 1 cup ~ 340 g
  };

  static PreciseDecimal getDensity(String key, [PreciseDecimal? fallback]) {
    final normalized = key.toLowerCase().trim().replaceAll(' ', '_');
    return standardDensities[normalized] ??
        fallback ??
        PreciseDecimal.fromString('1.0000');
  }
}

/// Culinary unit conversion service with exact decimal arithmetic.
class UnitConverter {
  // Volume to ml factors (US Culinary Standards)
  static final PreciseDecimal mlPerCup = PreciseDecimal.fromString('236.588');
  static final PreciseDecimal mlPerTablespoon = PreciseDecimal.fromString('14.787');
  static final PreciseDecimal mlPerTeaspoon = PreciseDecimal.fromString('4.929');
  static final PreciseDecimal mlPerFluidOunce = PreciseDecimal.fromString('29.5735');
  static final PreciseDecimal mlPerLiter = PreciseDecimal.fromInt(1000);
  static final PreciseDecimal mlPerGallon = PreciseDecimal.fromString('3785.41');

  // Mass to grams factors (International Standards)
  static final PreciseDecimal gramsPerKilogram = PreciseDecimal.fromInt(1000);
  static final PreciseDecimal gramsPerPound = PreciseDecimal.fromString('453.59237');
  static final PreciseDecimal gramsPerOunce = PreciseDecimal.fromString('28.3495');

  // Count factors
  static final PreciseDecimal unitsPerDozen = PreciseDecimal.fromInt(12);

  /// Converts culinary volume (cups, tbsp, tsp, ml, l, gal) to milliliters
  static PreciseDecimal toMilliliters(PreciseDecimal quantity, String unit) {
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

  /// Converts culinary mass (kg, g, lb, oz) to grams
  static PreciseDecimal toGrams(PreciseDecimal quantity, String unit) {
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

  /// Converts count items (docena, unidad) to single units
  static PreciseDecimal toUnits(PreciseDecimal quantity, String unit) {
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

  /// Returns standard base unit code: 'g' for mass, 'ml' for volume, 'unidad' for count
  static String determineBaseUnit(String unit) {
    final u = unit.toLowerCase().trim();
    if (['kg', 'kilo', 'kilogramo', 'kilogramos', 'g', 'gramo', 'gramos', 'lb', 'libra', 'libras', 'oz', 'onza', 'onzas'].contains(u)) {
      return 'g';
    }
    if (['l', 'litro', 'litros', 'ml', 'mililitro', 'mililitros', 'gal', 'galon', 'galón', 'galones', 'taza', 'cda', 'cdta', 'fl_oz'].contains(u)) {
      return 'ml';
    }
    return 'unidad';
  }

  /// Converts commercial quantity to base SI or count quantity (g, ml, or units)
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
