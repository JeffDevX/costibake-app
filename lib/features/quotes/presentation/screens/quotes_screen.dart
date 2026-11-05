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

  Widget _buildFilterChip({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? accentColor,
  }) {
    final colors = context.bakeryColors;
    final isCacao = context.isCacaoMode;
    final activeColor = accentColor ?? colors.primaryCaramel;

    return FilterChip(
      key: key,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? (isCacao ? activeColor : colors.primaryDarkCaramel)
              : colors.textMuted,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: colors.surfaceCard,
      selectedColor: isCacao
          ? activeColor.withValues(alpha: 0.25)
          : activeColor.withValues(alpha: 0.18),
      checkmarkColor: isCacao ? activeColor : colors.primaryDarkCaramel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? activeColor : colors.borderWarm,
          width: isSelected ? 1.4 : 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bakeryColors;
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
        backgroundColor: colors.butterCream,
        foregroundColor: colors.primaryDarkCaramel,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        key: const Key('btn_add_quote'),
        onPressed: () => _openNewQuote(context),
        backgroundColor: colors.primaryCaramel,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Cotización'),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: colors.butterCream,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                TextField(
                  key: const Key('txt_search_quotes'),
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: colors.textEspresso),
                  decoration: InputDecoration(
                    hintText: 'Buscar por cliente, notas o pastel...',
                    hintStyle: TextStyle(
                      color: context.isCacaoMode
                          ? const Color(0xFFD4C3B3)
                          : colors.textMuted,
                    ),
                    prefixIcon: Icon(Icons.search, color: colors.primaryCaramel),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: colors.textMuted),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: colors.surfaceWarm,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colors.primaryCaramel, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        key: const Key('chip_filter_all'),
                        label: 'Todas',
                        isSelected: _selectedStatus == null,
                        onSelected: () => _onStatusFilterSelected(null),
                        accentColor: colors.primaryCaramel,
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        key: const Key('chip_filter_pending'),
                        label: 'Pendientes',
                        isSelected: _selectedStatus == QuoteStatus.pending,
                        onSelected: () => _onStatusFilterSelected(QuoteStatus.pending),
                        accentColor: colors.warningAmber,
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        key: const Key('chip_filter_confirmed'),
                        label: 'Confirmadas',
                        isSelected: _selectedStatus == QuoteStatus.confirmed,
                        onSelected: () => _onStatusFilterSelected(QuoteStatus.confirmed),
                        accentColor: colors.primaryCaramel,
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        key: const Key('chip_filter_delivered'),
                        label: 'Entregadas',
                        isSelected: _selectedStatus == QuoteStatus.delivered,
                        onSelected: () => _onStatusFilterSelected(QuoteStatus.delivered),
                        accentColor: colors.profitGreen,
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        key: const Key('chip_filter_cancelled'),
                        label: 'Canceladas',
                        isSelected: _selectedStatus == QuoteStatus.cancelled,
                        onSelected: () => _onStatusFilterSelected(QuoteStatus.cancelled),
                        accentColor: colors.textMuted,
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
                        style: TextStyle(color: colors.costRed),
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
                                decoration: BoxDecoration(
                                  color: colors.surfaceHighlight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.request_quote_outlined,
                                  size: 56,
                                  color: colors.primaryCaramel,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aún no hay cotizaciones registradas',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textEspresso,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Cree presupuestos en segundos para sus clientes con sus recetas y compártalos por WhatsApp con comprobante digital.',
                                style: TextStyle(fontSize: 14, color: colors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                key: const Key('btn_empty_create_quote'),
                                onPressed: () => _openNewQuote(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Crear primera cotización'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primaryCaramel,
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

                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: colors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'No se encontraron cotizaciones con este filtro o búsqueda',
                              style: TextStyle(color: colors.textMuted, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
