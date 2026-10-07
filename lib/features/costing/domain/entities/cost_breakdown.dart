import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';

class CostBreakdown extends Equatable {
  final PreciseDecimal rawMaterialsCost; // Insumos
  final PreciseDecimal packagingCost; // Empaques directos
  final PreciseDecimal overheadCost; // Alícuota de servicios / indirectos
  final PreciseDecimal laborCost; // Mano de obra por tiempo de trabajo
  final PreciseDecimal totalProductionCost; // Costo total del lote
  final PreciseDecimal costPerPortion; // Costo unitario por porción
  final PreciseDecimal suggestedBatchPrice; // Precio venta lote según markup
  final PreciseDecimal suggestedPortionPrice; // Precio venta por porción
  final PreciseDecimal netProfitBatch; // Ganancia neta lote
  final PreciseDecimal netProfitPortion; // Ganancia neta porción

  const CostBreakdown({
    required this.rawMaterialsCost,
    required this.packagingCost,
    required this.overheadCost,
    required this.laborCost,
    required this.totalProductionCost,
    required this.costPerPortion,
    required this.suggestedBatchPrice,
    required this.suggestedPortionPrice,
    required this.netProfitBatch,
    required this.netProfitPortion,
  });

  @override
  List<Object?> get props => [
        rawMaterialsCost,
        packagingCost,
        overheadCost,
        laborCost,
        totalProductionCost,
        costPerPortion,
        suggestedBatchPrice,
        suggestedPortionPrice,
        netProfitBatch,
        netProfitPortion,
      ];
}
