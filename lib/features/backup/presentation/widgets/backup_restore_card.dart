import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../catalog/presentation/bloc/catalog_bloc.dart';
import '../../../catalog/presentation/bloc/catalog_event.dart';
import '../../../quotes/presentation/bloc/quotes_bloc.dart';
import '../../../quotes/presentation/bloc/quotes_event.dart';
import '../../../recipes/presentation/bloc/recipes_bloc.dart';
import '../../../recipes/presentation/bloc/recipes_event.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_event.dart';
import '../../data/services/backup_service_impl.dart';
import '../../domain/entities/backup_manifest.dart';
import '../../domain/services/backup_service.dart';

/// Interactive UI card for exporting and importing `.cbake` backups (JEF-32).
class BackupRestoreCard extends StatefulWidget {
  final BackupService? backupService;

  const BackupRestoreCard({
    super.key,
    this.backupService,
  });

  @override
  State<BackupRestoreCard> createState() => _BackupRestoreCardState();
}

class _BackupRestoreCardState extends State<BackupRestoreCard> {
  late final BackupService _backupService;
  bool _isProcessing = false;
  Map<String, int>? _stats;

  @override
  void initState() {
    super.initState();
    _backupService = widget.backupService ?? BackupServiceImpl();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _backupService.getDatabaseStats();
      if (mounted) {
        setState(() => _stats = stats);
      }
    } catch (_) {
      // Ignored if DB is busy or testing
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isProcessing = true);
    try {
      final result = await _backupService.createBackup();
      if (!mounted) return;

      _showBackupSuccessDialog(result.filePath, result.fileName, result.manifest);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear copia de seguridad: $e'),
          backgroundColor: AppColors.costRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showBackupSuccessDialog(
    String filePath,
    String fileName,
    BackupManifest manifest,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.profitGreen, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Copia Creada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se generó el archivo de respaldo seguro:',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.butterCream,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.honeyAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.archive, color: AppColors.primaryCaramel),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStatRow('Recetas:', '${manifest.tableCounts['RECETA'] ?? 0}'),
              _buildStatRow('Insumos:', '${manifest.tableCounts['INSUMO'] ?? 0}'),
              _buildStatRow('Empaques:', '${manifest.tableCounts['EMPAQUE'] ?? 0}'),
              _buildStatRow('Cotizaciones:', '${manifest.tableCounts['COTIZACION'] ?? 0}'),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total de Registros:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${manifest.totalRecords}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryCaramel),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Integridad verificada con hash SHA-256.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            key: const Key('btn_share_backup'),
            onPressed: () async {
              Navigator.pop(ctx);
              await SharePlus.instance.share(
                ShareParams(
                  files: [XFile(filePath, mimeType: 'application/octet-stream')],
                  subject: 'Copia de Seguridad CostiBake ($fileName)',
                  text: 'Respaldo seguro de mi recetario y cotizaciones en CostiBake.',
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCaramel,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Compartir / Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndRestoreBackup() async {
    try {
      final pickResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['cbake', 'zip'],
        withData: true,
      );

      if (pickResult == null || pickResult.files.isEmpty) return;

      final file = pickResult.files.first;
      final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo leer el archivo seleccionado.'),
            backgroundColor: AppColors.costRed,
          ),
        );
        return;
      }

      setState(() => _isProcessing = true);
      final validation = await _backupService.validateBackupFile(bytes);
      setState(() => _isProcessing = false);

      if (!mounted) return;

      if (!validation.isValid || validation.manifest == null) {
        _showErrorDialog(validation.errorMessage ?? 'El archivo no es una copia válida.');
        return;
      }

      _showConfirmRestoreDialog(bytes, validation.manifest!);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog('Error al procesar el archivo: $e');
      }
    }
  }

  @visibleForTesting
  void callRestoreForTest(Uint8List bytes, BackupManifest manifest) {
    _showConfirmRestoreDialog(bytes, manifest);
  }

  void _showConfirmRestoreDialog(List<int> bytes, BackupManifest manifest) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(manifest.createdAt);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.costRed, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirmar Restauración',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.costRedLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.costRed),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.priority_high, color: AppColors.costRed, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¡ATENCIÓN! Esta acción reemplazará toda la base de datos actual con los datos del respaldo seleccionado.',
                        style: TextStyle(
                          color: AppColors.costRed,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Detalles de la Copia a Restaurar:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _buildStatRow('Fecha de creación:', dateStr),
              _buildStatRow('Recetas:', '${manifest.tableCounts['RECETA'] ?? 0}'),
              _buildStatRow('Insumos:', '${manifest.tableCounts['INSUMO'] ?? 0}'),
              _buildStatRow('Empaques:', '${manifest.tableCounts['EMPAQUE'] ?? 0}'),
              _buildStatRow('Cotizaciones:', '${manifest.tableCounts['COTIZACION'] ?? 0}'),
              _buildStatRow('Total de registros:', '${manifest.totalRecords}'),
              const SizedBox(height: 12),
              const Text(
                '¿Estás completamente seguro de sobrescribir los datos actuales?',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('btn_confirm_restore_db'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeRestore(bytes, manifest);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.costRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sobrescribir y Restaurar'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeRestore(List<int> bytes, BackupManifest manifest) async {
    setState(() => _isProcessing = true);
    try {
      await _backupService.restoreBackup(Uint8List.fromList(bytes));

      // Reload all active BLoCs
      if (!mounted) return;
      context.read<CatalogBloc>().add(const LoadCatalog());
      context.read<RecipesBloc>().add(const LoadRecipes());
      context.read<SettingsBloc>().add(const LoadSettings());
      context.read<QuotesBloc>().add(const LoadQuotes());

      await _loadStats();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¡Base de datos restaurada con éxito! Se restauraron ${manifest.totalRecords} registros.',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.profitGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error al restaurar los datos: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.costRed),
            SizedBox(width: 8),
            Text('Error de Respaldo'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipeCount = _stats?['RECETA'] ?? 0;
    final ingredientCount = _stats?['INSUMO'] ?? 0;
    final quoteCount = _stats?['COTIZACION'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.backup_outlined, color: AppColors.primaryCaramel),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Copia de Seguridad y Restauración',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tus recetas, insumos, costos y cotizaciones se guardan de forma 100% segura en tu dispositivo. Puedes exportar una copia `.cbake` para respaldar tu negocio o transferirlo a otro teléfono.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.butterCream,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildCountBadge('$recipeCount', 'Recetas')),
                  Expanded(child: _buildCountBadge('$ingredientCount', 'Insumos')),
                  Expanded(child: _buildCountBadge('$quoteCount', 'Cotizaciones')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Procesando copia de seguridad...',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const Key('btn_create_backup'),
                      onPressed: _createBackup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.honeyAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.file_download_outlined),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Crear Copia de Seguridad (.cbake)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('btn_restore_backup'),
                      onPressed: _pickAndRestoreBackup,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textEspresso,
                        side: const BorderSide(color: AppColors.primaryCaramel),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.settings_backup_restore, color: AppColors.primaryCaramel),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Restaurar desde Archivo (.cbake)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryCaramel,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
