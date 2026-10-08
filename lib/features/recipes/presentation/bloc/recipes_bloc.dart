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

  Future<void> _onCreateRecipe(
    CreateRecipe event,
    Emitter<RecipesState> emit,
  ) async {
    try {
      await recipeRepository.saveRecipe(event.recipe);
      add(const LoadRecipes());
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
      add(const LoadRecipes());
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
      add(const LoadRecipes());
    } catch (e) {
      emit(RecipesError(e.toString()));
    }
  }
}
