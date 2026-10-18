import 'package:equatable/equatable.dart';
import '../../../../core/constants/culinary_units.dart';
import '../../../../core/utils/precise_decimal.dart';

/// Represents a single ingredient extracted from a recipe by AI vision/document analysis.
class AiExtractedIngredient extends Equatable {
  final String name;
  final PreciseDecimal quantity;
  final String unit;
  final String section;
  final String? notes;
  final String? rawText;

  // Reconciliation state (used in JEF-29 guided wizard)
  final String? matchedCatalogIngredientId;
  final String? matchedCatalogIngredientName;
  final bool isNewIngredient;
  final PreciseDecimal? purchasePrice;
  final PreciseDecimal? commercialPackageQuantity;
  final String? commercialPackageUnit;
  final PreciseDecimal? wastePercentage;
  final PreciseDecimal? densityGPerMl;
  final PreciseDecimal? gramsPerCup;

  const AiExtractedIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.section = 'Base',
    this.notes,
    this.rawText,
    this.matchedCatalogIngredientId,
    this.matchedCatalogIngredientName,
    this.isNewIngredient = false,
    this.purchasePrice,
    this.commercialPackageQuantity,
    this.commercialPackageUnit,
    this.wastePercentage,
    this.densityGPerMl,
    this.gramsPerCup,
  });

  /// Normalizes the unit string using [CulinaryUnit.tryParse] if possible,
  /// falling back to lowercased trimmed string.
  String get normalizedUnit {
    final parsed = CulinaryUnit.tryParse(unit);
    return parsed != null ? parsed.symbol : unit.trim().toLowerCase();
  }

  /// True if this ingredient has been mapped to an existing catalog item or newly created.
  bool get isResolved =>
      matchedCatalogIngredientId != null ||
      (isNewIngredient &&
          purchasePrice != null &&
          purchasePrice! > PreciseDecimal.zero &&
          commercialPackageQuantity != null &&
          commercialPackageQuantity! > PreciseDecimal.zero);

  AiExtractedIngredient copyWith({
    String? name,
    PreciseDecimal? quantity,
    String? unit,
    String? section,
    String? notes,
    String? rawText,
    String? matchedCatalogIngredientId,
    String? matchedCatalogIngredientName,
    bool? isNewIngredient,
    PreciseDecimal? purchasePrice,
    PreciseDecimal? commercialPackageQuantity,
    String? commercialPackageUnit,
    PreciseDecimal? wastePercentage,
    PreciseDecimal? densityGPerMl,
    PreciseDecimal? gramsPerCup,
  }) {
    return AiExtractedIngredient(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      section: section ?? this.section,
      notes: notes ?? this.notes,
      rawText: rawText ?? this.rawText,
      matchedCatalogIngredientId:
          matchedCatalogIngredientId ?? this.matchedCatalogIngredientId,
      matchedCatalogIngredientName:
          matchedCatalogIngredientName ?? this.matchedCatalogIngredientName,
      isNewIngredient: isNewIngredient ?? this.isNewIngredient,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      commercialPackageQuantity:
          commercialPackageQuantity ?? this.commercialPackageQuantity,
      commercialPackageUnit:
          commercialPackageUnit ?? this.commercialPackageUnit,
      wastePercentage: wastePercentage ?? this.wastePercentage,
      densityGPerMl: densityGPerMl ?? this.densityGPerMl,
      gramsPerCup: gramsPerCup ?? this.gramsPerCup,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity.toString(),
      'unit': unit,
      'section': section,
      'notes': notes,
      'rawText': rawText,
      'matchedCatalogIngredientId': matchedCatalogIngredientId,
      'matchedCatalogIngredientName': matchedCatalogIngredientName,
      'isNewIngredient': isNewIngredient,
      'purchasePrice': purchasePrice?.toString(),
      'commercialPackageQuantity': commercialPackageQuantity?.toString(),
      'commercialPackageUnit': commercialPackageUnit,
      'wastePercentage': wastePercentage?.toString(),
      'densityGPerMl': densityGPerMl?.toString(),
      'gramsPerCup': gramsPerCup?.toString(),
    };
  }

  factory AiExtractedIngredient.fromJson(Map<String, dynamic> json) {
    return AiExtractedIngredient(
      name: json['name'] as String? ?? '',
      quantity: PreciseDecimal.tryParse(json['quantity']?.toString() ?? '1') ??
          PreciseDecimal.one,
      unit: json['unit'] as String? ?? 'g',
      section: json['section'] as String? ?? 'Base',
      notes: json['notes'] as String?,
      rawText: json['rawText'] as String?,
      matchedCatalogIngredientId:
          json['matchedCatalogIngredientId'] as String?,
      matchedCatalogIngredientName:
          json['matchedCatalogIngredientName'] as String?,
      isNewIngredient: json['isNewIngredient'] as bool? ?? false,
      purchasePrice: json['purchasePrice'] != null
          ? PreciseDecimal.tryParse(json['purchasePrice'].toString())
          : null,
      commercialPackageQuantity: json['commercialPackageQuantity'] != null
          ? PreciseDecimal.tryParse(
              json['commercialPackageQuantity'].toString())
          : null,
      commercialPackageUnit: json['commercialPackageUnit'] as String?,
      wastePercentage: json['wastePercentage'] != null
          ? PreciseDecimal.tryParse(json['wastePercentage'].toString())
          : null,
      densityGPerMl: json['densityGPerMl'] != null
          ? PreciseDecimal.tryParse(json['densityGPerMl'].toString())
          : null,
      gramsPerCup: json['gramsPerCup'] != null
          ? PreciseDecimal.tryParse(json['gramsPerCup'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [
        name,
        quantity,
        unit,
        section,
        notes,
        rawText,
        matchedCatalogIngredientId,
        matchedCatalogIngredientName,
        isNewIngredient,
        purchasePrice,
        commercialPackageQuantity,
        commercialPackageUnit,
        wastePercentage,
        densityGPerMl,
        gramsPerCup,
      ];
}

/// Represents the complete structured data of a recipe extracted by AI vision/multimodal analysis.
class AiRecipeExtraction extends Equatable {
  final String title;
  final String? description;
  final int yieldPortions;
  final int prepTimeMinutes;
  final int bakeTimeMinutes;
  final String? moldType;
  final String? moldDimension;
  final List<AiExtractedIngredient> ingredients;
  final List<String> steps;
  final String? notes;
  final String? rawResponse;

  const AiRecipeExtraction({
    required this.title,
    this.description,
    this.yieldPortions = 1,
    this.prepTimeMinutes = 0,
    this.bakeTimeMinutes = 0,
    this.moldType,
    this.moldDimension,
    this.ingredients = const [],
    this.steps = const [],
    this.notes,
    this.rawResponse,
  });

  /// Number of ingredients that have not been reconciled with the catalog.
  int get unresolvedIngredientsCount =>
      ingredients.where((i) => !i.isResolved).length;

  /// True when all extracted ingredients have been matched to catalog items or newly registered.
  bool get isFullyResolved => unresolvedIngredientsCount == 0;

  AiRecipeExtraction copyWith({
    String? title,
    String? description,
    int? yieldPortions,
    int? prepTimeMinutes,
    int? bakeTimeMinutes,
    String? moldType,
    String? moldDimension,
    List<AiExtractedIngredient>? ingredients,
    List<String>? steps,
    String? notes,
    String? rawResponse,
  }) {
    return AiRecipeExtraction(
      title: title ?? this.title,
      description: description ?? this.description,
      yieldPortions: yieldPortions ?? this.yieldPortions,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      bakeTimeMinutes: bakeTimeMinutes ?? this.bakeTimeMinutes,
      moldType: moldType ?? this.moldType,
      moldDimension: moldDimension ?? this.moldDimension,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      notes: notes ?? this.notes,
      rawResponse: rawResponse ?? this.rawResponse,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'yieldPortions': yieldPortions,
      'prepTimeMinutes': prepTimeMinutes,
      'bakeTimeMinutes': bakeTimeMinutes,
      'moldType': moldType,
      'moldDimension': moldDimension,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'steps': steps,
      'notes': notes,
      'rawResponse': rawResponse,
    };
  }

  factory AiRecipeExtraction.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'] as List<dynamic>? ?? [];
    final rawSteps = json['steps'] as List<dynamic>? ?? [];

    return AiRecipeExtraction(
      title: json['title'] as String? ?? 'Receta Extraída',
      description: json['description'] as String?,
      yieldPortions: (json['yieldPortions'] as num?)?.toInt() ?? 1,
      prepTimeMinutes: (json['prepTimeMinutes'] as num?)?.toInt() ?? 0,
      bakeTimeMinutes: (json['bakeTimeMinutes'] as num?)?.toInt() ?? 0,
      moldType: json['moldType'] as String?,
      moldDimension: json['moldDimension'] as String?,
      ingredients: rawIngredients
          .whereType<Map<String, dynamic>>()
          .map((i) => AiExtractedIngredient.fromJson(i))
          .toList(),
      steps: rawSteps.map((s) => s.toString()).toList(),
      notes: json['notes'] as String?,
      rawResponse: json['rawResponse'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        title,
        description,
        yieldPortions,
        prepTimeMinutes,
        bakeTimeMinutes,
        moldType,
        moldDimension,
        ingredients,
        steps,
        notes,
        rawResponse,
      ];
}
