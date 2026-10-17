import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../../core/widgets/responsive_center.dart';
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
                      const SizedBox(height: 16),

                      // Sección 3: Almacenamiento Offline & Persistencia
                      _buildStorageCard(),
                      const SizedBox(height: 24),

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

  Widget _buildStorageCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: AppColors.profitGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Almacenamiento y Seguridad',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textEspresso,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.storage, color: AppColors.primaryCaramel),
              title: Text('Modo Offline-First Activo'),
              subtitle: Text(
                'Tus parámetros se almacenan localmente en SQLite y persisten incluso sin conexión a internet.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
