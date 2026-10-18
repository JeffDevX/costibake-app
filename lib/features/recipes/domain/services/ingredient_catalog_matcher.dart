import 'dart:math';
import '../../../catalog/domain/entities/ingredient.dart';
import '../entities/ai_recipe_extraction.dart';

/// Represents an ingredient from the catalog along with its calculated similarity score.
class ScoredIngredient {
  final Ingredient ingredient;
  final double score; // 0.0 to 1.0

  const ScoredIngredient({
    required this.ingredient,
    required this.score,
  });
}

/// Result of matching an extracted ingredient name against the catalog.
class IngredientMatchResult {
  final Ingredient? exactMatch;
  final List<ScoredIngredient> suggestions;

  const IngredientMatchResult({
    this.exactMatch,
    this.suggestions = const [],
  });

  bool get hasExactMatch => exactMatch != null;
  Ingredient? get bestSuggestion =>
      suggestions.isNotEmpty ? suggestions.first.ingredient : null;
}

/// Domain service that reconciles AI-extracted ingredient names against the local catalog.
/// Implements BR-IA-05, BR-IA-06, BR-IA-07.
class IngredientCatalogMatcher {
  static const double exactMatchThreshold = 0.95;
  static const double suggestionThreshold = 0.25;

  /// Matches a single extracted ingredient name against the local catalog.
  static IngredientMatchResult match({
    required String extractedName,
    required List<Ingredient> catalog,
  }) {
    final normalizedQuery = normalize(extractedName);
    if (normalizedQuery.isEmpty || catalog.isEmpty) {
      return const IngredientMatchResult();
    }

    Ingredient? exact;
    final scoredList = <ScoredIngredient>[];

    for (final ingredient in catalog) {
      final normalizedTarget = normalize(ingredient.name);
      final score = calculateSimilarity(normalizedQuery, normalizedTarget);

      if (score >= exactMatchThreshold && exact == null) {
        exact = ingredient;
      }

      if (score >= suggestionThreshold) {
        scoredList.add(
          ScoredIngredient(
            ingredient: ingredient,
            score: score,
          ),
        );
      }
    }

    // Sort descending by similarity score
    scoredList.sort((a, b) => b.score.compareTo(a.score));

    return IngredientMatchResult(
      exactMatch: exact,
      suggestions: scoredList,
    );
  }

  /// Automatically matches all extracted ingredients in an [AiRecipeExtraction] against the catalog.
  /// Any ingredient with an exact match is marked with its catalog ID and name.
  static AiRecipeExtraction matchExtraction({
    required AiRecipeExtraction extraction,
    required List<Ingredient> catalog,
  }) {
    final updatedIngredients = <AiExtractedIngredient>[];

    for (final item in extraction.ingredients) {
      // If already resolved, keep as is
      if (item.matchedCatalogIngredientId != null) {
        updatedIngredients.add(item);
        continue;
      }

      final matchResult = match(
        extractedName: item.name,
        catalog: catalog,
      );

      if (matchResult.hasExactMatch) {
        final matched = matchResult.exactMatch!;
        updatedIngredients.add(
          item.copyWith(
            matchedCatalogIngredientId: matched.id,
            matchedCatalogIngredientName: matched.name,
            isNewIngredient: false,
          ),
        );
      } else {
        // Unresolved: will require guided wizard resolution
        updatedIngredients.add(item);
      }
    }

    return extraction.copyWith(ingredients: updatedIngredients);
  }

  /// Normalizes a string by converting to lowercase, stripping diacritics/accents,
  /// and removing punctuation.
  static String normalize(String text) {
    var result = text.toLowerCase().trim();

    const diacritics = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
      'à': 'a',
      'è': 'e',
      'ì': 'i',
      'ò': 'o',
      'ù': 'u',
    };

    diacritics.forEach((accented, plain) {
      result = result.replaceAll(accented, plain);
    });

    // Replace non-alphanumeric characters with spaces
    result = result.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    // Collapse multi-spaces
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Calculates a hybrid similarity score (0.0 to 1.0) combining:
  /// 1. Exact string match
  /// 2. Substring containment
  /// 3. Token Jaccard overlap
  /// 4. Levenshtein edit distance
  static double calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Substring containment check
    if (s1.contains(s2) || s2.contains(s1)) {
      final minLen = min(s1.length, s2.length);
      final maxLen = max(s1.length, s2.length);
      final containmentScore = minLen / maxLen;
      // High weight for substring containment
      if (containmentScore > 0.6) {
        return max(0.85, containmentScore);
      }
    }

    // Token Jaccard similarity
    final tokens1 = s1.split(' ').where((t) => t.length > 1).toSet();
    final tokens2 = s2.split(' ').where((t) => t.length > 1).toSet();

    double jaccard = 0.0;
    if (tokens1.isNotEmpty && tokens2.isNotEmpty) {
      final intersection = tokens1.intersection(tokens2).length;
      final union = tokens1.union(tokens2).length;
      jaccard = union > 0 ? intersection / union : 0.0;
    }

    // Levenshtein distance ratio
    final distance = _levenshteinDistance(s1, s2);
    final maxLen = max(s1.length, s2.length);
    final levenshteinScore = maxLen > 0 ? 1.0 - (distance / maxLen) : 0.0;

    // Weighted blend: 60% token overlap + 40% Levenshtein
    final combined = (jaccard * 0.6) + (levenshteinScore * 0.4);
    return combined.clamp(0.0, 1.0);
  }

  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < v0.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(
          v1[j] + 1,
          min(v0[j + 1] + 1, v0[j] + cost),
        );
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[t.length];
  }
}
