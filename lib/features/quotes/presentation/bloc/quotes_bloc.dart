import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/quote.dart';
import '../../domain/repositories/quote_repository.dart';
import 'quotes_event.dart';
import 'quotes_state.dart';

class QuotesBloc extends Bloc<QuotesEvent, QuotesState> {
  final QuoteRepository quoteRepository;

  QuotesBloc({required this.quoteRepository}) : super(const QuotesInitial()) {
    on<LoadQuotes>(_onLoadQuotes);
    on<FilterQuotes>(_onFilterQuotes);
    on<SaveQuoteEvent>(_onSaveQuote);
    on<DeleteQuoteEvent>(_onDeleteQuote);
    on<UpdateQuoteStatusEvent>(_onUpdateQuoteStatus);
  }

  Future<void> _onLoadQuotes(LoadQuotes event, Emitter<QuotesState> emit) async {
    emit(const QuotesLoading());
    try {
      final quotes = await quoteRepository.getAllQuotes();
      emit(QuotesLoaded(
        quotes: quotes,
        filteredQuotes: quotes,
      ));
    } catch (e) {
      emit(QuotesError('Error al cargar cotizaciones: ${e.toString()}'));
    }
  }

  void _onFilterQuotes(FilterQuotes event, Emitter<QuotesState> emit) {
    if (state is QuotesLoaded) {
      final currentState = state as QuotesLoaded;
      final filtered = _applyFilter(currentState.quotes, event.query, event.statusFilter);
      emit(currentState.copyWith(
        query: event.query,
        statusFilter: event.statusFilter,
        clearStatusFilter: event.statusFilter == null,
        filteredQuotes: filtered,
      ));
    }
  }

  Future<void> _onSaveQuote(SaveQuoteEvent event, Emitter<QuotesState> emit) async {
    try {
      await quoteRepository.saveQuote(event.quote);
      final quotes = await quoteRepository.getAllQuotes();
      final currentQuery = state is QuotesLoaded ? (state as QuotesLoaded).query : '';
      final currentStatus = state is QuotesLoaded ? (state as QuotesLoaded).statusFilter : null;
      final filtered = _applyFilter(quotes, currentQuery, currentStatus);

      emit(QuotesLoaded(
        quotes: quotes,
        filteredQuotes: filtered,
        query: currentQuery,
        statusFilter: currentStatus,
      ));
    } catch (e) {
      emit(QuotesError('Error al guardar la cotización: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteQuote(DeleteQuoteEvent event, Emitter<QuotesState> emit) async {
    try {
      await quoteRepository.deleteQuote(event.id);
      final quotes = await quoteRepository.getAllQuotes();
      final currentQuery = state is QuotesLoaded ? (state as QuotesLoaded).query : '';
      final currentStatus = state is QuotesLoaded ? (state as QuotesLoaded).statusFilter : null;
      final filtered = _applyFilter(quotes, currentQuery, currentStatus);

      emit(QuotesLoaded(
        quotes: quotes,
        filteredQuotes: filtered,
        query: currentQuery,
        statusFilter: currentStatus,
      ));
    } catch (e) {
      emit(QuotesError('Error al eliminar la cotización: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateQuoteStatus(UpdateQuoteStatusEvent event, Emitter<QuotesState> emit) async {
    try {
      await quoteRepository.updateQuoteStatus(event.id, event.newStatus);
      final quotes = await quoteRepository.getAllQuotes();
      final currentQuery = state is QuotesLoaded ? (state as QuotesLoaded).query : '';
      final currentStatus = state is QuotesLoaded ? (state as QuotesLoaded).statusFilter : null;
      final filtered = _applyFilter(quotes, currentQuery, currentStatus);

      emit(QuotesLoaded(
        quotes: quotes,
        filteredQuotes: filtered,
        query: currentQuery,
        statusFilter: currentStatus,
      ));
    } catch (e) {
      emit(QuotesError('Error al actualizar estado: ${e.toString()}'));
    }
  }

  List<Quote> _applyFilter(List<Quote> quotes, String query, QuoteStatus? status) {
    final lowerQ = query.trim().toLowerCase();
    return quotes.where((q) {
      final matchesStatus = status == null || q.status == status;
      if (!matchesStatus) return false;

      if (lowerQ.isEmpty) return true;

      final matchesClient = q.clientName.toLowerCase().contains(lowerQ);
      final matchesPhone = q.clientPhone?.toLowerCase().contains(lowerQ) ?? false;
      final matchesNotes = q.eventNotes?.toLowerCase().contains(lowerQ) ?? false;
      final matchesItems = q.items.any((i) => i.concept.toLowerCase().contains(lowerQ));

      return matchesClient || matchesPhone || matchesNotes || matchesItems;
    }).toList();
  }
}
