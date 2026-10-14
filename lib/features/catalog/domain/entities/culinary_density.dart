import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/utils/unit_converter.dart';

/// Represents a culinary density reference for an ingredient in pastry arts.
/// Conforms to RF-SYS-08, BR-DEN-01, BR-DEN-02, BR-DEN-04.
class CulinaryDensity extends Equatable {
  final String id;
  final String key; // Unique slug identifier e.g. 'harina_trigo'
  final String displayName; // User-facing name e.g. 'Harina de trigo todo uso'
  final String category; // Culinary category e.g. 'Harinas y Secos'
  final PreciseDecimal gramsPerCup; // Weight in grams of 1 standard culinary cup (240ml)
  final PreciseDecimal densityGPerMl; // Physical density in g/ml
  final bool isStandard; // True if pre-configured system seed, false if user custom
  final DateTime updatedAt;

  const CulinaryDensity({
    required this.id,
    required this.key,
    required this.displayName,
    required this.category,
    required this.gramsPerCup,
    required this.densityGPerMl,
    this.isStandard = true,
    required this.updatedAt,
  });

  /// Factory constructing from grams per cup (e.g. 125 g/taza).
  /// Automatically computes [densityGPerMl] = gramsPerCup / 240.0 ml.
  factory CulinaryDensity.fromGramsPerCup({
    required String id,
    required String key,
    required String displayName,
    required String category,
    required PreciseDecimal gramsPerCup,
    bool isStandard = true,
    DateTime? updatedAt,
  }) {
    final density = gramsPerCup / UnitConverter.mlPerCup;
    return CulinaryDensity(
      id: id,
      key: key,
      displayName: displayName,
      category: category,
      gramsPerCup: gramsPerCup,
      densityGPerMl: density,
      isStandard: isStandard,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Factory constructing from density in g/ml (e.g. 1.0300 g/ml).
  /// Automatically computes [gramsPerCup] = densityGPerMl * 240.0 ml.
  factory CulinaryDensity.fromDensityGPerMl({
    required String id,
    required String key,
    required String displayName,
    required String category,
    required PreciseDecimal densityGPerMl,
    bool isStandard = true,
    DateTime? updatedAt,
  }) {
    final gramsPerCup = densityGPerMl * UnitConverter.mlPerCup;
    return CulinaryDensity(
      id: id,
      key: key,
      displayName: displayName,
      category: category,
      gramsPerCup: gramsPerCup,
      densityGPerMl: densityGPerMl,
      isStandard: isStandard,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  CulinaryDensity copyWith({
    String? id,
    String? key,
    String? displayName,
    String? category,
    PreciseDecimal? gramsPerCup,
    PreciseDecimal? densityGPerMl,
    bool? isStandard,
    DateTime? updatedAt,
  }) {
    return CulinaryDensity(
      id: id ?? this.id,
      key: key ?? this.key,
      displayName: displayName ?? this.displayName,
      category: category ?? this.category,
      gramsPerCup: gramsPerCup ?? this.gramsPerCup,
      densityGPerMl: densityGPerMl ?? this.densityGPerMl,
      isStandard: isStandard ?? this.isStandard,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        key,
        displayName,
        category,
        gramsPerCup,
        densityGPerMl,
        isStandard,
        updatedAt,
      ];
}
