import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../costing/data/services/cascade_recalculation_service.dart';
import '../../domain/entities/dependency_block_info.dart';
import '../../domain/repositories/ingredient_repository.dart';
import '../../domain/repositories/packaging_repository.dart';
import 'catalog_event.dart';
import 'catalog_state.dart';

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  final IngredientRepository ingredientRepository;
  final PackagingRepository packagingRepository;
  final CascadeRecalculationService cascadeRecalculationService;

  CatalogBloc({
    required this.ingredientRepository,
    required this.packagingRepository,
    CascadeRecalculationService? cascadeRecalculationService,
  })  : cascadeRecalculationService =
            cascadeRecalculationService ?? CascadeRecalculationService(),
        super(const CatalogInitial()) {
    on<LoadCatalog>(_onLoadCatalog);
    on<AddIngredient>(_onAddIngredient);
    on<UpdateIngredient>(_onUpdateIngredient);
    on<DeleteIngredient>(_onDeleteIngredient);
    on<AddPackaging>(_onAddPackaging);
    on<UpdatePackaging>(_onUpdatePackaging);
    on<DeletePackaging>(_onDeletePackaging);
    on<FilterCatalog>(_onFilterCatalog);
    on<ClearDependencyBlock>(_onClearDependencyBlock);
  }

  /// Queries recipes actively using the given ingredient (`RF-SYS-21`).
  Future<List<String>> checkIngredientDependencies(String ingredientId) {
    return ingredientRepository.getRecipesUsingIngredient(ingredientId);
  }

  /// Queries recipes actively using the given packaging item (`RF-SYS-21`).
  Future<List<String>> checkPackagingDependencies(String packagingId) {
    return packagingRepository.getRecipesUsingPackaging(packagingId);
  }

  void _onClearDependencyBlock(
    ClearDependencyBlock event,
    Emitter<CatalogState> emit,
  ) {
    if (state is CatalogLoaded) {
      final current = state as CatalogLoaded;
      emit(current.copyWith(clearDependencyBlock: true));
    }
  }

  Future<void> _onLoadCatalog(
    LoadCatalog event,
    Emitter<CatalogState> emit,
  ) async {
    String currentQuery = '';
    String? currentIngCat;
    String? currentPackCat;
    if (state is CatalogLoaded) {
      final current = state as CatalogLoaded;
      currentQuery = current.searchQuery;
      currentIngCat = current.ingredientCategory;
      currentPackCat = current.packagingCategory;
    }

    emit(const CatalogLoading());
    try {
      final ingredients = await ingredientRepository.getAllIngredients();
      final packagings = await packagingRepository.getAllPackaging();
      emit(CatalogLoaded(
        ingredients: ingredients,
        packagings: packagings,
        searchQuery: currentQuery,
        ingredientCategory: currentIngCat,
        packagingCategory: currentPackCat,
      ));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onFilterCatalog(
    FilterCatalog event,
    Emitter<CatalogState> emit,
  ) async {
    if (state is CatalogLoaded) {
      final current = state as CatalogLoaded;
      emit(current.copyWith(
        searchQuery: event.query,
        ingredientCategory: event.ingredientCategory,
        packagingCategory: event.packagingCategory,
        clearIngredientCategory: event.clearIngredientCategory,
        clearPackagingCategory: event.clearPackagingCategory,
      ));
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
      final cascadeResult = await cascadeRecalculationService
          .recalculateForIngredient(ingredient: event.ingredient);

      final ingredients = await ingredientRepository.getAllIngredients();
      final packagings = await packagingRepository.getAllPackaging();
      String currentQuery = '';
      String? currentIngCat;
      String? currentPackCat;
      if (state is CatalogLoaded) {
        final current = state as CatalogLoaded;
        currentQuery = current.searchQuery;
        currentIngCat = current.ingredientCategory;
        currentPackCat = current.packagingCategory;
      }
      emit(CatalogLoaded(
        ingredients: ingredients,
        packagings: packagings,
        searchQuery: currentQuery,
        ingredientCategory: currentIngCat,
        packagingCategory: currentPackCat,
        lastCascadeResult: cascadeResult,
      ));
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
    } on DependencyConstraintException catch (e) {
      await _emitDependencyBlock(
        emit: emit,
        itemId: event.id,
        isPackaging: false,
        affectedRecipeNames: e.affectedRecipeNames,
      );
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
      final cascadeResult = await cascadeRecalculationService
          .recalculateForPackaging(packaging: event.packaging);

      final ingredients = await ingredientRepository.getAllIngredients();
      final packagings = await packagingRepository.getAllPackaging();
      String currentQuery = '';
      String? currentIngCat;
      String? currentPackCat;
      if (state is CatalogLoaded) {
        final current = state as CatalogLoaded;
        currentQuery = current.searchQuery;
        currentIngCat = current.ingredientCategory;
        currentPackCat = current.packagingCategory;
      }
      emit(CatalogLoaded(
        ingredients: ingredients,
        packagings: packagings,
        searchQuery: currentQuery,
        ingredientCategory: currentIngCat,
        packagingCategory: currentPackCat,
        lastCascadeResult: cascadeResult,
      ));
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _onDeletePackaging(
    DeletePackaging event,
    Emitter<CatalogState> emit,
  ) async {
    try {
      await packagingRepository.deletePackaging(event.id, force: event.force);
      add(const LoadCatalog());
    } on DependencyConstraintException catch (e) {
      await _emitDependencyBlock(
        emit: emit,
        itemId: event.id,
        isPackaging: true,
        affectedRecipeNames: e.affectedRecipeNames,
      );
    } catch (e) {
      emit(CatalogError(e.toString()));
    }
  }

  Future<void> _emitDependencyBlock({
    required Emitter<CatalogState> emit,
    required String itemId,
    required bool isPackaging,
    required List<String> affectedRecipeNames,
  }) async {
    String itemName = itemId;
    if (state is CatalogLoaded) {
      final current = state as CatalogLoaded;
      if (isPackaging) {
        final match =
            current.allPackagings.where((p) => p.id == itemId).toList();
        if (match.isNotEmpty) itemName = match.first.name;
      } else {
        final match =
            current.allIngredients.where((i) => i.id == itemId).toList();
        if (match.isNotEmpty) itemName = match.first.name;
      }

      emit(current.copyWith(
        lastDependencyBlock: DependencyBlockInfo(
          itemId: itemId,
          itemName: itemName,
          isPackaging: isPackaging,
          affectedRecipeNames: affectedRecipeNames,
        ),
        clearCascadeResult: true,
      ));
      return;
    }

    // Fallback if state was not CatalogLoaded yet
    final ingredients = await ingredientRepository.getAllIngredients();
    final packagings = await packagingRepository.getAllPackaging();
    if (isPackaging) {
      final match = packagings.where((p) => p.id == itemId).toList();
      if (match.isNotEmpty) itemName = match.first.name;
    } else {
      final match = ingredients.where((i) => i.id == itemId).toList();
      if (match.isNotEmpty) itemName = match.first.name;
    }

    emit(CatalogLoaded(
      ingredients: ingredients,
      packagings: packagings,
      lastDependencyBlock: DependencyBlockInfo(
        itemId: itemId,
        itemName: itemName,
        isPackaging: isPackaging,
        affectedRecipeNames: affectedRecipeNames,
      ),
    ));
  }
}
