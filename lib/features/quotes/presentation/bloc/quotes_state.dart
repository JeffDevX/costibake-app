import 'package:equatable/equatable.dart';
import '../../domain/entities/quote.dart';

abstract class QuotesState extends Equatable {
  const QuotesState();

  @override
  List<Object?> get props => [];
}

class QuotesInitial extends QuotesState {
  const QuotesInitial();
}

class QuotesLoading extends QuotesState {
  const QuotesLoading();
}

class QuotesLoaded extends QuotesState {
  final List<Quote> quotes;
  final List<Quote> filteredQuotes;
  final String query;
  final QuoteStatus? statusFilter;

  const QuotesLoaded({
    required this.quotes,
    required this.filteredQuotes,
    this.query = '',
    this.statusFilter,
  });

  QuotesLoaded copyWith({
    List<Quote>? quotes,
    List<Quote>? filteredQuotes,
    String? query,
    QuoteStatus? statusFilter,
    bool clearStatusFilter = false,
  }) {
    return QuotesLoaded(
      quotes: quotes ?? this.quotes,
      filteredQuotes: filteredQuotes ?? this.filteredQuotes,
      query: query ?? this.query,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
    );
  }

  @override
  List<Object?> get props => [quotes, filteredQuotes, query, statusFilter];
}

class QuotesError extends QuotesState {
  final String message;

  const QuotesError(this.message);

  @override
  List<Object?> get props => [message];
}
