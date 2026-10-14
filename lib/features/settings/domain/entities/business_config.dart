import 'package:equatable/equatable.dart';
import '../../../../core/utils/precise_decimal.dart';

class BusinessConfig extends Equatable {
  final String id;
  final String businessName;
  final String currencySymbol;
  final PreciseDecimal laborHourlyRate;
  final PreciseDecimal overheadPercentage;
  final DateTime updatedAt;

  const BusinessConfig({
    required this.id,
    required this.businessName,
    required this.currencySymbol,
    required this.laborHourlyRate,
    required this.overheadPercentage,
    required this.updatedAt,
  });

  BusinessConfig copyWith({
    String? id,
    String? businessName,
    String? currencySymbol,
    PreciseDecimal? laborHourlyRate,
    PreciseDecimal? overheadPercentage,
    DateTime? updatedAt,
  }) {
    return BusinessConfig(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      laborHourlyRate: laborHourlyRate ?? this.laborHourlyRate,
      overheadPercentage: overheadPercentage ?? this.overheadPercentage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        businessName,
        currencySymbol,
        laborHourlyRate,
        overheadPercentage,
        updatedAt,
      ];
}
