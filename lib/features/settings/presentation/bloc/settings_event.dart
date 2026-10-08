import 'package:equatable/equatable.dart';
import '../../domain/entities/business_config.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched to load business configuration (currency, labor rate, overhead percentage)
class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

/// Dispatched to save / update business configuration
class UpdateSettings extends SettingsEvent {
  final BusinessConfig config;

  const UpdateSettings(this.config);

  @override
  List<Object?> get props => [config];
}
