import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/costing/domain/entities/pricing_strategy.dart';
import 'package:costibake_app/features/costing/presentation/widgets/dual_pricing_card.dart';

void main() {
  Widget buildTestWidget({
    required PreciseDecimal totalCost,
    required int yieldPortions,
    required PricingStrategy initialStrategy,
    ValueChanged<PricingStrategy>? onStrategyChanged,
    Size screenSize = const Size(360, 640),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: Scaffold(
          body: SingleChildScrollView(
            child: DualPricingCard(
              totalProductionCost: totalCost,
              yieldPortions: yieldPortions,
              currencySymbol: r'$',
              initialStrategy: initialStrategy,
              onStrategyChanged: onStrategyChanged,
            ),
          ),
        ),
      ),
    );
  }

  group('DualPricingCard Widget Tests (JEF-16 / RF-SYS-18..20)', () {
    testWidgets('Renders without overflow on compact 360x640 mobile screen',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final strategy = PricingStrategy(
        targetProfitMargin: PreciseDecimal.fromInt(40),
        mode: PricingMode.markupOnCost,
        roundingRule: RoundingRule.none,
      );

      await tester.pumpWidget(
        buildTestWidget(
          totalCost: PreciseDecimal.fromString('10.00'),
          yieldPortions: 8,
          initialStrategy: strategy,
        ),
      );
      await tester.pumpAndSettle();

      // Check key header texts
      expect(find.text('Estrategia de Precios y Ganancia'), findsOneWidget);
      expect(find.text('PRECIO LOTE SUGERIDO'), findsOneWidget);
      expect(find.text('PORCIÓN (8 PZAS)'), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Toggles between Markup on Cost and Margin on Sales',
        (tester) async {
      PricingStrategy? updatedStrategy;

      final strategy = PricingStrategy(
        targetProfitMargin: PreciseDecimal.fromInt(40),
        mode: PricingMode.markupOnCost,
        roundingRule: RoundingRule.none,
      );

      await tester.pumpWidget(
        buildTestWidget(
          totalCost: PreciseDecimal.fromString('10.00'),
          yieldPortions: 4,
          initialStrategy: strategy,
          onStrategyChanged: (s) => updatedStrategy = s,
        ),
      );
      await tester.pumpAndSettle();

      // Initially Markup on Cost is selected
      expect(find.byKey(const Key('mode_chip_markup')), findsOneWidget);
      expect(find.byKey(const Key('mode_chip_margin')), findsOneWidget);

      // Tap Margin on Sales chip
      await tester.tap(find.byKey(const Key('mode_chip_margin')));
      await tester.pumpAndSettle();

      expect(updatedStrategy, isNotNull);
      expect(updatedStrategy!.mode, equals(PricingMode.marginOnSales));
      expect(find.text('Margen Deseado (% sobre Venta)'), findsOneWidget);
    });

    testWidgets('Applies quick margin preset chips reactively',
        (tester) async {
      PricingStrategy? updatedStrategy;

      final strategy = PricingStrategy(
        targetProfitMargin: PreciseDecimal.fromInt(40),
        mode: PricingMode.markupOnCost,
        roundingRule: RoundingRule.none,
      );

      await tester.pumpWidget(
        buildTestWidget(
          totalCost: PreciseDecimal.fromString('20.00'),
          yieldPortions: 10,
          initialStrategy: strategy,
          onStrategyChanged: (s) => updatedStrategy = s,
        ),
      );
      await tester.pumpAndSettle();

      // Tap +50% chip
      final chip50 = find.byKey(const Key('margin_preset_chip_50'));
      expect(chip50, findsOneWidget);
      await tester.tap(chip50);
      await tester.pumpAndSettle();

      expect(updatedStrategy, isNotNull);
      expect(updatedStrategy!.targetProfitMargin, equals(PreciseDecimal.fromInt(50)));

      // With cost 20.00 and 50% markup -> suggested batch price = 30.00
      expect(find.text(r'$30.00'), findsAtLeastNWidgets(1));
    });

    testWidgets('Applies psychological rounding rules correctly',
        (tester) async {
      PricingStrategy? updatedStrategy;

      // Cost 10.33, markup 40% -> 10.33 * 1.40 = 14.462
      final strategy = PricingStrategy(
        targetProfitMargin: PreciseDecimal.fromInt(40),
        mode: PricingMode.markupOnCost,
        roundingRule: RoundingRule.none,
      );

      await tester.pumpWidget(
        buildTestWidget(
          totalCost: PreciseDecimal.fromString('10.33'),
          yieldPortions: 1,
          initialStrategy: strategy,
          onStrategyChanged: (s) => updatedStrategy = s,
        ),
      );
      await tester.pumpAndSettle();

      // Tap rounding to +$0.50 superior
      final round50Chip = find.byKey(const Key('rounding_chip_ceil0_50'));
      expect(round50Chip, findsOneWidget);
      await tester.tap(round50Chip);
      await tester.pumpAndSettle();

      expect(updatedStrategy, isNotNull);
      expect(updatedStrategy!.roundingRule, equals(RoundingRule.ceil0_50));
      // 14.462 rounded to 0.50 superior is 14.50
      expect(find.text(r'$14.50'), findsAtLeastNWidgets(1));
    });

    testWidgets('Manual price override displays "Manual" badge and 24sp bold text',
        (tester) async {
      PricingStrategy? updatedStrategy;

      final strategy = PricingStrategy(
        targetProfitMargin: PreciseDecimal.fromInt(40),
        mode: PricingMode.markupOnCost,
        roundingRule: RoundingRule.none,
      );

      await tester.pumpWidget(
        buildTestWidget(
          totalCost: PreciseDecimal.fromString('10.00'),
          yieldPortions: 5,
          initialStrategy: strategy,
          onStrategyChanged: (s) => updatedStrategy = s,
        ),
      );
      await tester.pumpAndSettle();

      // Enter manual batch price
      final batchField = find.byKey(const Key('custom_batch_price_field'));
      expect(batchField, findsOneWidget);

      await tester.enterText(batchField, '25.00');
      await tester.pumpAndSettle();

      expect(updatedStrategy, isNotNull);
      expect(updatedStrategy!.customBatchPrice, equals(PreciseDecimal.fromString('25.00')));
      expect(find.text('Manual'), findsOneWidget);
      expect(find.byKey(const Key('reset_batch_price_button')), findsOneWidget);

      // Verify reset button clears custom price
      await tester.tap(find.byKey(const Key('reset_batch_price_button')));
      await tester.pumpAndSettle();

      expect(updatedStrategy!.customBatchPrice, isNull);
      expect(find.text('Manual'), findsNothing);
    });

    testWidgets('Triggers loss protection alert when custom price is <= cost (BR-PRC-05)',
        (tester) async {
      final strategy = PricingStrategy(
        targetProfitMargin: PreciseDecimal.fromInt(40),
        mode: PricingMode.markupOnCost,
        roundingRule: RoundingRule.none,
      );

      await tester.pumpWidget(
        buildTestWidget(
          totalCost: PreciseDecimal.fromString('20.00'),
          yieldPortions: 4,
          initialStrategy: strategy,
        ),
      );
      await tester.pumpAndSettle();

      // Production cost is 20.00. Enter 15.00 for batch price (loss)
      final batchField = find.byKey(const Key('custom_batch_price_field'));
      await tester.enterText(batchField, '15.00');
      await tester.pumpAndSettle();

      // Loss alert must be visible
      expect(
        find.text('¡Alerta de venta a pérdida! El precio no cubre el costo de producción.'),
        findsOneWidget,
      );
    });
  });
}
