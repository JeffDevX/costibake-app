import '../entities/business_config.dart';

abstract class SettingsRepository {
  Future<BusinessConfig> getBusinessConfig();
  Future<void> saveBusinessConfig(BusinessConfig config);
}
