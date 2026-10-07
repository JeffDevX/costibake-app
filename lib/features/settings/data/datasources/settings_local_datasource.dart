import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_tables.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../models/business_config_model.dart';

abstract class SettingsLocalDataSource {
  Future<BusinessConfigModel> getBusinessConfig();
  Future<void> saveBusinessConfig(BusinessConfigModel config);
}

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  final AppDatabase appDatabase;

  SettingsLocalDataSourceImpl({AppDatabase? database})
      : appDatabase = database ?? AppDatabase.instance;

  @override
  Future<BusinessConfigModel> getBusinessConfig() async {
    final db = await appDatabase.database;
    final results = await db.query(
      DatabaseTables.tableConfiguracionNegocio,
      limit: 1,
    );

    if (results.isEmpty) {
      final defaultConfig = BusinessConfigModel(
        id: 'default_business_config',
        businessName: 'Mi Taller de Repostería',
        currencySymbol: AppConstants.defaultCurrencySymbol,
        laborHourlyRate:
            PreciseDecimal.fromDouble(AppConstants.defaultLaborRatePerHour),
        overheadPercentage:
            PreciseDecimal.fromDouble(AppConstants.defaultOverheadPercentage),
        updatedAt: DateTime.now(),
      );
      await saveBusinessConfig(defaultConfig);
      return defaultConfig;
    }

    return BusinessConfigModel.fromMap(results.first);
  }

  @override
  Future<void> saveBusinessConfig(BusinessConfigModel config) async {
    final db = await appDatabase.database;
    await db.insert(
      DatabaseTables.tableConfiguracionNegocio,
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
