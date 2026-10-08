import '../entities/packaging.dart';

abstract class PackagingRepository {
  Future<List<Packaging>> getAllPackaging();
  Future<Packaging?> getPackagingById(String id);
  Future<List<Packaging>> searchPackaging(String query, {String? category});
  Future<void> savePackaging(Packaging packaging);
  Future<void> deletePackaging(String id, {bool force = false});
  Future<List<String>> getRecipesUsingPackaging(String packagingId);
}
