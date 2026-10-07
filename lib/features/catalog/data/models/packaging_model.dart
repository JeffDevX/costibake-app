import '../../../../core/utils/precise_decimal.dart';
import '../../domain/entities/packaging.dart';

class PackagingModel extends Packaging {
  const PackagingModel({
    required super.id,
    required super.name,
    required super.category,
    required super.packageCost,
    required super.unitsPerPackage,
    required super.unitCost,
    super.notes,
    required super.updatedAt,
  });

  factory PackagingModel.fromEntity(Packaging entity) {
    return PackagingModel(
      id: entity.id,
      name: entity.name,
      category: entity.category,
      packageCost: entity.packageCost,
      unitsPerPackage: entity.unitsPerPackage,
      unitCost: entity.unitCost,
      notes: entity.notes,
      updatedAt: entity.updatedAt,
    );
  }

  factory PackagingModel.fromMap(Map<String, dynamic> map) {
    return PackagingModel(
      id: map['id'] as String,
      name: map['nombre'] as String,
      category: map['categoria'] as String,
      packageCost: PreciseDecimal.fromString(map['costo_paquete'] as String),
      unitsPerPackage: map['unidades_por_paquete'] as int,
      unitCost: PreciseDecimal.fromString(map['costo_unitario'] as String),
      notes: map['notas'] as String?,
      updatedAt: DateTime.parse(map['fecha_actualizacion'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': name,
      'categoria': category,
      'costo_paquete': packageCost.toStringAsFixed(4),
      'unidades_por_paquete': unitsPerPackage,
      'costo_unitario': unitCost.toStringAsFixed(6),
      'notas': notes,
      'fecha_actualizacion': updatedAt.toIso8601String(),
    };
  }
}
