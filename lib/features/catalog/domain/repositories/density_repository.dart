import '../entities/culinary_density.dart';

abstract class DensityRepository {
  /// Fetches all culinary densities in the matrix (standard + custom).
  Future<List<CulinaryDensity>> getAllDensities();

  /// Finds a culinary density by its unique slug/key or normalized name.
  Future<CulinaryDensity?> getDensityByKey(String key);

  /// Saves or updates a culinary density item.
  Future<void> saveDensity(CulinaryDensity density);

  /// Seeds default densities if table is empty.
  Future<void> seedDefaultDensities();
}
