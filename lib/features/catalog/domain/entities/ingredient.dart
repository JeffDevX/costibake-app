import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/utils/unit_converter.dart';

class Ingredient extends Equatable {
  final String id;
  final String name;
  final String category;
  final PreciseDecimal purchaseCost;
  final PreciseDecimal purchaseQuantity;
  final String purchaseUnit; // 'kg', 'lb', 'g', 'oz', 'l', 'gal', 'ml', 'docena', 'unidad'
  final PreciseDecimal wastePercentage; // e.g. 5.0%
  final PreciseDecimal minimumUnitCost; // Cost per minimum unit ($/g or $/ml or $/unidad)
  final String minimumUnit; // 'g', 'ml', 'unidad'
  final PreciseDecimal? densityGPerMl; // For volume-to-mass conversion
  final String? notes;
  final DateTime updatedAt;

  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.purchaseCost,
    required this.purchaseQuantity,
    required this.purchaseUnit,
    required this.wastePercentage,
    required this.minimumUnitCost,
    required this.minimumUnit,
    this.densityGPerMl,
    this.notes,
    required this.updatedAt,
  });

  /// Factory helper to calculate effective minimum unit cost accounting for waste (merma)
  /// Formula: Costo_Unitario = Costo_Total / (Cantidad_Base * (1 - Merma / 100))
  static PreciseDecimal calculateMinimumUnitCost({
    required PreciseDecimal purchaseCost,
    required PreciseDecimal purchaseQuantity,
    required String purchaseUnit,
    required PreciseDecimal wastePercentage,
  }) {
    final baseQuantity = UnitConverter.convertToBaseQuantity(
      purchaseQuantity,
      purchaseUnit,
    );

    // Effective usable quantity = baseQuantity * (1 - waste / 100)
    final usableMultiplier = PreciseDecimal.fromInt(1) -
        (wastePercentage / PreciseDecimal.fromInt(100));
    final effectiveQuantity = baseQuantity * usableMultiplier;

    if (effectiveQuantity.isZero) return PreciseDecimal.zero;

    return purchaseCost / effectiveQuantity;
  }

  /// Determines the normalized minimum base unit for a given commercial purchase unit
  static String determineMinimumUnit(String purchaseUnit) {
    return UnitConverter.determineBaseUnit(purchaseUnit);
  }

  Ingredient copyWith({
    String? id,
    String? name,
    String? category,
    PreciseDecimal? purchaseCost,
    PreciseDecimal? purchaseQuantity,
    String? purchaseUnit,
    PreciseDecimal? wastePercentage,
    PreciseDecimal? minimumUnitCost,
    String? minimumUnit,
    PreciseDecimal? densityGPerMl,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      purchaseCost: purchaseCost ?? this.purchaseCost,
      purchaseQuantity: purchaseQuantity ?? this.purchaseQuantity,
      purchaseUnit: purchaseUnit ?? this.purchaseUnit,
      wastePercentage: wastePercentage ?? this.wastePercentage,
      minimumUnitCost: minimumUnitCost ?? this.minimumUnitCost,
      minimumUnit: minimumUnit ?? this.minimumUnit,
      densityGPerMl: densityGPerMl ?? this.densityGPerMl,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        purchaseCost,
        purchaseQuantity,
        purchaseUnit,
        wastePercentage,
        minimumUnitCost,
        minimumUnit,
        densityGPerMl,
        notes,
        updatedAt,
      ];
}
