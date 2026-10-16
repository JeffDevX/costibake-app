import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/dependency_block_info.dart';

/// Second-level explicit confirmation modal required to force-delete a catalog
/// item that has active recipe dependencies (`RF-SYS-23`, `BR-FRC-01`, `BR-FRC-02`).
///
/// Requires the user to type `"ELIMINAR"` to confirm they understand that
/// all dependent recipes will immediately transition to
/// `INCOMPLETA_REQUIERE_REVISION`.
class ForcedDeleteConfirmationDialog extends StatefulWidget {
  final DependencyBlockInfo blockInfo;

  const ForcedDeleteConfirmationDialog({
    super.key,
    required this.blockInfo,
  });

  /// Shows the second-level confirmation dialog and returns `true` only if the
  /// user explicitly typed `"ELIMINAR"` and confirmed.
  static Future<bool> show(
    BuildContext context, {
    required DependencyBlockInfo blockInfo,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForcedDeleteConfirmationDialog(blockInfo: blockInfo),
    );
    return result == true;
  }

  @override
  State<ForcedDeleteConfirmationDialog> createState() =>
      _ForcedDeleteConfirmationDialogState();
}

class _ForcedDeleteConfirmationDialogState
    extends State<ForcedDeleteConfirmationDialog> {
  static const String requiredConfirmationWord = 'ELIMINAR';
  final TextEditingController _confirmController = TextEditingController();

  bool get _isConfirmed =>
      _confirmController.text.trim().toUpperCase() == requiredConfirmationWord;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.blockInfo.affectedCount;
    final recipeWord = count == 1 ? 'receta pasará' : 'recetas pasarán';
    final itemTypeLabel = widget.blockInfo.isPackaging ? 'empaque' : 'insumo';

    return AlertDialog(
      key: const Key('forced_delete_confirmation_dialog'),
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.costRed.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.costRed,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmar Borrado Forzado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textEspresso,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Confirmación de segundo nivel (BR-FRC-01)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningAmberLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warningAmber.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'Al forzar la eliminación del $itemTypeLabel "${widget.blockInfo.itemName}", '
                '$count $recipeWord a estado INCOMPLETA (Requiere Revisión) y su '
                'precio de venta sugerido quedará deshabilitado hasta asignar un sustituto.',
                key: const Key('forced_delete_warning_text'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textEspresso,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Recetas que quedarán incompletas (${widget.blockInfo.affectedRecipeNames.join(', ')}):',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Escribe "ELIMINAR" para habilitar el borrado forzado:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textEspresso,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('input_confirm_force_delete'),
              controller: _confirmController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: requiredConfirmationWord,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderWarm),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          height: 48,
          child: TextButton(
            key: const Key('btn_cancel_force_delete'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textEspresso,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('btn_confirm_force_delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isConfirmed ? AppColors.costRed : AppColors.borderSubtle,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: _isConfirmed
                ? () => Navigator.of(context).pop(true)
                : null,
            icon: const Icon(Icons.delete_forever_outlined, size: 18),
            label: const Text(
              'Forzar Borrado',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
