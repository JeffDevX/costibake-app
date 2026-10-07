import '../../domain/entities/business_config.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';
import '../models/business_config_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource localDataSource;

  SettingsRepositoryImpl({SettingsLocalDataSource? localDataSource})
      : localDataSource = localDataSource ?? SettingsLocalDataSourceImpl();

  @override
  Future<BusinessConfig> getBusinessConfig() async {
    return await localDataSource.getBusinessConfig();
  }

  @override
  Future<void> saveBusinessConfig(BusinessConfig config) async {
    final model = config is BusinessConfigModel
        ? config
        : BusinessConfigModel.fromEntity(config);
    await localDataSource.saveBusinessConfig(model);
  }
}
