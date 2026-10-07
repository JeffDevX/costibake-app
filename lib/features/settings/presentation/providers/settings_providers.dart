import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/business_config.dart';
import '../../domain/repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl();
});

final businessConfigProvider =
    FutureProvider.autoDispose<BusinessConfig>((ref) async {
  final repository = ref.watch(settingsRepositoryProvider);
  return await repository.getBusinessConfig();
});
