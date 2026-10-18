import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/features/quotes/domain/entities/quote.dart';
import 'package:costibake_app/features/quotes/domain/entities/quote_item.dart';
import 'package:costibake_app/features/quotes/domain/repositories/quote_repository.dart';
import 'package:costibake_app/features/quotes/presentation/bloc/quotes_bloc.dart';
import 'package:costibake_app/features/quotes/presentation/screens/quotes_screen.dart';
import 'package:costibake_app/features/quotes/presentation/screens/quote_form_screen.dart';
import 'package:costibake_app/features/recipes/domain/entities/recipe.dart';
import 'package:costibake_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:costibake_app/features/settings/domain/entities/business_config.dart';
import 'package:costibake_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_event.dart';

class _MockQuoteRepository implements QuoteRepository {
  final List<Quote> quotes = [];

  @override
  Future<List<Quote>> getAllQuotes() async => List.of(quotes);

  @override
  Future<Quote?> getQuoteById(String id) async =>
      quotes.where((q) => q.id == id).firstOrNull;

  @override
  Future<void> saveQuote(Quote quote) async {
    quotes.removeWhere((q) => q.id == quote.id);
    quotes.add(quote);
  }

  @override
  Future<void> deleteQuote(String id) async {
    quotes.removeWhere((q) => q.id == id);
  }

  @override
  Future<void> updateQuoteStatus(String id, QuoteStatus newStatus) async {
    final idx = quotes.indexWhere((q) => q.id == id);
    if (idx != -1) {
      quotes[idx] = quotes[idx].copyWith(status: newStatus);
    }
  }

  @override
  Future<List<Quote>> searchQuotes(String query, {QuoteStatus? status}) async {
    return quotes.where((q) {
      if (status != null && q.status != status) return false;
      if (query.isEmpty) return true;
      return q.clientName.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }
}

class _MockRecipeRepository implements RecipeRepository {
  final List<Recipe> recipes = [];

  @override
  Future<List<Recipe>> getAllRecipes() async => recipes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSettingsRepository implements SettingsRepository {
  @override
  Future<BusinessConfig> getBusinessConfig() async => BusinessConfig(
        id: 'cfg-test',
        businessName: 'Dulces Delicias',
        currencySymbol: '\$',
        laborHourlyRate: PreciseDecimal.fromString('15.00'),
        overheadPercentage: PreciseDecimal.fromString('12.00'),
        updatedAt: DateTime.now(),
      );

  @override
  Future<void> saveBusinessConfig(BusinessConfig config) async {}
}

void main() {
  group('QuotesScreen and QuoteFormScreen Widget Tests (JEF-31)', () {
    late _MockQuoteRepository mockQuoteRepo;
    late _MockRecipeRepository mockRecipeRepo;
    late _MockSettingsRepository mockSettingsRepo;

    setUp(() {
      mockQuoteRepo = _MockQuoteRepository();
      mockRecipeRepo = _MockRecipeRepository();
      mockSettingsRepo = _MockSettingsRepository();
    });

    Widget createTestWidget({Widget? child}) {
      return MultiRepositoryProvider(
        providers: [
          RepositoryProvider<QuoteRepository>.value(value: mockQuoteRepo),
          RepositoryProvider<RecipeRepository>.value(value: mockRecipeRepo),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>(
              create: (_) => SettingsBloc(settingsRepository: mockSettingsRepo)
                ..add(const LoadSettings()),
            ),
            BlocProvider<QuotesBloc>(
              create: (_) => QuotesBloc(quoteRepository: mockQuoteRepo),
            ),
          ],
          child: MaterialApp(
            home: child ?? const QuotesScreen(),
          ),
        ),
      );
    }

    testWidgets('Renders empty state properly on 360x640 mobile without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Cotizaciones y Pedidos'), findsOneWidget);
      expect(find.text('Aún no hay cotizaciones registradas'), findsOneWidget);
      expect(find.byKey(const Key('btn_add_quote')), findsOneWidget);
      expect(find.byKey(const Key('btn_empty_create_quote')), findsOneWidget);
    });

    testWidgets('Displays quote cards when quotes exist and allows status filter',
        (tester) async {
      final sampleQuote = Quote(
        id: 'quote-sample-1',
        clientName: 'Fernanda Ortiz',
        clientPhone: '5512349988',
        eventNotes: 'Pastel bautizo',
        deliveryDate: DateTime(2026, 12, 1, 14, 0),
        discount: PreciseDecimal.zero,
        depositAmount: PreciseDecimal.fromString('25.00'),
        status: QuoteStatus.pending,
        items: [
          QuoteItem(
            id: 'it-1',
            quoteId: 'quote-sample-1',
            concept: 'Pastel Zanahoria',
            quantity: PreciseDecimal.one,
            unitPrice: PreciseDecimal.fromString('50.00'),
          )
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      mockQuoteRepo.quotes.add(sampleQuote);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Fernanda Ortiz'), findsOneWidget);
      expect(find.text('5512349988'), findsOneWidget);
      expect(find.text('Total: \$50.00'), findsOneWidget);
      expect(find.text('Anticipo: \$25.00'), findsOneWidget);
      expect(find.text('Saldo: \$25.00'), findsOneWidget);

      // Tap Confirmadas chip -> should filter out
      await tester.tap(find.byKey(const Key('chip_filter_confirmed')));
      await tester.pumpAndSettle();
      expect(find.text('Fernanda Ortiz'), findsNothing);

      // Tap Pendientes chip -> should show again
      await tester.tap(find.byKey(const Key('chip_filter_pending')));
      await tester.pumpAndSettle();
      expect(find.text('Fernanda Ortiz'), findsOneWidget);
    });

    testWidgets('QuoteFormScreen allows creating a quote with custom item and saving',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(child: const QuoteFormScreen()));
      await tester.pumpAndSettle();

      // Enter client name
      await tester.enterText(
        find.byKey(const Key('txt_quote_client_name')),
        'Valeria Sanchez',
      );
      await tester.enterText(
        find.byKey(const Key('txt_quote_client_phone')),
        '5599001122',
      );

      // Add a custom item
      await tester.tap(find.byKey(const Key('btn_add_custom_item')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('txt_custom_item_concept')),
        'Pastel Redondo Red Velvet',
      );
      await tester.enterText(
        find.byKey(const Key('txt_custom_item_qty')),
        '1',
      );
      await tester.enterText(
        find.byKey(const Key('txt_custom_item_price')),
        '65.00',
      );
      await tester.tap(find.byKey(const Key('btn_confirm_add_custom_item')));
      await tester.pumpAndSettle();

      expect(find.text('Pastel Redondo Red Velvet'), findsOneWidget);
      expect(find.text('\$65.00'), findsWidgets);

      // Enter deposit
      await tester.enterText(
        find.byKey(const Key('txt_quote_deposit')),
        '30.00',
      );
      await tester.pumpAndSettle();

      // Remaining balance = 35.00
      expect(find.text('\$35.00'), findsOneWidget);

      // Save quote
      await tester.tap(find.byKey(const Key('btn_save_quote')));
      await tester.pumpAndSettle();

      expect(mockQuoteRepo.quotes.length, 1);
      expect(mockQuoteRepo.quotes.first.clientName, 'Valeria Sanchez');
      expect(mockQuoteRepo.quotes.first.totalAmount, PreciseDecimal.fromString('65.00'));
      expect(mockQuoteRepo.quotes.first.depositAmount, PreciseDecimal.fromString('30.00'));
      expect(mockQuoteRepo.quotes.first.remainingBalance, PreciseDecimal.fromString('35.00'));
    });
  });
}
