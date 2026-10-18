import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/services/ai_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../backup/presentation/widgets/backup_restore_card.dart';
import '../../domain/entities/business_config.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

/// Screen for viewing and updating global business parameters:
/// Labor hourly rate and overhead indirect cost percentage (JEF-6, SUC-07, BR-CFG-01..04).
class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const SettingsScreen({
    super.key,
    this.onBackToHome,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _currencyController;
  late TextEditingController _laborRateController;
  late TextEditingController _overheadController;

  String? _lastLoadedId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _currencyController = TextEditingController();
    _laborRateController = TextEditingController();
    _overheadController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _laborRateController.dispose();
    _overheadController.dispose();
    super.dispose();
  }

  void _populateControllers(BusinessConfig config) {
    if (_lastLoadedId != config.id || _nameController.text.isEmpty) {
      _nameController.text = config.businessName;
      _currencyController.text = config.currencySymbol;
      _laborRateController.text = config.laborHourlyRate.toStringAsFixed(2);
      _overheadController.text = config.overheadPercentage.toStringAsFixed(1);
      _lastLoadedId = config.id;
    }
  }

  Future<void> _saveSettings(BusinessConfig currentConfig) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updatedConfig = currentConfig.copyWith(
        businessName: _nameController.text.trim(),
        currencySymbol: _currencyController.text.trim(),
        laborHourlyRate:
            PreciseDecimal.fromString(_laborRateController.text.trim()),
        overheadPercentage:
            PreciseDecimal.fromString(_overheadController.text.trim()),
        updatedAt: DateTime.now(),
      );

      context.read<SettingsBloc>().add(UpdateSettings(updatedConfig));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Configuración guardada exitosamente'),
                ),
              ],
            ),
            backgroundColor: AppColors.profitGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.costRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final showBack = canPop || widget.onBackToHome != null;

    return Scaffold(
      appBar: AppBar(
        leading: showBack
            ? IconButton(
                key: const Key('btn_settings_back'),
                icon: const Icon(Icons.arrow_back),
                tooltip: canPop ? 'Atrás' : 'Volver a Catálogo',
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  if (canPop) {
                    Navigator.pop(context);
                  } else {
                    widget.onBackToHome?.call();
                  }
                },
              )
            : null,
        title: const Text('Configuración del Taller'),
        actions: [
          IconButton(
            key: const Key('btn_settings_hide_keyboard'),
            icon: const Icon(Icons.keyboard_hide),
            tooltip: 'Ocultar Teclado',
            onPressed: () => FocusScope.of(context).unfocus(),
          ),
        ],
      ),
      body: BlocConsumer<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsLoaded) {
            _populateControllers(state.config);
          }
        },
        builder: (context, state) {
          if (state is SettingsLoading || state is SettingsInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SettingsError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.costRed),
                    const SizedBox(height: 16),
                    Text('Error: ${state.message}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.read<SettingsBloc>().add(const LoadSettings()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is SettingsLoaded) {
            final config = state.config;
            _populateControllers(config);

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              child: ResponsiveCenter(
                maxWidth: AppBreakpoints.maxFormWidth,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sección 1: Datos de Identidad del Taller
                      _buildIdentityCard(),
                      const SizedBox(height: 16),

                      // Sección 2: Parámetros Financieros (BR-CFG-01, BR-CFG-02)
                      _buildFinancialCard(),
                      const SizedBox(height: 20),

                      // Botón de Guardado (Kitchen Ergonomics >= 48px)
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          key: const Key('save_settings_button'),
                          onPressed: _isSaving ? null : () => _saveSettings(config),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryCaramel,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving
                                ? 'Guardando Cambios...'
                                : 'Guardar Parámetros de Taller',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sección 3: Inteligencia Artificial Gemini (API Key)
                      const _AiConfigCard(),
                      const SizedBox(height: 24),

                      // Sección 4: Copia de Seguridad y Restauración (JEF-32)
                      const BackupRestoreCard(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildIdentityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storefront_outlined,
                    color: AppColors.primaryCaramel),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Identidad del Negocio',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('business_name_field'),
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre del Taller / Obrador *',
                hintText: 'Ej. Sweet Boutique Repostería',
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre del negocio es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('currency_symbol_field'),
              controller: _currencyController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Símbolo de Moneda *',
                hintText: 'Ej. \$, €, S/, MXN\$',
                prefixIcon: Icon(Icons.monetization_on_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El símbolo de moneda es obligatorio';
                }
                if (value.trim().length > 5) {
                  return 'Máximo 5 caracteres';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune_outlined, color: AppColors.primaryCaramel),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tarifas y Prorrateos Globales',
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
            const Text(
              'Estos valores se usan como predeterminados en el costeo de nuevas recetas.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            // Tarifa de Mano de Obra (BR-CFG-01 >= 0.00)
            TextFormField(
              key: const Key('labor_rate_field'),
              controller: _laborRateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: const InputDecoration(
                labelText: 'Tarifa de Mano de Obra por Hora *',
                hintText: '0.00',
                prefixIcon: Icon(Icons.timer_outlined),
                suffixText: '/ hora',
                helperText:
                    'Costo estimado por hora de trabajo directo (BR-CFG-01 >= 0.00)',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa la tarifa de mano de obra';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null) {
                  return 'Ingresa un valor numérico válido';
                }
                if (parsed < 0) {
                  return 'La tarifa no puede ser negativa (BR-CFG-01)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Overhead / Costos Indirectos (BR-CFG-02 entre 0.00% y 100.00%)
            TextFormField(
              key: const Key('overhead_percentage_field'),
              controller: _overheadController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: const InputDecoration(
                labelText: 'Porcentaje de Costos Indirectos (Overhead) *',
                hintText: '15.0',
                prefixIcon: Icon(Icons.bolt_outlined),
                suffixText: '%',
                helperText:
                    'Sugerido entre 10% y 25% para servicios y desgaste (BR-CFG-02 0-100%)',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa el porcentaje de overhead';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null) {
                  return 'Ingresa un valor numérico válido';
                }
                if (parsed < 0 || parsed > 100) {
                  return 'El porcentaje debe estar entre 0.00% y 100.00% (BR-CFG-02)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

}

class _AiConfigCard extends StatefulWidget {
  const _AiConfigCard();

  @override
  State<_AiConfigCard> createState() => _AiConfigCardState();
}

class _AiConfigCardState extends State<_AiConfigCard> {
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _hasBundledKey = false;
  AiKeySource _source = AiKeySource.none;
  String? _testFeedback;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadKeyStatus();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  AiConfigService _getAiService() {
    try {
      return context.read<AiConfigService>();
    } catch (_) {
      return AiConfigService();
    }
  }

  Future<void> _loadKeyStatus() async {
    final aiService = _getAiService();
    final source = await aiService.getApiKeySource();
    final key = await aiService.getApiKey();
    final hasBundled = aiService.hasBundledKey;

    if (mounted) {
      setState(() {
        _source = source;
        _hasBundledKey = hasBundled;
        if (key != null && key.isNotEmpty) {
          _apiKeyController.text = key;
        }
      });
    }
  }

  Future<void> _saveKey() async {
    setState(() => _isSaving = true);
    final aiService = _getAiService();
    try {
      await aiService.saveApiKey(_apiKeyController.text.trim());
      await _loadKeyStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _source == AiKeySource.userCustom
                  ? 'Clave de IA personalizada guardada con éxito'
                  : 'Clave eliminada',
            ),
            backgroundColor: AppColors.profitGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar clave: $e'),
            backgroundColor: AppColors.costRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetToBundledDefault() async {
    final aiService = _getAiService();
    await aiService.deleteApiKey();
    await _loadKeyStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se restableció a la clave predeterminada de la aplicación.'),
          backgroundColor: AppColors.profitGreen,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testFeedback = null;
      _testSuccess = null;
    });

    final aiService = _getAiService();
    final result = await aiService.testApiKeyConnection(_apiKeyController.text.trim());

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = result.isSuccessful;
        _testFeedback = result.isSuccessful
            ? '¡Conexión exitosa con Google Gemini! La clave es válida y está lista para escanear recetas.'
            : (result.errorMessage ?? 'Error desconocido al validar la clave.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String badgeText = 'Sin Clave';
    Color badgeBg = AppColors.warningAmberLight;
    Color badgeFg = AppColors.warningAmber;
    IconData badgeIcon = Icons.info_outline;

    if (_source == AiKeySource.bundledDefault) {
      badgeText = 'Clave de Fábrica (Modo Esposa)';
      badgeBg = AppColors.profitGreenLight;
      badgeFg = AppColors.profitGreen;
      badgeIcon = Icons.verified_user;
    } else if (_source == AiKeySource.userCustom) {
      badgeText = 'Clave Personalizada';
      badgeBg = const Color(0xFFF3E5F5); // light purple
      badgeFg = const Color(0xFF7B1FA2); // dark purple
      badgeIcon = Icons.tune;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primaryCaramel),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Inteligencia Artificial (Gemini 1.5)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeFg),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeFg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Digitaliza automáticamente fotos de libretas manuscritas, documentos PDF y Word para costear recetas al instante.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
            ),
            const SizedBox(height: 10),

            // Nivel Gratuito Banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.butterCream,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderWarm),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.profitGreen, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nivel Gratuito de Google AI Studio: Costo \$0.00 siempre (hasta 1,500 recetas al día sin cargos).',
                      style: TextStyle(fontSize: 12, color: AppColors.textEspresso),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              key: const Key('gemini_api_key_field'),
              controller: _apiKeyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: 'API Key de Google Gemini',
                hintText: 'AIzaSy...',
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
                helperText: 'Obtén tu clave gratuita en aistudio.google.com',
              ),
            ),

            if (_testFeedback != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _testSuccess == true
                      ? AppColors.profitGreenLight
                      : AppColors.costRedLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess == true
                        ? AppColors.profitGreen
                        : AppColors.costRed,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testSuccess == true ? Icons.check_circle : Icons.error_outline,
                      color: _testSuccess == true ? AppColors.profitGreen : AppColors.costRed,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testFeedback!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _testSuccess == true
                              ? AppColors.profitGreen
                              : AppColors.costRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Botones de Acción (Kitchen Ergonomics >= 48px)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('btn_save_ai_key'),
                      onPressed: _isSaving ? null : _saveKey,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryCaramel,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Guardar Clave',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      key: const Key('btn_test_ai_key'),
                      onPressed: _isTesting ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textEspresso,
                        side: const BorderSide(color: AppColors.primaryCaramel),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _isTesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Probar Conexión',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_source == AiKeySource.userCustom && _hasBundledKey) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  key: const Key('btn_reset_ai_key'),
                  onPressed: _resetToBundledDefault,
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text(
                    'Restablecer a Clave de Fábrica (Modo Esposa)',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
