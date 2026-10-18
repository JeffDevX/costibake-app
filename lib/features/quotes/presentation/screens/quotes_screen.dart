import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/precise_decimal.dart';
import '../../../settings/domain/entities/business_config.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../domain/entities/quote.dart';
import '../bloc/quotes_bloc.dart';
import '../bloc/quotes_event.dart';
import '../bloc/quotes_state.dart';
import '../widgets/quote_card.dart';
import 'quote_form_screen.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  QuoteStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    context.read<QuotesBloc>().add(const LoadQuotes());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<QuotesBloc>().add(
          FilterQuotes(
            query: query,
            statusFilter: _selectedStatus,
          ),
        );
  }

  void _onStatusFilterSelected(QuoteStatus? status) {
    setState(() => _selectedStatus = status);
    context.read<QuotesBloc>().add(
          FilterQuotes(
            query: _searchCtrl.text,
            statusFilter: _selectedStatus,
          ),
        );
  }

  void _openNewQuote(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QuoteFormScreen(),
      ),
    );
  }

  void _openEditQuote(BuildContext context, Quote quote) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuoteFormScreen(quoteToEdit: quote),
      ),
    );
  }

  void _confirmDeleteQuote(BuildContext context, Quote quote) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cotización'),
        content: Text('¿Desea eliminar la cotización para "${quote.clientName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<QuotesBloc>().add(DeleteQuoteEvent(quote.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cotización eliminada'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = context.watch<SettingsBloc>().state;
    final config = settingsState is SettingsLoaded
        ? settingsState.config
        : BusinessConfig(
            id: 'default',
            businessName: 'Mi Repostería',
            currencySymbol: '\$',
            laborHourlyRate: PreciseDecimal.fromString('10.00'),
            overheadPercentage: PreciseDecimal.fromString('15.00'),
            updatedAt: DateTime.now(),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotizaciones y Pedidos'),
        backgroundColor: AppColors.butterCream,
        foregroundColor: AppColors.primaryDarkCaramel,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('btn_add_quote'),
        onPressed: () => _openNewQuote(context),
        backgroundColor: AppColors.primaryCaramel,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Cotización'),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: AppColors.butterCream,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                TextField(
                  key: const Key('txt_search_quotes'),
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar por cliente, notas o pastel...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryCaramel),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        key: const Key('chip_filter_all'),
                        label: const Text('Todas'),
                        selected: _selectedStatus == null,
                        onSelected: (_) => _onStatusFilterSelected(null),
                        selectedColor: AppColors.primaryCaramel.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        key: const Key('chip_filter_pending'),
                        label: const Text('Pendientes'),
                        selected: _selectedStatus == QuoteStatus.pending,
                        onSelected: (_) => _onStatusFilterSelected(QuoteStatus.pending),
                        selectedColor: Colors.orange.shade100,
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        key: const Key('chip_filter_confirmed'),
                        label: const Text('Confirmadas'),
                        selected: _selectedStatus == QuoteStatus.confirmed,
                        onSelected: (_) => _onStatusFilterSelected(QuoteStatus.confirmed),
                        selectedColor: AppColors.primaryCaramel.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        key: const Key('chip_filter_delivered'),
                        label: const Text('Entregadas'),
                        selected: _selectedStatus == QuoteStatus.delivered,
                        onSelected: (_) => _onStatusFilterSelected(QuoteStatus.delivered),
                        selectedColor: Colors.green.shade100,
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        key: const Key('chip_filter_cancelled'),
                        label: const Text('Canceladas'),
                        selected: _selectedStatus == QuoteStatus.cancelled,
                        onSelected: (_) => _onStatusFilterSelected(QuoteStatus.cancelled),
                        selectedColor: Colors.grey.shade300,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: BlocBuilder<QuotesBloc, QuotesState>(
              builder: (context, state) {
                if (state is QuotesLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is QuotesError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (state is QuotesLoaded) {
                  final quotes = state.filteredQuotes;

                  if (quotes.isEmpty) {
                    if (state.quotes.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: AppColors.butterCream,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.request_quote_outlined,
                                  size: 56,
                                  color: AppColors.primaryCaramel,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Aún no hay cotizaciones registradas',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textEspresso,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Cree presupuestos en segundos para sus clientes con sus recetas y compártalos por WhatsApp con comprobante digital.',
                                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                key: const Key('btn_empty_create_quote'),
                                onPressed: () => _openNewQuote(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Crear primera cotización'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryCaramel,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'No se encontraron cotizaciones con este filtro o búsqueda',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: quotes.length,
                    itemBuilder: (context, index) {
                      final quote = quotes[index];
                      return QuoteCard(
                        quote: quote,
                        config: config,
                        onTap: () => _openEditQuote(context, quote),
                        onStatusChanged: (newStatus) {
                          context.read<QuotesBloc>().add(
                                UpdateQuoteStatusEvent(quote.id, newStatus),
                              );
                        },
                        onDelete: () => _confirmDeleteQuote(context, quote),
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}
