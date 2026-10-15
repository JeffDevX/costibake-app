import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';

/// Commercial calculation model for suggested pricing (RF-SYS-18, BR-PRC-01).
enum PricingMode {
  markupOnCost,
  marginOnSales;

  String get displayName {
    switch (this) {
      case PricingMode.markupOnCost:
        return 'Markup sobre Costo';
      case PricingMode.marginOnSales:
        return 'Margen sobre Venta';
    }
  }

  String get formulaDescription {
    switch (this) {
      case PricingMode.markupOnCost:
        return 'Precio = Costo × (1 + Margen / 100)';
      case PricingMode.marginOnSales:
        return 'Precio = Costo / (1 - Margen / 100)';
    }
  }

  static PricingMode fromString(String? value) {
    if (value == null) return PricingMode.markupOnCost;
    switch (value.trim().toUpperCase()) {
      case 'MARGEN_SOBRE_VENTA':
      case 'MARGINONSALES':
      case 'MARGIN_ON_SALES':
        return PricingMode.marginOnSales;
      case 'MARKUP_SOBRE_COSTO':
      case 'MARKUPONCOST':
      case 'MARKUP_ON_COST':
      default:
        return PricingMode.markupOnCost;
    }
  }

  String toDbString() {
    switch (this) {
      case PricingMode.markupOnCost:
        return 'MARKUP_SOBRE_COSTO';
      case PricingMode.marginOnSales:
        return 'MARGEN_SOBRE_VENTA';
    }
  }
}

/// Commercial psychological rounding rules (RF-SYS-20).
enum RoundingRule {
  none,
  ceil0_10,
  ceil0_50,
  ceil1_00;

  String get displayName {
    switch (this) {
      case RoundingRule.none:
        return 'Exacto';
      case RoundingRule.ceil0_10:
        return r'+$0.10 superior';
      case RoundingRule.ceil0_50:
        return r'+$0.50 superior';
      case RoundingRule.ceil1_00:
        return r'+$1.00 superior';
    }
  }

  PreciseDecimal? get step {
    switch (this) {
      case RoundingRule.none:
        return null;
      case RoundingRule.ceil0_10:
        return PreciseDecimal.fromString('0.10');
      case RoundingRule.ceil0_50:
        return PreciseDecimal.fromString('0.50');
      case RoundingRule.ceil1_00:
        return PreciseDecimal.fromString('1.00');
    }
  }

  static RoundingRule fromString(String? value) {
    if (value == null) return RoundingRule.none;
    switch (value.trim().toUpperCase()) {
      case 'SUPERIOR_0_10':
      case 'CEIL0_10':
        return RoundingRule.ceil0_10;
      case 'SUPERIOR_0_50':
      case 'CEIL0_50':
        return RoundingRule.ceil0_50;
      case 'SUPERIOR_1_00':
      case 'CEIL1_00':
        return RoundingRule.ceil1_00;
      case 'NINGUNO':
      case 'NONE':
      default:
        return RoundingRule.none;
    }
  }

  String toDbString() {
    switch (this) {
      case RoundingRule.none:
        return 'NINGUNO';
      case RoundingRule.ceil0_10:
        return 'SUPERIOR_0_10';
      case RoundingRule.ceil0_50:
        return 'SUPERIOR_0_50';
      case RoundingRule.ceil1_00:
        return 'SUPERIOR_1_00';
    }
  }
}

/// Immutable pricing configuration and parameters for a recipe (JEF-16).
class PricingStrategy extends Equatable {
  final PricingMode mode;
  final PreciseDecimal targetProfitMargin;
  final RoundingRule roundingRule;
  final PreciseDecimal? customBatchPrice;
  final PreciseDecimal? customPortionPrice;

  const PricingStrategy({
    this.mode = PricingMode.markupOnCost,
    required this.targetProfitMargin,
    this.roundingRule = RoundingRule.none,
    this.customBatchPrice,
    this.customPortionPrice,
  });

  factory PricingStrategy.defaultStrategy({
    PreciseDecimal? targetProfitMargin,
  }) {
    return PricingStrategy(
      mode: PricingMode.markupOnCost,
      targetProfitMargin: targetProfitMargin ?? PreciseDecimal.fromInt(40),
      roundingRule: RoundingRule.none,
    );
  }

  PricingStrategy copyWith({
    PricingMode? mode,
    PreciseDecimal? targetProfitMargin,
    RoundingRule? roundingRule,
    PreciseDecimal? customBatchPrice,
    bool clearCustomBatchPrice = false,
    PreciseDecimal? customPortionPrice,
    bool clearCustomPortionPrice = false,
  }) {
    return PricingStrategy(
      mode: mode ?? this.mode,
      targetProfitMargin: targetProfitMargin ?? this.targetProfitMargin,
      roundingRule: roundingRule ?? this.roundingRule,
      customBatchPrice: clearCustomBatchPrice
          ? null
          : (customBatchPrice ?? this.customBatchPrice),
      customPortionPrice: clearCustomPortionPrice
          ? null
          : (customPortionPrice ?? this.customPortionPrice),
    );
  }

  @override
  List<Object?> get props => [
        mode,
        targetProfitMargin,
        roundingRule,
        customBatchPrice,
        customPortionPrice,
      ];
}
