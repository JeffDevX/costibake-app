import '../../../../core/utils/precise_decimal.dart';
import '../../domain/entities/ingredient.dart';

class IngredientModel extends Ingredient {
  const IngredientModel({
    required super.id,
    required super.name,
    required super.category,
    required super.purchaseCost,
    required super.purchaseQuantity,
    required super.purchaseUnit,
    required super.wastePercentage,
    required super.minimumUnitCost,
    required super.minimumUnit,
    super.densityGPerMl,
    super.notes,
    required super.updatedAt,
  });

  factory IngredientModel.fromEntity(Ingredient entity) {
    return IngredientModel(
      id: entity.id,
      name: entity.name,
      category: entity.category,
      purchaseCost: entity.purchaseCost,
      purchaseQuantity: entity.purchaseQuantity,
      purchaseUnit: entity.purchaseUnit,
      wastePercentage: entity.wastePercentage,
      minimumUnitCost: entity.minimumUnitCost,
      minimumUnit: entity.minimumUnit,
      densityGPerMl: entity.densityGPerMl,
      notes: entity.notes,
      updatedAt: entity.updatedAt,
    );
  }

  factory IngredientModel.fromMap(Map<String, dynamic> map) {
    return IngredientModel(
      id: map['id'] as String,
      name: map['nombre'] as String,
      category: map['categoria'] as String,
      purchaseCost: PreciseDecimal.fromString(map['costo_compra'] as String),
      purchaseQuantity:
          PreciseDecimal.fromString(map['cantidad_compra'] as String),
      purchaseUnit: map['unidad_compra'] as String,
      wastePercentage:
          PreciseDecimal.fromString(map['merma_porcentaje'] as String),
      minimumUnitCost:
          PreciseDecimal.fromString(map['costo_unitario_minimo'] as String),
      minimumUnit: map['unidad_minima'] as String,
      densityGPerMl: map['densidad_g_ml'] != null
          ? PreciseDecimal.fromString(map['densidad_g_ml'] as String)
          : null,
      notes: map['notas'] as String?,
      updatedAt: DateTime.parse(map['fecha_actualizacion'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': name,
      'categoria': category,
      'costo_compra': purchaseCost.toStringAsFixed(4),
      'cantidad_compra': purchaseQuantity.toStringAsFixed(4),
      'unidad_compra': purchaseUnit,
      'merma_porcentaje': wastePercentage.toStringAsFixed(4),
      'costo_unitario_minimo': minimumUnitCost.toStringAsFixed(6),
      'unidad_minima': minimumUnit,
      'densidad_g_ml': densityGPerMl?.toStringAsFixed(4),
      'notas': notes,
      'fecha_actualizacion': updatedAt.toIso8601String(),
    };
  }
}
