import '../../domain/entities/culinary_density.dart';
import '../../domain/repositories/density_repository.dart';
import '../datasources/density_local_datasource.dart';
import '../models/culinary_density_model.dart';

class DensityRepositoryImpl implements DensityRepository {
  final DensityLocalDataSource localDataSource;

  DensityRepositoryImpl({DensityLocalDataSource? localDataSource})
      : localDataSource = localDataSource ?? DensityLocalDataSourceImpl();

  @override
  Future<List<CulinaryDensity>> getAllDensities() async {
    return await localDataSource.getAll();
  }

  @override
  Future<CulinaryDensity?> getDensityByKey(String key) async {
    return await localDataSource.getByKey(key);
  }

  @override
  Future<void> saveDensity(CulinaryDensity density) async {
    final model = density is CulinaryDensityModel
        ? density
        : CulinaryDensityModel.fromEntity(density);
    await localDataSource.save(model);
  }

  @override
  Future<void> seedDefaultDensities() async {
    await localDataSource.seedIfEmpty();
  }
}
