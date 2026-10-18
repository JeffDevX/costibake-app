import 'dart:typed_data';
import '../entities/backup_manifest.dart';
import '../entities/backup_result.dart';

/// Contract for managing CostiBake backup generation, validation and transactional restoration.
abstract class BackupService {
  /// Generates a timestamped `.cbake` archive containing all tables and metadata.
  Future<BackupExportResult> createBackup();

  /// Inspects and validates a `.cbake` archive file without modifying the active database.
  Future<BackupValidationResult> validateBackupFile(Uint8List fileBytes);

  /// Restores the entire database from the given `.cbake` archive within an ACID transaction.
  Future<BackupManifest> restoreBackup(Uint8List fileBytes);

  /// Returns current record counts for each main table in the database.
  Future<Map<String, int>> getDatabaseStats();
}
