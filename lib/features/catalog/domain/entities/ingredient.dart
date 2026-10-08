import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';

class Ingredient extends Equatable {
  final String id;
  final String name;
  final String category;
  final PreciseDecimal purchaseCost;
  final PreciseDecimal purchaseQuantity;
  final String purchaseUnit; // 'kg', 'g', 'l', 'ml', 'unidad'
  final PreciseDecimal wastePercentage; // e.g. 5.0%
  final PreciseDecimal minimumUnitCost; // Cost per minimum unit ($/g or $/ml or $/u)
  final String minimumUnit; // 'g', 'ml', 'u'
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
  static PreciseDecimal calculateMinimumUnitCost({
    required PreciseDecimal purchaseCost,
    required PreciseDecimal purchaseQuantity,
    required String purchaseUnit,
    required PreciseDecimal wastePercentage,
  }) {
    // Convert purchase quantity to base unit (kg -> 1000g, l -> 1000ml)
    PreciseDecimal baseQuantity = purchaseQuantity;
    if (purchaseUnit.toLowerCase() == 'kg' || purchaseUnit.toLowerCase() == 'l') {
      baseQuantity = purchaseQuantity * PreciseDecimal.fromInt(1000);
    } else if (purchaseUnit.toLowerCase() == 'lb') {
      // 1 lb = 453.592 g
      baseQuantity = purchaseQuantity * PreciseDecimal.fromString('453.592');
    }

    // Effective usable quantity = baseQuantity * (1 - waste / 100)
    final usableMultiplier = PreciseDecimal.fromInt(1) -
        (wastePercentage / PreciseDecimal.fromInt(100));
    final effectiveQuantity = baseQuantity * usableMultiplier;

    if (effectiveQuantity.isZero) return PreciseDecimal.zero;

    return purchaseCost / effectiveQuantity;
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
