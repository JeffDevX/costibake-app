import 'package:costibake_app/core/constants/app_breakpoints.dart';
import 'package:costibake_app/core/widgets/responsive_center.dart';
import 'package:costibake_app/features/catalog/domain/entities/ingredient.dart';
import 'package:costibake_app/features/catalog/domain/entities/packaging.dart';
import 'package:costibake_app/features/catalog/domain/repositories/ingredient_repository.dart';
import 'package:costibake_app/features/catalog/domain/repositories/packaging_repository.dart';
import 'package:costibake_app/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:costibake_app/features/catalog/presentation/screens/ingredient_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIngredientRepo implements IngredientRepository {
  @override
  Future<List<Ingredient>> getAllIngredients() async => [];
  @override
  Future<Ingredient?> getIngredientById(String id) async => null;
  @override
  Future<List<Ingredient>> searchIngredients(String query, {String? category}) async => [];
  @override
  Future<void> saveIngredient(Ingredient ingredient) async {}
  @override
  Future<void> deleteIngredient(String id, {bool force = false}) async {}
  @override
  Future<List<String>> getRecipesUsingIngredient(String ingredientId) async => [];
}

class _FakePackagingRepo implements PackagingRepository {
  @override
  Future<List<Packaging>> getAllPackaging() async => [];
  @override
  Future<Packaging?> getPackagingById(String id) async => null;
  @override
  Future<List<Packaging>> searchPackaging(String query, {String? category}) async => [];
  @override
  Future<void> savePackaging(Packaging packaging) async {}
  @override
  Future<void> deletePackaging(String id, {bool force = false}) async {}
  @override
  Future<List<String>> getRecipesUsingPackaging(String packagingId) async => [];
}

void main() {
  late CatalogBloc catalogBloc;

  setUp(() {
    catalogBloc = CatalogBloc(
      ingredientRepository: _FakeIngredientRepo(),
      packagingRepository: _FakePackagingRepo(),
    );
  });

  tearDown(() {
    catalogBloc.close();
  });

  Widget buildTestableWidget(Widget child) {
    return BlocProvider<CatalogBloc>.value(
      value: catalogBloc,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Responsive Layout Tests', () {
    testWidgets('IngredientFormScreen renders without overflow on compact 360x640 screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const IngredientFormScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(IngredientFormScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Registrar Insumo a Granel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('IngredientFormScreen renders without overflow on wide 1024x768 screen',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const IngredientFormScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(IngredientFormScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Registrar Insumo a Granel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ResponsiveCenter clamps child width to maxWidth on large display',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const targetKey = Key('centered_content');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveCenter(
              maxWidth: AppBreakpoints.maxFormWidth,
              child: SizedBox(
                key: targetKey,
                width: double.infinity,
                height: 100,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final renderBox = tester.renderObject(find.byKey(targetKey)) as RenderBox;
      expect(renderBox.size.width, lessThanOrEqualTo(AppBreakpoints.maxFormWidth));
    });
  });
}
