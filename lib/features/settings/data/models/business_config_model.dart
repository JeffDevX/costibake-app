import '../../../../core/utils/precise_decimal.dart';
import '../../domain/entities/business_config.dart';

class BusinessConfigModel extends BusinessConfig {
  const BusinessConfigModel({
    required super.id,
    required super.businessName,
    required super.currencySymbol,
    required super.laborHourlyRate,
    required super.overheadPercentage,
    required super.updatedAt,
  });

  factory BusinessConfigModel.fromEntity(BusinessConfig entity) {
    return BusinessConfigModel(
      id: entity.id,
      businessName: entity.businessName,
      currencySymbol: entity.currencySymbol,
      laborHourlyRate: entity.laborHourlyRate,
      overheadPercentage: entity.overheadPercentage,
      updatedAt: entity.updatedAt,
    );
  }

  factory BusinessConfigModel.fromMap(Map<String, dynamic> map) {
    return BusinessConfigModel(
      id: map['id'] as String,
      businessName: map['nombre_negocio'] as String,
      currencySymbol: map['moneda_simbolo'] as String,
      laborHourlyRate:
          PreciseDecimal.fromString(map['tarifa_hora_mano_obra'] as String),
      overheadPercentage: PreciseDecimal.fromString(
          map['porcentaje_overhead_indirectos'] as String),
      updatedAt: DateTime.parse(map['fecha_actualizacion'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre_negocio': businessName,
      'moneda_simbolo': currencySymbol,
      'tarifa_hora_mano_obra': laborHourlyRate.toStringAsFixed(4),
      'porcentaje_overhead_indirectos': overheadPercentage.toStringAsFixed(4),
      'fecha_actualizacion': updatedAt.toIso8601String(),
    };
  }
}
