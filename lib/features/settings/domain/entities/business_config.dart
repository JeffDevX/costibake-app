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
