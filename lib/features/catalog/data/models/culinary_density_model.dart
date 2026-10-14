import '../../../../core/utils/precise_decimal.dart';
import '../../domain/entities/culinary_density.dart';

class CulinaryDensityModel extends CulinaryDensity {
  const CulinaryDensityModel({
    required super.id,
    required super.key,
    required super.displayName,
    required super.category,
    required super.gramsPerCup,
    required super.densityGPerMl,
    super.isStandard = true,
    required super.updatedAt,
  });

  factory CulinaryDensityModel.fromEntity(CulinaryDensity entity) {
    return CulinaryDensityModel(
      id: entity.id,
      key: entity.key,
      displayName: entity.displayName,
      category: entity.category,
      gramsPerCup: entity.gramsPerCup,
      densityGPerMl: entity.densityGPerMl,
      isStandard: entity.isStandard,
      updatedAt: entity.updatedAt,
    );
  }

  factory CulinaryDensityModel.fromMap(Map<String, dynamic> map) {
    return CulinaryDensityModel(
      id: map['id'] as String,
      key: map['nombre_clave'] as String,
      displayName: map['nombre_mostrado'] as String,
      category: map['categoria'] as String,
      gramsPerCup: PreciseDecimal.fromString(map['gramos_por_taza'] as String),
      densityGPerMl: PreciseDecimal.fromString(map['densidad_g_ml'] as String),
      isStandard: (map['es_estandar'] as int? ?? 1) == 1,
      updatedAt: DateTime.parse(map['fecha_actualizacion'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre_clave': key,
      'nombre_mostrado': displayName,
      'categoria': category,
      'gramos_por_taza': gramsPerCup.toStringAsFixed(4),
      'densidad_g_ml': densityGPerMl.toStringAsFixed(6),
      'es_estandar': isStandard ? 1 : 0,
      'fecha_actualizacion': updatedAt.toIso8601String(),
    };
  }
}
