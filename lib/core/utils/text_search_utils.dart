/// Utility class providing diacritics-insensitive and case-insensitive
/// search matching and normalization for bakery ingredients and packagings.
class TextSearchUtils {
  TextSearchUtils._();

  static const Map<String, String> _diacriticsMap = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n',
    'Á': 'a', 'À': 'a', 'Ä': 'a', 'Â': 'a', 'Ã': 'a',
    'É': 'e', 'È': 'e', 'Ë': 'e', 'Ê': 'e',
    'Í': 'i', 'Ì': 'i', 'Ï': 'i', 'Î': 'i',
    'Ó': 'o', 'Ò': 'o', 'Ö': 'o', 'Ô': 'o', 'Õ': 'o',
    'Ú': 'u', 'Ù': 'u', 'Ü': 'u', 'Û': 'u',
    'Ñ': 'n',
  };

  /// Normalizes a string by converting it to lowercase and removing Spanish
  /// diacritics / tildes (e.g. 'Azúcar' -> 'azucar').
  static String normalize(String input) {
    if (input.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      buffer.write(_diacriticsMap[char] ?? char.toLowerCase());
    }
    return buffer.toString().trim();
  }

  /// Returns true if [target] contains [query] ignoring case and diacritics/accents.
  static bool containsNormalized(String target, String query) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return true;
    final normalizedTarget = normalize(target);
    return normalizedTarget.contains(normalizedQuery);
  }
}
