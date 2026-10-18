import 'package:equatable/equatable.dart';
import 'package:costibake_app/core/utils/precise_decimal.dart';
import 'quote_item.dart';

enum QuoteStatus {
  pending('PENDIENTE', 'Pendiente'),
  confirmed('CONFIRMADA', 'Confirmada'),
  delivered('ENTREGADA', 'Entregada'),
  cancelled('CANCELADA', 'Cancelada');

  final String code;
  final String label;
  const QuoteStatus(this.code, this.label);

  static QuoteStatus fromCode(String code) {
    return QuoteStatus.values.firstWhere(
      (e) => e.code.toUpperCase() == code.toUpperCase(),
      orElse: () => QuoteStatus.pending,
    );
  }
}

class Quote extends Equatable {
  final String id;
  final String clientName;
  final String? clientPhone;
  final String? eventNotes;
  final DateTime deliveryDate;
  final PreciseDecimal discount;
  final PreciseDecimal depositAmount;
  final QuoteStatus status;
  final List<QuoteItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Quote({
    required this.id,
    required this.clientName,
    this.clientPhone,
    this.eventNotes,
    required this.deliveryDate,
    required this.discount,
    required this.depositAmount,
    this.status = QuoteStatus.pending,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  PreciseDecimal get subtotal => items.fold(
        PreciseDecimal.zero,
        (sum, item) => sum + item.total,
      );

  PreciseDecimal get totalAmount {
    final sub = subtotal;
    if (discount >= sub) return PreciseDecimal.zero;
    return sub - discount;
  }

  PreciseDecimal get remainingBalance {
    final total = totalAmount;
    if (depositAmount >= total) return PreciseDecimal.zero;
    return total - depositAmount;
  }

  bool get isFullyPaid => depositAmount >= totalAmount && totalAmount > PreciseDecimal.zero;

  Quote copyWith({
    String? id,
    String? clientName,
    String? clientPhone,
    String? eventNotes,
    DateTime? deliveryDate,
    PreciseDecimal? discount,
    PreciseDecimal? depositAmount,
    QuoteStatus? status,
    List<QuoteItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Quote(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      eventNotes: eventNotes ?? this.eventNotes,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      discount: discount ?? this.discount,
      depositAmount: depositAmount ?? this.depositAmount,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_nombre': clientName,
      'cliente_telefono': clientPhone,
      'evento_notas': eventNotes,
      'fecha_entrega': deliveryDate.toIso8601String(),
      'total_descuento': discount.toString(),
      'monto_anticipo': depositAmount.toString(),
      'estado': status.code,
      'fecha_creacion': createdAt.toIso8601String(),
      'fecha_actualizacion': updatedAt.toIso8601String(),
    };
  }

  factory Quote.fromMap(Map<String, dynamic> map, {List<QuoteItem> items = const []}) {
    return Quote(
      id: map['id'] as String,
      clientName: map['cliente_nombre'] as String,
      clientPhone: map['cliente_telefono'] as String?,
      eventNotes: map['evento_notas'] as String?,
      deliveryDate: DateTime.parse(map['fecha_entrega'] as String),
      discount: PreciseDecimal.fromString(map['total_descuento'] as String? ?? '0.00'),
      depositAmount: PreciseDecimal.fromString(map['monto_anticipo'] as String? ?? '0.00'),
      status: QuoteStatus.fromCode(map['estado'] as String? ?? 'PENDIENTE'),
      items: items,
      createdAt: DateTime.parse(map['fecha_creacion'] as String),
      updatedAt: DateTime.parse(map['fecha_actualizacion'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        clientName,
        clientPhone,
        eventNotes,
        deliveryDate,
        discount,
        depositAmount,
        status,
        items,
        createdAt,
        updatedAt,
      ];
}
