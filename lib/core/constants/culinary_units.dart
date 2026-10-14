import '../errors/exceptions.dart';
import '../utils/precise_decimal.dart';

/// Physical measurement dimensions in culinary context.
enum UnitDimension {
  mass,
  volume,
  count;

  String get displayName {
    switch (this) {
      case UnitDimension.mass:
        return 'Masa / Peso';
      case UnitDimension.volume:
        return 'Volumen';
      case UnitDimension.count:
        return 'Conteo';
    }
  }
}

/// Rich enumeration of culinary measurement units supporting exact conversions.
/// Conforms to RF-SYS-06, RF-SYS-07, BR-CNV-01, BR-CNV-02, BR-CNV-03, BR-CNV-04.
enum CulinaryUnit {
  // --- Mass / Peso (Base: Grams) ---
  gram(
    dimension: UnitDimension.mass,
    symbol: 'g',
    displayName: 'Gramo',
    displayNamePlural: 'Gramos',
    baseFactorString: '1',
    aliases: ['g', 'gramo', 'gramos', 'gr', 'grs', 'gram', 'grams'],
  ),
  kilogram(
    dimension: UnitDimension.mass,
    symbol: 'kg',
    displayName: 'Kilogramo',
    displayNamePlural: 'Kilogramos',
    baseFactorString: '1000', // BR-CNV-01: 1 kg = 1,000 g
    aliases: ['kg', 'kilo', 'kilos', 'kilogramo', 'kilogramos', 'kilogram', 'kilograms'],
  ),
  pound(
    dimension: UnitDimension.mass,
    symbol: 'lb',
    displayName: 'Libra',
    displayNamePlural: 'Libras',
    baseFactorString: '453.59237', // BR-CNV-01: 1 lb = 453.59237 g
    aliases: ['lb', 'lbs', 'libra', 'libras', 'pound', 'pounds'],
  ),
  ounce(
    dimension: UnitDimension.mass,
    symbol: 'oz',
    displayName: 'Onza',
    displayNamePlural: 'Onzas',
    baseFactorString: '28.349523125', // BR-CNV-01: 1 oz = 28.349523125 g
    aliases: ['oz', 'onza', 'onzas', 'ounce', 'ounces'],
  ),

  // --- Volume / Volumen (Base: Milliliters) ---
  milliliter(
    dimension: UnitDimension.volume,
    symbol: 'ml',
    displayName: 'Mililitro',
    displayNamePlural: 'Mililitros',
    baseFactorString: '1',
    aliases: ['ml', 'mililitro', 'mililitros', 'milliliter', 'milliliters'],
  ),
  liter(
    dimension: UnitDimension.volume,
    symbol: 'l',
    displayName: 'Litro',
    displayNamePlural: 'Litros',
    baseFactorString: '1000', // BR-CNV-02: 1 l = 1,000 ml
    aliases: ['l', 'lt', 'litro', 'litros', 'liter', 'liters'],
  ),
  cup(
    dimension: UnitDimension.volume,
    symbol: 'taza',
    displayName: 'Taza',
    displayNamePlural: 'Tazas',
    baseFactorString: '240.0', // BR-CNV-02: 1 cup estándar culinario = 240.0 ml (2.5 tazas = 600 ml)
    aliases: ['taza', 'tazas', 'cup', 'cups', 'tz'],
  ),
  tablespoon(
    dimension: UnitDimension.volume,
    symbol: 'cda',
    displayName: 'Cucharada',
    displayNamePlural: 'Cucharadas',
    baseFactorString: '15.0', // BR-CNV-02: 1 tbsp = 15.0 ml
    aliases: ['cda', 'cdas', 'cucharada', 'cucharadas', 'tbsp', 'tablespoon', 'tablespoons'],
  ),
  teaspoon(
    dimension: UnitDimension.volume,
    symbol: 'cdta',
    displayName: 'Cucharadita',
    displayNamePlural: 'Cucharaditas',
    baseFactorString: '5.0', // BR-CNV-02: 1 tsp = 5.0 ml (3 cda = 9 cdta = 45 ml)
    aliases: ['cdta', 'cdtas', 'cucharadita', 'cucharaditas', 'tsp', 'teaspoon', 'teaspoons'],
  ),
  fluidOunce(
    dimension: UnitDimension.volume,
    symbol: 'fl_oz',
    displayName: 'Onza líquida',
    displayNamePlural: 'Onzas líquidas',
    baseFactorString: '29.5735', // BR-CNV-02: 1 fl oz = 29.5735 ml
    aliases: ['fl_oz', 'fl oz', 'floz', 'onza_liquida', 'onza líquida', 'onzas liquidas', 'fluid ounce'],
  ),
  gallon(
    dimension: UnitDimension.volume,
    symbol: 'gal',
    displayName: 'Galón',
    displayNamePlural: 'Galones',
    baseFactorString: '3785.41', // BR-CNV-02: 1 gal = 3785.41 ml
    aliases: ['gal', 'galon', 'galón', 'galones', 'gallon', 'gallons'],
  ),

