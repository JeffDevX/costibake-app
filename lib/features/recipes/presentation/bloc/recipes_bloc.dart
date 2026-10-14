import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/recipe_repository.dart';
import 'recipes_event.dart';
import 'recipes_state.dart';

class RecipesBloc extends Bloc<RecipesEvent, RecipesState> {
  final RecipeRepository recipeRepository;

  RecipesBloc({
    required this.recipeRepository,
  }) : super(const RecipesInitial()) {
    on<LoadRecipes>(_onLoadRecipes);
    on<FilterRecipes>(_onFilterRecipes);
    on<CreateRecipe>(_onCreateRecipe);
    on<UpdateRecipe>(_onUpdateRecipe);
    on<DeleteRecipe>(_onDeleteRecipe);
  }

  Future<void> _onLoadRecipes(
    LoadRecipes event,
    Emitter<RecipesState> emit,
  ) async {
    emit(const RecipesLoading());
    try {
      final recipes = await recipeRepository.getAllRecipes();
      emit(RecipesLoaded(recipes));
    } catch (e) {
      emit(RecipesError(e.toString()));
    }
  }

  void _onFilterRecipes(
    FilterRecipes event,
    Emitter<RecipesState> emit,
  ) {
    if (state is RecipesLoaded) {
      final current = state as RecipesLoaded;
      emit(RecipesLoaded(
        current.recipes,
        searchQuery: event.query,
        statusFilter: event.status,
      ));
    }
  }

  Future<void> _onCreateRecipe(
    CreateRecipe event,
    Emitter<RecipesState> emit,
  ) async {
    try {
      await recipeRepository.saveRecipe(event.recipe);
      final recipes = await recipeRepository.getAllRecipes();
      emit(RecipesLoaded(recipes));
    } catch (e) {
      emit(RecipesError(e.toString()));
    }
  }

  Future<void> _onUpdateRecipe(
    UpdateRecipe event,
    Emitter<RecipesState> emit,
  ) async {
    try {
      await recipeRepository.saveRecipe(event.recipe);
      final recipes = await recipeRepository.getAllRecipes();
      emit(RecipesLoaded(recipes));
    } catch (e) {
      emit(RecipesError(e.toString()));
    }
  }

  Future<void> _onDeleteRecipe(
    DeleteRecipe event,
    Emitter<RecipesState> emit,
  ) async {
    try {
      await recipeRepository.deleteRecipe(event.id);
      final recipes = await recipeRepository.getAllRecipes();
      emit(RecipesLoaded(recipes));
    } catch (e) {
      emit(RecipesError(e.toString()));
    }
  }
}
