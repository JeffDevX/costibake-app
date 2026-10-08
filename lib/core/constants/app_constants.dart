class AppConstants {
  static const String appName = 'CostiBake';
  static const String appVersion = '0.1.0';
  static const String databaseName = 'costibake_local.db';
  static const int databaseVersion = 1;

  // Touch Target Guidelines for Kitchen/Obrador Environments
  static const double minTouchTargetSize = 48.0;

  // Financial and Quantity Constants
  static const int standardDecimalScale = 4;
  static const int currencyDecimalScale = 2;
  static const String defaultCurrencySymbol = r'$';
  static const double defaultLaborRatePerHour = 10.0;
  static const double defaultOverheadPercentage = 15.0;
  static const double defaultTargetProfitMargin = 40.0;

  // Recipe Statuses
  static const String recipeStatusActive = 'ACTIVA';
  static const String recipeStatusDraft = 'BORRADOR';
  static const String recipeStatusIncomplete = 'INCOMPLETA_REQUIERE_REVISION';
}
