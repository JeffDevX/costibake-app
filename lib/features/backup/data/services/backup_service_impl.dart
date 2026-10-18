import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_tables.dart';
import '../../domain/entities/backup_manifest.dart';
import '../../domain/entities/backup_result.dart';
import '../../domain/services/backup_service.dart';

/// Implementation of [BackupService] providing offline-first compressed `.cbake`
/// backups with SHA-256 cryptographic integrity validation and transactional SQLite restoration.
class BackupServiceImpl implements BackupService {
  final AppDatabase? _appDatabase;
  final Directory? _customTempDir;

  static const int currentFormatVersion = 1;
  static const String manifestFileName = 'manifest.json';
  static const String dataFileName = 'data.json';

  /// Tables ordered by parent-first hierarchy for safe foreign-key insertion.
  static const List<String> tableOrderForInsert = [
    DatabaseTables.tableConfiguracionNegocio,
    DatabaseTables.tableMatrizDensidad,
    DatabaseTables.tableInsumo,
    DatabaseTables.tableEmpaque,
    DatabaseTables.tableReceta,
    DatabaseTables.tableRecetaInsumo,
    DatabaseTables.tableRecetaSubreceta,
    DatabaseTables.tableRecetaEmpaque,
    DatabaseTables.tableCotizacion,
    DatabaseTables.tableCotizacionItem,
  ];

  BackupServiceImpl({
    AppDatabase? appDatabase,
    Directory? customTempDir,
  })  : _appDatabase = appDatabase,
        _customTempDir = customTempDir;

  Future<Database> get _db async {
    final dbClient = _appDatabase ?? AppDatabase.instance;
    return await dbClient.database;
  }

  @override
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await _db;
    final stats = <String, int>{};