  // --- Count / Conteo (Base: Single item) ---
  unit(
    dimension: UnitDimension.count,
    symbol: 'u',
    displayName: 'Unidad',
    displayNamePlural: 'Unidades',
    baseFactorString: '1',
    aliases: [
      'u',
      'unidad',
      'unidades',
      'pza',
      'pzas',
      'pieza',
      'piezas',
      'unit',
      'units',
      'huevo',
      'huevos',
      'yema',
      'yemas',
      'clara',
      'claras',
    ],
  ),
  dozen(
    dimension: UnitDimension.count,
    symbol: 'dz',
    displayName: 'Docena',
    displayNamePlural: 'Docenas',
    baseFactorString: '12',
    aliases: ['dz', 'docena', 'docenas', 'dozen', 'dozens'],
  );

  const CulinaryUnit({
    required this.dimension,
    required this.symbol,
    required this.displayName,
    required this.displayNamePlural,
    required this.baseFactorString,
    required this.aliases,
  });

  final UnitDimension dimension;
  final String symbol;
  final String displayName;
  final String displayNamePlural;
  final String baseFactorString;
  final List<String> aliases;

  PreciseDecimal get baseFactor => PreciseDecimal.fromString(baseFactorString);

  /// Returns true if this unit and [other] share the same physical dimension.
  bool isSameDimension(CulinaryUnit other) => dimension == other.dimension;

  /// Returns standard base unit for this unit's dimension ('g' for mass, 'ml' for volume, 'u' for count).
  CulinaryUnit get baseUnit {
    switch (dimension) {
      case UnitDimension.mass:
        return CulinaryUnit.gram;
      case UnitDimension.volume:
        return CulinaryUnit.milliliter;
      case UnitDimension.count:
        return CulinaryUnit.unit;
    }
  }

  /// Parses a string into a [CulinaryUnit], matching symbol, name, or aliases (case-insensitive).
  static CulinaryUnit? tryParse(dynamic raw) {
    if (raw == null) return null;
    if (raw is CulinaryUnit) return raw;
    final normalized = raw.toString().trim().toLowerCase().replaceAll('-', '_');
    if (normalized.isEmpty) return null;

    for (final unit in CulinaryUnit.values) {
      if (unit.name.toLowerCase() == normalized ||
          unit.symbol.toLowerCase() == normalized ||
          unit.displayName.toLowerCase() == normalized ||
          unit.displayNamePlural.toLowerCase() == normalized ||
          unit.aliases.contains(normalized)) {
        return unit;
      }
    }
    return null;
  }

  /// Parses a string or throws [InvalidUnitException] if unrecognized.
  static CulinaryUnit fromString(dynamic raw) {
    if (raw is CulinaryUnit) return raw;
    final parsed = tryParse(raw);
    if (parsed != null) return parsed;
    throw InvalidUnitException(
      raw.toString(),
      'Unidad de medida culinaria desconocida o no soportada: "$raw"',
    );
  }
}
