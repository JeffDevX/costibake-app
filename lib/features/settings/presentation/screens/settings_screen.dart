import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parámetros del Taller'),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoading || state is SettingsInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SettingsError) {
            return Center(child: Text('Error: ${state.message}'));
          }

          if (state is SettingsLoaded) {
            final config = state.config;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Datos del Negocio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textEspresso,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.store, color: AppColors.primaryCaramel),
                          title: const Text('Nombre del Taller / Obrador'),
                          subtitle: Text(config.businessName),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.attach_money, color: AppColors.primaryCaramel),
                          title: const Text('Símbolo de Moneda'),
                          subtitle: Text(config.currencySymbol),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tarifas y Prorrateos Globales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textEspresso,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.timer, color: AppColors.primaryCaramel),
                          title: const Text('Tarifa de Mano de Obra'),
                          subtitle: Text(
                              '${config.currencySymbol}${config.laborHourlyRate.toStringAsFixed(2)} / hora'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.flash_on, color: AppColors.primaryCaramel),
                          title: const Text('Overhead / Costos Indirectos'),
                          subtitle: Text(
                              '${config.overheadPercentage.toStringAsFixed(1)}% sobre base directa'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Almacenamiento y Seguridad',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textEspresso,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.security, color: AppColors.profitGreen),
                          title: Text('Modo Offline-First Activo'),
                          subtitle: Text(
                              'Persistencia local transaccional SQLite con cifrado sandbox'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
