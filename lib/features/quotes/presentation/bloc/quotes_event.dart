import 'package:equatable/equatable.dart';
import '../../domain/entities/quote.dart';

abstract class QuotesEvent extends Equatable {
  const QuotesEvent();

  @override
  List<Object?> get props => [];
}

class LoadQuotes extends QuotesEvent {
  const LoadQuotes();
}

class FilterQuotes extends QuotesEvent {
  final String query;
  final QuoteStatus? statusFilter;

  const FilterQuotes({this.query = '', this.statusFilter});

  @override
  List<Object?> get props => [query, statusFilter];
}

class SaveQuoteEvent extends QuotesEvent {
  final Quote quote;

  const SaveQuoteEvent(this.quote);

  @override
  List<Object?> get props => [quote];
}

class DeleteQuoteEvent extends QuotesEvent {
  final String id;

  const DeleteQuoteEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateQuoteStatusEvent extends QuotesEvent {
  final String id;
  final QuoteStatus newStatus;

  const UpdateQuoteStatusEvent(this.id, this.newStatus);

  @override
  List<Object?> get props => [id, newStatus];
}
