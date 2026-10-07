import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';

class Packaging extends Equatable {
  final String id;
  final String name;
  final String category; // e.g. 'Cajas', 'Bases', 'Domo', 'Cintas', 'Capacillos'
  final PreciseDecimal packageCost;
  final int unitsPerPackage;
  final PreciseDecimal unitCost; // packageCost / unitsPerPackage
  final String? notes;
  final DateTime updatedAt;

  const Packaging({
    required this.id,
    required this.name,
    required this.category,
    required this.packageCost,
    required this.unitsPerPackage,
    required this.unitCost,
    this.notes,
    required this.updatedAt,
  });

  /// Factory helper to calculate exact unit cost per piece
  static PreciseDecimal calculateUnitCost({
    required PreciseDecimal packageCost,
    required int unitsPerPackage,
  }) {
    if (unitsPerPackage <= 0) return PreciseDecimal.zero;
    return packageCost / PreciseDecimal.fromInt(unitsPerPackage);
  }

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        packageCost,
        unitsPerPackage,
        unitCost,
        notes,
        updatedAt,
      ];
}
