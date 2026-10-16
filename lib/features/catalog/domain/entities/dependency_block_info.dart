import 'package:equatable/equatable.dart';

/// Represents protective dependency blocking details when a user attempts
/// to delete an ingredient or packaging item that is actively referenced by
/// one or more recipes (`RF-SYS-21`, `RF-SYS-22`, `BR-INT-01`, `BR-INT-02`).
class DependencyBlockInfo extends Equatable {
  /// Unique ID of the ingredient or packaging item whose deletion was blocked.
  final String itemId;

  /// Human-readable name of the ingredient or packaging item.
  final String itemName;

  /// Whether the item is a packaging/disposable (`true`) or an ingredient (`false`).
  final bool isPackaging;

  /// List of recipe names that actively reference this item.
  final List<String> affectedRecipeNames;

  const DependencyBlockInfo({
    required this.itemId,
    required this.itemName,
    required this.isPackaging,
    required this.affectedRecipeNames,
  });

  /// Total count of recipes referencing this item.
  int get affectedCount => affectedRecipeNames.length;

  /// Formatted blocking message adhering to `BR-INT-02`:
  /// e.g. "No se puede eliminar 'Mantequilla Gloria'. Está en uso en 3 recetas: [Pastel de Zanahoria, Torta Red Velvet, Ganache de Chocolate]"
  String get formattedBlockMessage {
    final recipeWord = affectedCount == 1 ? 'receta' : 'recetas';
    return "No se puede eliminar '$itemName'. Está en uso en $affectedCount $recipeWord: [${affectedRecipeNames.join(', ')}]";
  }

  /// Header summary without the bracketed list for structured UI cards.
  String get headerSummary {
    final recipeWord = affectedCount == 1 ? 'receta' : 'recetas';
    return "No se puede eliminar '$itemName'. Está en uso en $affectedCount $recipeWord:";
  }

  @override
  List<Object?> get props => [
        itemId,
        itemName,
        isPackaging,
        affectedRecipeNames,
      ];
}
