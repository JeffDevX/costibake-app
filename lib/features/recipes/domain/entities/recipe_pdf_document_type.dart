/// Specifies the type of PDF document to generate for a recipe (JEF-26, RF-SYS-27).
enum RecipePdfDocumentType {
  /// Production sheet designed for kitchen staff / assistants.
  /// Displays quantities, mold, portions, and preparation instructions,
  /// but strictly hides all financial data, costs, overhead, labor rates, and selling prices (BR-EXP-02).
  productionSheet,

  /// Full financial technical sheet designed for the owner / pastry chef.
  /// Displays integral quadruple cost breakdown (ingredients, packaging, labor, overhead),
  /// profit margins, and suggested selling prices per batch and portion (BR-EXP-03).
  financialSheet,
}
