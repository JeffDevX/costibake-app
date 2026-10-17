import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'package:costibake_app/core/widgets/responsive_center.dart';
import 'package:costibake_app/features/settings/domain/entities/business_config.dart';
import 'package:costibake_app/features/settings/domain/repositories/settings_repository.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_event.dart';
import 'package:costibake_app/features/settings/presentation/bloc/settings_state.dart';
import 'package:costibake_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockSettingsRepository implements SettingsRepository {
  BusinessConfig config = BusinessConfig(
    id: 'cfg-test',
    businessName: 'Taller de Dulces Pastelería',
    currencySymbol: '\$',
    laborHourlyRate: PreciseDecimal.fromString('15.00'),
    overheadPercentage: PreciseDecimal.fromString('18.0'),
    updatedAt: DateTime(2026, 1, 1),
  );

  @override
  Future<BusinessConfig> getBusinessConfig() async => config;

  @override
  Future<void> saveBusinessConfig(BusinessConfig newConfig) async {
    config = newConfig;
  }
}

void main() {
  group('SettingsBloc Logic (Pure BLoC Pattern)', () {
    late _MockSettingsRepository repo;
    late SettingsBloc bloc;

    setUp(() {
      repo = _MockSettingsRepository();
      bloc = SettingsBloc(settingsRepository: repo);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is SettingsInitial', () {
      expect(bloc.state, equals(const SettingsInitial()));
    });

    test('LoadSettings emits [SettingsLoading, SettingsLoaded] with repository config', () async {
      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          const SettingsLoading(),
          predicate<SettingsLoaded>((state) {
            return state.config.businessName == 'Taller de Dulces Pastelería' &&
                state.config.laborHourlyRate == PreciseDecimal.fromString('15.00') &&
                state.config.overheadPercentage == PreciseDecimal.fromString('18.0');
          }),
        ]),
      );

      bloc.add(const LoadSettings());
      await expectation;
    });

    test('UpdateSettings saves config and emits SettingsLoaded with new values', () async {
      final updated = repo.config.copyWith(
        businessName: 'Nueva Dulcería Central',
        laborHourlyRate: PreciseDecimal.fromString('22.50'),
        overheadPercentage: PreciseDecimal.fromString('20.0'),
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SettingsLoaded>((state) {
            return state.config.businessName == 'Nueva Dulcería Central' &&
                state.config.laborHourlyRate == PreciseDecimal.fromString('22.50') &&
                state.config.overheadPercentage == PreciseDecimal.fromString('20.0');
          }),
        ]),
      );

      bloc.add(UpdateSettings(updated));
      await expectation;
      expect(repo.config.businessName, equals('Nueva Dulcería Central'));
    });
  });

  group('SettingsScreen UI & Kitchen Ergonomics (JEF-6, BR-CFG-01..04)', () {
    late _MockSettingsRepository repo;
    late SettingsBloc bloc;

    setUp(() {
      repo = _MockSettingsRepository();
      bloc = SettingsBloc(settingsRepository: repo);
    });

    tearDown(() {
      bloc.close();
    });

    Widget buildTestable(Widget child) {
      return BlocProvider<SettingsBloc>.value(
        value: bloc,
        child: MaterialApp(home: child),
      );
    }

    Future<void> ensureLoaded(WidgetTester tester) async {
      await tester.runAsync(() async {
        if (bloc.state is! SettingsLoaded) {
          final future = bloc.stream.firstWhere((s) => s is SettingsLoaded);
          bloc.add(const LoadSettings());
          await future;
        }
      });
    }

    testWidgets('Renders all fields pre-populated with current settings', (tester) async {
      await ensureLoaded(tester);

      await tester.pumpWidget(buildTestable(const SettingsScreen()));
      await tester.pump();

      expect(find.byKey(const Key('business_name_field')), findsOneWidget);
      expect(find.byKey(const Key('currency_symbol_field')), findsOneWidget);
      expect(find.byKey(const Key('labor_rate_field')), findsOneWidget);
      expect(find.byKey(const Key('overhead_percentage_field')), findsOneWidget);
      expect(find.byKey(const Key('save_settings_button')), findsOneWidget);

      expect(find.text('Taller de Dulces Pastelería'), findsOneWidget);
      expect(find.text('\$'), findsOneWidget);
      expect(find.text('15.00'), findsOneWidget);
      expect(find.text('18.0'), findsOneWidget);
    });

    testWidgets('Validates required fields when emptied', (tester) async {
      await ensureLoaded(tester);

      await tester.pumpWidget(buildTestable(const SettingsScreen()));
      await tester.pump();

      // Empty the business name field
      await tester.enterText(find.byKey(const Key('business_name_field')), '');
      // Tap save
      final saveBtn = find.byKey(const Key('save_settings_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pump();

      expect(find.text('El nombre del negocio es obligatorio'), findsOneWidget);
    });

    testWidgets('Validates BR-CFG-02: overhead percentage cannot exceed 100%', (tester) async {
      await ensureLoaded(tester);

      await tester.pumpWidget(buildTestable(const SettingsScreen()));
      await tester.pump();

      // Enter 125% overhead (invalid)
      await tester.enterText(find.byKey(const Key('overhead_percentage_field')), '125');
      // Tap save
      final saveBtn = find.byKey(const Key('save_settings_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pump();

      expect(find.text('El porcentaje debe estar entre 0.00% y 100.00% (BR-CFG-02)'), findsOneWidget);
    });

    testWidgets('Updates settings and dispatches UpdateSettings event when form is valid',
        (tester) async {
      await ensureLoaded(tester);

      await tester.pumpWidget(buildTestable(const SettingsScreen()));
      await tester.pump();

      // Update labor rate to 20.00 and overhead to 15.0
      await tester.enterText(find.byKey(const Key('labor_rate_field')), '20.00');
      await tester.enterText(find.byKey(const Key('overhead_percentage_field')), '15.0');
      await tester.enterText(find.byKey(const Key('business_name_field')), 'Obrador Artesanal');

      // Tap save button
      final saveBtn = find.byKey(const Key('save_settings_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();

      // Verify SnackBar
      expect(find.text('Configuración guardada exitosamente'), findsOneWidget);

      // Verify bloc and repo state updated
      expect(bloc.state, isA<SettingsLoaded>());
      final loaded = bloc.state as SettingsLoaded;
      expect(loaded.config.businessName, equals('Obrador Artesanal'));
      expect(loaded.config.laborHourlyRate, equals(PreciseDecimal.fromString('20.00')));
      expect(loaded.config.overheadPercentage, equals(PreciseDecimal.fromString('15.0')));
    });

    testWidgets('Renders without overflow on compact 360x640 mobile screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await ensureLoaded(tester);
      await tester.pumpWidget(buildTestable(const SettingsScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('ResponsiveCenter clamps width on 1024x768 wide screen', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await ensureLoaded(tester);
      await tester.pumpWidget(buildTestable(const SettingsScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final centerFinder = find.byType(ResponsiveCenter);
      expect(centerFinder, findsOneWidget);
      final RenderBox renderBox = tester.renderObject(centerFinder);
      expect(renderBox.size.width, lessThanOrEqualTo(1024));
    });

    testWidgets('Renders back button when onBackToHome is provided and triggers callback', (tester) async {
      await ensureLoaded(tester);
      bool backCalled = false;
      await tester.pumpWidget(buildTestable(SettingsScreen(onBackToHome: () => backCalled = true)));
      await tester.pump();

      final backBtn = find.byKey(const Key('btn_settings_back'));
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pump();

      expect(backCalled, isTrue);
    });

    testWidgets('Renders hide keyboard button in AppBar and unfocuses active field', (tester) async {
      await ensureLoaded(tester);
      await tester.pumpWidget(buildTestable(const SettingsScreen()));
      await tester.pump();

      final nameField = find.byKey(const Key('business_name_field'));
      await tester.tap(nameField);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

      final hideBtn = find.byKey(const Key('btn_settings_hide_keyboard'));
      expect(hideBtn, findsOneWidget);
      await tester.tap(hideBtn);
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(of: nameField, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isFalse);
    });

    testWidgets('SingleChildScrollView has onDrag keyboardDismissBehavior', (tester) async {
      await ensureLoaded(tester);
      await tester.pumpWidget(buildTestable(const SettingsScreen()));
      await tester.pump();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);
      final scrollWidget = tester.widget<SingleChildScrollView>(scrollFinder);
      expect(scrollWidget.keyboardDismissBehavior, equals(ScrollViewKeyboardDismissBehavior.onDrag));
    });
  });
}
