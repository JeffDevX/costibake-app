import '../entities/quote.dart';

abstract class QuoteRepository {
  Future<List<Quote>> getAllQuotes();
  Future<Quote?> getQuoteById(String id);
  Future<void> saveQuote(Quote quote);
  Future<void> deleteQuote(String id);
  Future<void> updateQuoteStatus(String id, QuoteStatus newStatus);
  Future<List<Quote>> searchQuotes(String query, {QuoteStatus? status});
}
