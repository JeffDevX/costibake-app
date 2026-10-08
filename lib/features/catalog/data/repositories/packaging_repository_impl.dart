import '../../domain/entities/packaging.dart';
import '../../domain/repositories/packaging_repository.dart';
import '../datasources/packaging_local_datasource.dart';
import '../models/packaging_model.dart';

class PackagingRepositoryImpl implements PackagingRepository {
  final PackagingLocalDataSource localDataSource;

  PackagingRepositoryImpl({PackagingLocalDataSource? localDataSource})
      : localDataSource = localDataSource ?? PackagingLocalDataSourceImpl();

  @override
  Future<List<Packaging>> getAllPackaging() async {
    return await localDataSource.getAll();
  }

  @override
  Future<Packaging?> getPackagingById(String id) async {
    return await localDataSource.getById(id);
  }

  @override
  Future<List<Packaging>> searchPackaging(String query,
      {String? category}) async {
    return await localDataSource.search(query, category: category);
  }

  @override
  Future<void> savePackaging(Packaging packaging) async {
    final model = packaging is PackagingModel
        ? packaging
        : PackagingModel.fromEntity(packaging);
    await localDataSource.save(model);
  }

  @override
  Future<void> deletePackaging(String id, {bool force = false}) async {
    await localDataSource.delete(id, force: force);
  }

  @override
  Future<List<String>> getRecipesUsingPackaging(String packagingId) async {
    return await localDataSource.getUsageInRecipes(packagingId);
  }
}