    for (final table in tableOrderForInsert) {
      try {
        final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $table'),
        );
        stats[table] = count ?? 0;
      } catch (_) {
        stats[table] = 0;
      }
    }

    return stats;
  }

  @override
  Future<BackupExportResult> createBackup() async {
    final db = await _db;
    final now = DateTime.now();

    // 1. Read all tables into a structured JSON dataset
    final dataset = <String, List<Map<String, dynamic>>>{};
    final tableCounts = <String, int>{};

    for (final table in tableOrderForInsert) {
      try {
        final rows = await db.query(table);
        dataset[table] = rows;
        tableCounts[table] = rows.length;
      } catch (_) {
        dataset[table] = [];
        tableCounts[table] = 0;
      }
    }

    // 2. Encode data payload and compute SHA-256 checksum
    final dataJsonString = jsonEncode(dataset);
    final dataBytes = utf8.encode(dataJsonString);
    final checksum = sha256.convert(dataBytes).toString();

    // 3. Create Manifest
    final manifest = BackupManifest(
      formatVersion: currentFormatVersion,
      appName: AppConstants.appName,
      databaseVersion: AppConstants.databaseVersion,
      createdAt: now,
      tableCounts: tableCounts,
      checksum: checksum,
    );
    final manifestJsonString = manifest.toJsonString();
    final manifestBytes = utf8.encode(manifestJsonString);

    // 4. Archive into `.cbake` ZIP container
    final archive = Archive();
    archive.addFile(
      ArchiveFile(manifestFileName, manifestBytes.length, manifestBytes),
    );
    archive.addFile(
      ArchiveFile(dataFileName, dataBytes.length, dataBytes),
    );

    final zipEncoder = ZipEncoder();
    final encodedZip = zipEncoder.encode(archive);
    if (encodedZip == null) {
      throw Exception('Error al codificar el archivo de respaldo comprimido.');
    }
    final zipBytes = Uint8List.fromList(encodedZip);

    // 5. Generate timestamped file name (BR-BCK-01: costibake_backup_YYYYMMDD_HHMM.cbake)
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(now);
    final fileName = 'costibake_backup_$dateStr.cbake';

    final tempDir = _customTempDir ?? await getTemporaryDirectory();
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(zipBytes, flush: true);

    return BackupExportResult(
      fileName: fileName,
      filePath: filePath,
      bytes: zipBytes,
      manifest: manifest,
    );
  }

  @override
  Future<BackupValidationResult> validateBackupFile(Uint8List fileBytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(fileBytes);

      ArchiveFile? manifestFile;
      ArchiveFile? dataFile;

      for (final file in archive) {
        if (file.name == manifestFileName) {
          manifestFile = file;
        } else if (file.name == dataFileName) {
          dataFile = file;
        }
      }

      if (manifestFile == null || dataFile == null) {
        return BackupValidationResult.failure(
          'El archivo no es una copia de seguridad válida de CostiBake (archivos internos faltantes).',
        );
      }

      // Parse manifest
      final manifestJsonStr = utf8.decode(manifestFile.content as List<int>);
      final manifestMap = jsonDecode(manifestJsonStr) as Map<String, dynamic>;
      final manifest = BackupManifest.fromJson(manifestMap);

      if (manifest.appName != AppConstants.appName) {
        return BackupValidationResult.failure(
          'El archivo corresponde a otra aplicación (${manifest.appName}) y no a CostiBake.',
        );
      }

      if (manifest.formatVersion > currentFormatVersion) {
        return BackupValidationResult.failure(
          'La versión del respaldo (${manifest.formatVersion}) es más reciente que la admitida por esta versión de CostiBake ($currentFormatVersion). Por favor actualiza la aplicación.',
        );
      }

      // Verify SHA-256 Checksum
      final dataContent = dataFile.content as List<int>;
      final calculatedHash = sha256.convert(dataContent).toString();

      if (calculatedHash != manifest.checksum) {
        return BackupValidationResult.failure(
          'Fallo de integridad: El archivo de datos ha sido alterado o está corrupto (la suma de comprobación no coincide).',
        );
      }

      // Validate JSON data format
      final dataJsonStr = utf8.decode(dataContent);
      final dynamic decoded = jsonDecode(dataJsonStr);
      if (decoded is! Map<String, dynamic>) {
        return BackupValidationResult.failure(
          'La estructura interna de datos no tiene el formato esperado.',
        );
      }

      return BackupValidationResult.success(manifest);
    } catch (e) {
      return BackupValidationResult.failure(
        'No se pudo leer el archivo de respaldo: ${e.toString()}',
      );
    }
  }

  @override
  Future<BackupManifest> restoreBackup(Uint8List fileBytes) async {
    final validation = await validateBackupFile(fileBytes);
    if (!validation.isValid || validation.manifest == null) {
      throw Exception(validation.errorMessage ?? 'Copia de seguridad inválida.');
    }

    final manifest = validation.manifest!;
    final archive = ZipDecoder().decodeBytes(fileBytes);
    final dataFile = archive.firstWhere((f) => f.name == dataFileName);
    final dataJsonStr = utf8.decode(dataFile.content as List<int>);
    final dataMap = jsonDecode(dataJsonStr) as Map<String, dynamic>;

    final db = await _db;

    // Execute atomic restoration within a single ACID transaction
    await db.transaction((txn) async {
      // Temporarily disable foreign keys to cleanly clear tables without lock conflicts
      await txn.execute('PRAGMA foreign_keys = OFF;');

      // 1. Delete all current records in reverse dependency order
      final deleteOrder = tableOrderForInsert.reversed.toList();
      for (final table in deleteOrder) {
        try {
          await txn.delete(table);
        } catch (_) {
          // Table might not exist in an older schema, continue
        }
      }

      // 2. Insert records in hierarchical order
      for (final table in tableOrderForInsert) {
        final rows = dataMap[table];
        if (rows is List) {
          final batch = txn.batch();
          for (final row in rows) {
            if (row is Map<String, dynamic>) {
              batch.insert(
                table,
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
          await batch.commit(noResult: true);
        }
      }

      // Re-enable foreign key constraints
      await txn.execute('PRAGMA foreign_keys = ON;');

      // Run integrity check
      final integrityResult = await txn.rawQuery('PRAGMA integrity_check;');
      if (integrityResult.isNotEmpty) {
        final status = integrityResult.first.values.first?.toString().toLowerCase();
        if (status != 'ok') {
          throw Exception('SQLite integrity check falló tras la restauración: $status');
        }
      }
    });

    return manifest;
  }
}
