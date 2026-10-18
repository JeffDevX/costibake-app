import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'backup_manifest.dart';

/// Result of exporting a CostiBake `.cbake` archive.
class BackupExportResult extends Equatable {
  final String fileName;
  final String filePath;
  final Uint8List bytes;
  final BackupManifest manifest;

  const BackupExportResult({
    required this.fileName,
    required this.filePath,
    required this.bytes,
    required this.manifest,
  });

  @override
  List<Object?> get props => [fileName, filePath, manifest];
}

/// Result of inspecting and validating a `.cbake` backup archive before restoration.
class BackupValidationResult extends Equatable {
  final bool isValid;
  final BackupManifest? manifest;
  final String? errorMessage;

  const BackupValidationResult({
    required this.isValid,
    this.manifest,
    this.errorMessage,
  });

  factory BackupValidationResult.success(BackupManifest manifest) =>
      BackupValidationResult(isValid: true, manifest: manifest);

  factory BackupValidationResult.failure(String error) =>
      BackupValidationResult(isValid: false, errorMessage: error);

  @override
  List<Object?> get props => [isValid, manifest, errorMessage];
}
