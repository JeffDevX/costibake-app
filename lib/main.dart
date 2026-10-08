import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/catalog/data/repositories/ingredient_repository_impl.dart';
import 'features/catalog/data/repositories/packaging_repository_impl.dart';
import 'features/catalog/domain/repositories/ingredient_repository.dart';
import 'features/catalog/domain/repositories/packaging_repository.dart';
import 'features/catalog/presentation/bloc/catalog_bloc.dart';
import 'features/catalog/presentation/bloc/catalog_event.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/recipes/data/repositories/recipe_repository_impl.dart';
import 'features/recipes/domain/repositories/recipe_repository.dart';
import 'features/recipes/presentation/bloc/recipes_bloc.dart';
import 'features/recipes/presentation/bloc/recipes_event.dart';
import 'features/settings/data/repositories/settings_repository_impl.dart';
import 'features/settings/domain/repositories/settings_repository.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/settings/presentation/bloc/settings_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CostiBakeApp());
}

class CostiBakeApp extends StatelessWidget {
  const CostiBakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IngredientRepository>(
          create: (_) => IngredientRepositoryImpl(),
        ),
        RepositoryProvider<PackagingRepository>(
          create: (_) => PackagingRepositoryImpl(),
        ),
        RepositoryProvider<RecipeRepository>(
          create: (_) => RecipeRepositoryImpl(),
        ),
        RepositoryProvider<SettingsRepository>(
          create: (_) => SettingsRepositoryImpl(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<CatalogBloc>(
            create: (ctx) => CatalogBloc(
              ingredientRepository: ctx.read<IngredientRepository>(),
              packagingRepository: ctx.read<PackagingRepository>(),
            )..add(const LoadCatalog()),
          ),
          BlocProvider<RecipesBloc>(
            create: (ctx) => RecipesBloc(
              recipeRepository: ctx.read<RecipeRepository>(),
            )..add(const LoadRecipes()),
          ),
          BlocProvider<SettingsBloc>(
            create: (ctx) => SettingsBloc(
              settingsRepository: ctx.read<SettingsRepository>(),
            )..add(const LoadSettings()),
          ),
        ],
        child: MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
