import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:costibake_app/core/database/app_database.dart';
import 'package:costibake_app/core/database/database_tables.dart';
import 'package:costibake_app/features/backup/data/services/backup_service_impl.dart';
import 'package:costibake_app/features/backup/domain/entities/backup_manifest.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDb;
  late Directory tempDir;
  late BackupServiceImpl backupService;

  setUp(() async {
    await AppDatabase.openInMemoryTestDatabase();
    appDb = AppDatabase.instance;
    tempDir = await Directory.systemTemp.createTemp('cbake_test_');
    backupService = BackupServiceImpl(
      appDatabase: appDb,
      customTempDir: tempDir,
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BackupServiceImpl Unit & Integrity Tests (JEF-32)', () {
    test('BR-BCK-01: Creates a timestamped .cbake archive with manifest and data', () async {
      final db = await appDb.database;

      // Seed an ingredient
      await db.insert(DatabaseTables.tableInsumo, {
        'id': 'insumo_harina_test',
        'nombre': 'Harina de Fuerza',
        'categoria': 'Harinas y Polvos',
        'costo_compra': '4.5000',
        'cantidad_compra': '1000.0000',
        'unidad_compra': 'g',
        'merma_porcentaje': '0.0000',
        'costo_unitario_minimo': '0.0045',
        'unidad_minima': 'g',
        'densidad_g_ml': '0.550000',
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      });

      final result = await backupService.createBackup();

      expect(result.fileName, startsWith('costibake_backup_'));
      expect(result.fileName, endsWith('.cbake'));
      expect(File(result.filePath).existsSync(), isTrue);
      expect(result.bytes.isNotEmpty, isTrue);

      // Verify manifest content
      expect(result.manifest.appName, equals('CostiBake'));
      expect(result.manifest.formatVersion, equals(1));
      expect(result.manifest.tableCounts[DatabaseTables.tableInsumo], equals(1));
      expect(result.manifest.checksum.isNotEmpty, isTrue);

      // Verify zip contains manifest.json and data.json
      final archive = ZipDecoder().decodeBytes(result.bytes);
      final fileNames = archive.map((f) => f.name).toList();
      expect(fileNames, containsAll(['manifest.json', 'data.json']));
    });

    test('BR-BCK-03: Validates valid .cbake archive successfully', () async {
      final result = await backupService.createBackup();
      final validation = await backupService.validateBackupFile(result.bytes);

      expect(validation.isValid, isTrue);
      expect(validation.errorMessage, isNull);
      expect(validation.manifest, isNotNull);
      expect(validation.manifest!.appName, equals('CostiBake'));
    });

    test('BR-BCK-03: Fails validation if checksum does not match data (tampered archive)', () async {
      // Build an archive with tampered data
      final archive = Archive();

      const tamperedData = '{"INSUMO": []}';
      final tamperedBytes = utf8.encode(tamperedData);

      final fakeManifest = BackupManifest(
        formatVersion: 1,
        appName: 'CostiBake',
        databaseVersion: 1,
        createdAt: DateTime.now(),
        tableCounts: const {},
        checksum: 'invalid_sha256_hash_here',
      );
      final manifestBytes = utf8.encode(fakeManifest.toJsonString());

      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
      archive.addFile(ArchiveFile('data.json', tamperedBytes.length, tamperedBytes));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final validation = await backupService.validateBackupFile(zipBytes);

      expect(validation.isValid, isFalse);
      expect(validation.errorMessage, contains('Fallo de integridad'));
    });

    test('BR-BCK-03: Fails validation if file is not CostiBake app', () async {
      final archive = Archive();
      const rawData = '{"INSUMO": []}';
      final dataBytes = utf8.encode(rawData);
      final realHash = sha256.convert(dataBytes).toString();

      final otherAppManifest = BackupManifest(
        formatVersion: 1,
        appName: 'OtherBakeApp',
        databaseVersion: 1,
        createdAt: DateTime.now(),
        tableCounts: const {},
        checksum: realHash,
      );
      final manifestBytes = utf8.encode(otherAppManifest.toJsonString());

      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
      archive.addFile(ArchiveFile('data.json', dataBytes.length, dataBytes));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final validation = await backupService.validateBackupFile(zipBytes);

      expect(validation.isValid, isFalse);
      expect(validation.errorMessage, contains('corresponde a otra aplicación'));
    });

    test('Restores database transactionally replacing current data with backup data', () async {
      final db = await appDb.database;

      // 1. Initial State: insert ingredient A
      await db.insert(DatabaseTables.tableInsumo, {
        'id': 'insumo_backup_a',
        'nombre': 'Vainilla Bourbon Original',
        'categoria': 'Esencias',
        'costo_compra': '25.0000',
        'cantidad_compra': '100.0000',
        'unidad_compra': 'ml',
        'merma_porcentaje': '0.0000',
        'costo_unitario_minimo': '0.2500',
        'unidad_minima': 'ml',
        'densidad_g_ml': '1.000000',
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      });

      // 2. Generate backup
      final backup = await backupService.createBackup();

      // 3. Mutate database: delete ingredient A and insert ingredient B
      await db.delete(DatabaseTables.tableInsumo);
      await db.insert(DatabaseTables.tableInsumo, {
        'id': 'insumo_post_backup_b',
        'nombre': 'Canela de Ceilán',
        'categoria': 'Especias',
        'costo_compra': '12.0000',
        'cantidad_compra': '50.0000',
        'unidad_compra': 'g',
        'merma_porcentaje': '0.0000',
        'costo_unitario_minimo': '0.2400',
        'unidad_minima': 'g',
        'densidad_g_ml': '0.500000',
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      });

      final countBeforeRestore = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM ${DatabaseTables.tableInsumo} WHERE id = 'insumo_post_backup_b'"),
      );
      expect(countBeforeRestore, equals(1));

      // 4. Restore backup
      final restoredManifest = await backupService.restoreBackup(backup.bytes);
      expect(restoredManifest.appName, equals('CostiBake'));

      // 5. Verify database matches backup state: ingredient A is back, ingredient B is gone
      final countA = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM ${DatabaseTables.tableInsumo} WHERE id = 'insumo_backup_a'"),
      );
      final countB = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM ${DatabaseTables.tableInsumo} WHERE id = 'insumo_post_backup_b'"),
      );

      expect(countA, equals(1));
      expect(countB, equals(0));
    });

    test('getDatabaseStats returns correct counts', () async {
      final db = await appDb.database;
      await db.insert(DatabaseTables.tableEmpaque, {
        'id': 'emp_1',
        'nombre': 'Caja 25x25',
        'categoria': 'Cajas',
        'costo_paquete': '15.0000',
        'unidades_por_paquete': 10,
        'costo_unitario': '1.5000',
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      });

      final stats = await backupService.getDatabaseStats();
      expect(stats[DatabaseTables.tableEmpaque], equals(1));
      expect(stats.containsKey(DatabaseTables.tableReceta), isTrue);
    });
  });
}
