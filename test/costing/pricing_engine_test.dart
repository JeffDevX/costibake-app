import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/costing/domain/entities/pricing_strategy.dart';
import 'package:costibake_app/features/costing/domain/services/pricing_engine.dart';

void main() {
  group('PricingEngine Unit Tests (JEF-16, BR-PRC-01..05, RF-SYS-18..20)', () {
    test('BR-PRC-01: Markup on Cost formula suggested price', () {
      // Cost: $20.00, Margin/Markup: 40% -> Price = 20 * (1 + 0.40) = $28.00
      final result = PricingEngine.calculate(
        totalProductionCost: PreciseDecimal.fromString('20.00'),
        yieldPortions: 10,
        strategy: PricingStrategy(
          mode: PricingMode.markupOnCost,
          targetProfitMargin: PreciseDecimal.fromString('40.00'),
          roundingRule: RoundingRule.none,
        ),
      );

      expect(result.rawSuggestedBatchPrice.toStringAsFixed(2), '28.00');
      expect(result.effectiveBatchPrice.toStringAsFixed(2), '28.00');
      expect(result.netProfitBatch.toStringAsFixed(2), '8.00');
      expect(result.realMarkupBatch.toStringAsFixed(1), '40.0');
      expect(result.isBatchAtLoss, isFalse);

      // Portions (BR-PRC-03)
      expect(result.portionCost.toStringAsFixed(2), '2.00');
      expect(result.rawSuggestedPortionPrice.toStringAsFixed(2), '2.80');
      expect(result.effectivePortionPrice.toStringAsFixed(2), '2.80');
      expect(result.netProfitPortion.toStringAsFixed(2), '0.80');
      expect(result.realMarkupPortion.toStringAsFixed(1), '40.0');
      expect(result.isPortionAtLoss, isFalse);
    });

    test('BR-PRC-01: Margin on Sales formula suggested price', () {
      // Cost: $30.00, Margin on sales: 40% -> Price = 30 / (1 - 0.40) = 30 / 0.60 = $50.00
      final result = PricingEngine.calculate(
        totalProductionCost: PreciseDecimal.fromString('30.00'),
        yieldPortions: 5,
        strategy: PricingStrategy(
          mode: PricingMode.marginOnSales,
          targetProfitMargin: PreciseDecimal.fromString('40.00'),
          roundingRule: RoundingRule.none,
        ),
      );

      expect(result.rawSuggestedBatchPrice.toStringAsFixed(2), '50.00');
      expect(result.effectiveBatchPrice.toStringAsFixed(2), '50.00');
      expect(result.netProfitBatch.toStringAsFixed(2), '20.00');
      // Margin on sales = (20 / 50) * 100 = 40.0%
      expect(result.realMarginOnSalesBatch.toStringAsFixed(1), '40.0');
      // Real markup over cost = (20 / 30) * 100 = 66.67%
      expect(result.realMarkupBatch.toStringAsFixed(2), '66.67');
      expect(result.isBatchAtLoss, isFalse);

      // Portions
      expect(result.portionCost.toStringAsFixed(2), '6.00');
      expect(result.rawSuggestedPortionPrice.toStringAsFixed(2), '10.00');
      expect(result.effectivePortionPrice.toStringAsFixed(2), '10.00');
      expect(result.netProfitPortion.toStringAsFixed(2), '4.00');
      expect(result.realMarginOnSalesPortion.toStringAsFixed(1), '40.0');
    });

    test(r'RF-SYS-20: Rounding rules (+$0.10, +$0.50, +$1.00 superior)', () {
      // Base suggested: $32.43
      final cost = PreciseDecimal.fromString('24.946154');
      // 32.43 with +$0.10 -> $32.50
      final r010 = PricingEngine.calculate(
        totalProductionCost: cost,
        yieldPortions: 8,
        strategy: PricingStrategy(
          mode: PricingMode.markupOnCost,
          targetProfitMargin: PreciseDecimal.fromString('30.00'),
          roundingRule: RoundingRule.ceil0_10,
        ),
      );
      expect(r010.roundedSuggestedBatchPrice.toStringAsFixed(2), '32.50');

      // 32.43 with +$0.50 -> $32.50
      final r050 = PricingEngine.calculate(
        totalProductionCost: cost,
        yieldPortions: 8,
        strategy: PricingStrategy(
          mode: PricingMode.markupOnCost,
          targetProfitMargin: PreciseDecimal.fromString('30.00'),
          roundingRule: RoundingRule.ceil0_50,
        ),
      );
      expect(r050.roundedSuggestedBatchPrice.toStringAsFixed(2), '32.50');

      // 32.43 with +$1.00 -> $33.00
      final r100 = PricingEngine.calculate(
        totalProductionCost: cost,
        yieldPortions: 8,
        strategy: PricingStrategy(
          mode: PricingMode.markupOnCost,
          targetProfitMargin: PreciseDecimal.fromString('30.00'),
          roundingRule: RoundingRule.ceil1_00,
        ),
      );
      expect(r100.roundedSuggestedBatchPrice.toStringAsFixed(2), '33.00');
    });

    test('BR-PRC-04: Custom manual price recalculates real achieved margin', () {
      // Cost: $20.00, Suggested @ 30%: $26.00
      // User sets custom price to $35.00
      final result = PricingEngine.calculate(
        totalProductionCost: PreciseDecimal.fromString('20.00'),
        yieldPortions: 1,
        strategy: PricingStrategy(
          mode: PricingMode.markupOnCost,
          targetProfitMargin: PreciseDecimal.fromString('30.00'),
          customBatchPrice: PreciseDecimal.fromString('35.00'),
        ),
      );

      expect(result.rawSuggestedBatchPrice.toStringAsFixed(2), '26.00');
      expect(result.effectiveBatchPrice.toStringAsFixed(2), '35.00');
      expect(result.netProfitBatch.toStringAsFixed(2), '15.00');
      // Real markup: (15 / 20) * 100 = 75.0%
      expect(result.realMarkupBatch.toStringAsFixed(1), '75.0');
      // Real margin on sales: (15 / 35) * 100 = 42.86%
      expect(result.realMarginOnSalesBatch.toStringAsFixed(2), '42.86');
      expect(result.isBatchAtLoss, isFalse);
    });

    test('BR-PRC-05: Selling price <= total cost triggers loss alert', () {
      // Cost: $25.00, Manual price: $20.00 (selling at loss)
      final result = PricingEngine.calculate(
        totalProductionCost: PreciseDecimal.fromString('25.00'),
        yieldPortions: 1,
        strategy: PricingStrategy(
          mode: PricingMode.markupOnCost,
          targetProfitMargin: PreciseDecimal.fromString('40.00'),
          customBatchPrice: PreciseDecimal.fromString('20.00'),
        ),
      );

      expect(result.effectiveBatchPrice.toStringAsFixed(2), '20.00');
      expect(result.netProfitBatch.toStringAsFixed(2), '-5.00');
      expect(result.isBatchAtLoss, isTrue);

      // Exact breakeven (price == cost) is also marked as loss / zero gain (BR-PRC-05)
      final breakeven = PricingEngine.calculate(
        totalProductionCost: PreciseDecimal.fromString('25.00'),
        yieldPortions: 1,
        strategy: PricingStrategy(
          mode: PricingMode.markupOnCost,
          targetProfitMargin: PreciseDecimal.fromString('40.00'),
          customBatchPrice: PreciseDecimal.fromString('25.00'),
        ),
      );
      expect(breakeven.isBatchAtLoss, isTrue);
    });

    test('Handles edge cases: 0 cost, 0 portions, 100% margin on sales guard', () {
      final zeroCost = PricingEngine.calculate(
        totalProductionCost: PreciseDecimal.zero,
        yieldPortions: 0, // Fallback to 1
        strategy: PricingStrategy(
          targetProfitMargin: PreciseDecimal.fromString('50.00'),
        ),
      );
      expect(zeroCost.effectiveBatchPrice, PreciseDecimal.zero);
      expect(zeroCost.yieldPortions, 1);

      expect(
        () => PricingEngine.calculate(
          totalProductionCost: PreciseDecimal.fromInt(10),
          yieldPortions: 1,
          strategy: PricingStrategy(
            mode: PricingMode.marginOnSales,
            targetProfitMargin: PreciseDecimal.fromString('100.00'),
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
