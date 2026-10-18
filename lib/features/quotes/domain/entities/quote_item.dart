import 'package:equatable/equatable.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';

enum QuoteItemType {
  recipe('RECETA'),
  custom('PERSONALIZADO');

  final String code;
  const QuoteItemType(this.code);

  static QuoteItemType fromCode(String code) {
    return QuoteItemType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => QuoteItemType.custom,
    );
  }
}

class QuoteItem extends Equatable {
  final String id;
  final String quoteId;
  final String? recipeId;
  final String concept;
  final QuoteItemType type;
  final PreciseDecimal quantity;
  final PreciseDecimal unitPrice;
  final String? notes;

  const QuoteItem({
    required this.id,
    required this.quoteId,
    this.recipeId,
    required this.concept,
    this.type = QuoteItemType.recipe,
    required this.quantity,
    required this.unitPrice,
    this.notes,
  });

  PreciseDecimal get total => quantity * unitPrice;

  QuoteItem copyWith({
    String? id,
    String? quoteId,
    String? recipeId,
    String? concept,
    QuoteItemType? type,
    PreciseDecimal? quantity,
    PreciseDecimal? unitPrice,
    String? notes,
  }) {
    return QuoteItem(
      id: id ?? this.id,
      quoteId: quoteId ?? this.quoteId,
      recipeId: recipeId ?? this.recipeId,
      concept: concept ?? this.concept,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cotizacion_id': quoteId,
      'receta_id': recipeId,
      'concepto': concept,
      'tipo': type.code,
      'cantidad': quantity.toString(),
      'precio_unitario': unitPrice.toString(),
      'notas': notes,
    };
  }

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      id: map['id'] as String,
      quoteId: map['cotizacion_id'] as String,
      recipeId: map['receta_id'] as String?,
      concept: map['concepto'] as String,
      type: QuoteItemType.fromCode(map['tipo'] as String? ?? 'RECETA'),
      quantity: PreciseDecimal.fromString(map['cantidad'] as String? ?? '1.00'),
      unitPrice: PreciseDecimal.fromString(map['precio_unitario'] as String? ?? '0.00'),
      notes: map['notas'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        quoteId,
        recipeId,
        concept,
        type,
        quantity,
        unitPrice,
        notes,
      ];
}
