import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/ingredient_repository.dart';
import '../../domain/repositories/packaging_repository.dart';
import 'catalog_event.dart';
import 'catalog_state.dart';

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  final IngredientRepository ingredientRepository;
  final PackagingRepository packagingRepository;

  CatalogBloc({
    required this.ingredientRepository,
    required this.packagingRepository,
  }) : super(const CatalogInitial()) {
    on<LoadCatalog>(_onLoadCatalog);
    on<AddIngredient>(_onAddIngredient);
    on<UpdateIngredient>(_onUpdateIngredient);
    on<DeleteIngredient>(_onDeleteIngredient);
    on<AddPackaging>(_onAddPackaging);
    on<UpdatePackaging>(_onUpdatePackaging);
    on<DeletePackaging>(_onDeletePackaging);
  }

  Future<void> _onLoadCatalog(
    LoadCatalog event,
    Emitter<CatalogState> emit,
  ) async {
    emit(const CatalogLoading());
    try {
      final ingredients = await ingredientRepository.getAllIngredients();
      final packagings = await packagingRepository.getAllPackaging();
      emit(CatalogLoaded(ingredients: ingredients, packagings: packagings));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onAddIngredient(
    AddIngredient event,
    Emitter<CatalogState> emit,
  ) async {
    try {
      await ingredientRepository.saveIngredient(event.ingredient);
      add(const LoadCatalog());
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onUpdateIngredient(
    UpdateIngredient event,
    Emitter<CatalogState> emit,
  ) async {
    try {
      await ingredientRepository.saveIngredient(event.ingredient);
      add(const LoadCatalog());
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onDeleteIngredient(
    DeleteIngredient event,
    Emitter<CatalogState> emit,
  ) async {
    try {
      await ingredientRepository.deleteIngredient(event.id, force: event.force);
      add(const LoadCatalog());
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onAddPackaging(
    AddPackaging event,
    Emitter<CatalogState> emit,
  ) async {
    try {
      await packagingRepository.savePackaging(event.packaging);
      add(const LoadCatalog());
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onUpdatePackaging(
    UpdatePackaging event,
    Emitter<CatalogState> emit,
  ) async {
    try {
      await packagingRepository.savePackaging(event.packaging);
      add(const LoadCatalog());
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onDeletePackaging(
    DeletePackaging event,
    Emitter<CatalogState> emit,
  ) async {
    try {
      await packagingRepository.deletePackaging(event.id);
      add(const LoadCatalog());
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }
}
