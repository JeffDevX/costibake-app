import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Manifest containing metadata and cryptographic verification checksum
/// for a CostiBake `.cbake` backup archive.
class BackupManifest extends Equatable {
  final int formatVersion;
  final String appName;
  final int databaseVersion;
  final DateTime createdAt;
  final Map<String, int> tableCounts;
  final String checksum;

  const BackupManifest({
    required this.formatVersion,
    required this.appName,
    required this.databaseVersion,
    required this.createdAt,
    required this.tableCounts,
    required this.checksum,
  });

  /// Total number of individual records backed up across all tables.
  int get totalRecords =>
      tableCounts.values.fold(0, (sum, count) => sum + count);

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'appName': appName,
        'databaseVersion': databaseVersion,
        'createdAt': createdAt.toIso8601String(),
        'tableCounts': tableCounts,
        'checksum': checksum,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      formatVersion: json['formatVersion'] as int? ?? 1,
      appName: json['appName'] as String? ?? 'CostiBake',
      databaseVersion: json['databaseVersion'] as int? ?? 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
      tableCounts: (json['tableCounts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0),
          ) ??
          const {},
      checksum: json['checksum'] as String? ?? '',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory BackupManifest.fromJsonString(String source) =>
      BackupManifest.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  List<Object?> get props => [
        formatVersion,
        appName,
        databaseVersion,
        createdAt,
        tableCounts,
        checksum,
      ];
}
