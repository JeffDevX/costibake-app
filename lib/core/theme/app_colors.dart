import 'package:flutter/material.dart';

/// Available theme modes for the CostiBake Artisanal Confectionery experience.
enum BakeryThemeMode {
  /// Pastelería suave, crema de vainilla cálida, caramelo miel (Stitch Light).
  vainilla,

  /// Chocolate trufa, cacao tostado profundo, ámbar dorado (Stitch Dark).
  cacao,
}

/// Design tokens representing the 'Artisanal Confectionery Financial OS' palette (Modo Vainilla)
/// and the luxury dark 'Modo Cacao Noche' palette from Stitch.
class AppColors {
  // Brand Warmth & Heritage (Vainilla Base)
  static const Color primaryCaramel = Color(0xFFC06B3E);
  static const Color primaryDarkCaramel = Color(0xFF994D25);
  static const Color honeyAccent = Color(0xFFE89A3C);
  static const Color butterCream = Color(0xFFFFF9F0);
  static const Color pastryCrust = Color(0xFFD6A268);

  // Surface & Neutrals (Vainilla Base)
  static const Color surfaceWarm = Color(0xFFFAF7F2);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceHighlight = Color(0xFFF3ECE0);
  static const Color borderSubtle = Color(0xFFE6DEC8);
  static const Color borderWarm = Color(0xFFDFD4C5);

  // Text Hierarchies (Vainilla Base)
  static const Color textEspresso = Color(0xFF2C221E);
  static const Color textMuted = Color(0xFF6B5E57);
  static const Color textLight = Color(0xFF9E8E85);

  // Financial Semantics (Vainilla Base)
  static const Color profitGreen = Color(0xFF2E7D32);
  static const Color profitGreenLight = Color(0xFFE8F5E9);
  static const Color costRed = Color(0xFFC62828);
  static const Color costRedLight = Color(0xFFFFEBEE);
  static const Color warningAmber = Color(0xFFF57F17);
  static const Color warningAmberLight = Color(0xFFFFF8E1);
  static const Color infoBlue = Color(0xFF1565C0);
  static const Color infoBlueLight = Color(0xFFE3F2FD);

  // ==========================================
  // Cacao Theme Palette (Stitch Dark Mode)
  // ==========================================
  static const Color cacaoPrimaryCaramel = Color(0xFFF59E0B);
  static const Color cacaoPrimaryDarkCaramel = Color(0xFFFFC174);
  static const Color cacaoHoneyAccent = Color(0xFFFBBF24);
  static const Color cacaoButterCream = Color(0xFF241E1C);
  static const Color cacaoPastryCrust = Color(0xFF4A3B35);

  static const Color cacaoSurfaceWarm = Color(0xFF181210);
  static const Color cacaoSurfaceCard = Color(0xFF241E1C);
  static const Color cacaoSurfaceHighlight = Color(0xFF2F2926);
  static const Color cacaoBorderSubtle = Color(0xFF3A3331);
  static const Color cacaoBorderWarm = Color(0xFF4A3B35);

  static const Color cacaoTextEspresso = Color(0xFFECE0DC);
  static const Color cacaoTextMuted = Color(0xFFA08E7A);
  static const Color cacaoTextLight = Color(0xFF7D6E66);

  static const Color cacaoProfitGreen = Color(0xFF34D399);
  static const Color cacaoProfitGreenLight = Color(0x3310B981);
  static const Color cacaoCostRed = Color(0xFFF87171);
  static const Color cacaoCostRedLight = Color(0x33EF4444);
  static const Color cacaoWarningAmber = Color(0xFFFBBF24);
  static const Color cacaoWarningAmberLight = Color(0x33F59E0B);
}

/// Material 3 ThemeExtension for context-aware bakery styling.
@immutable
class BakeryColorsExtension extends ThemeExtension<BakeryColorsExtension> {
  final Color primaryCaramel;
  final Color primaryDarkCaramel;
  final Color honeyAccent;
  final Color butterCream;
  final Color surfaceWarm;
  final Color surfaceCard;
  final Color surfaceHighlight;
  final Color borderSubtle;
  final Color borderWarm;
  final Color textEspresso;
  final Color textMuted;
  final Color textLight;
  final Color profitGreen;
  final Color profitGreenLight;
  final Color costRed;
  final Color costRedLight;
  final Color warningAmber;
  final Color warningAmberLight;

  const BakeryColorsExtension({
    required this.primaryCaramel,
    required this.primaryDarkCaramel,
    required this.honeyAccent,
    required this.butterCream,
    required this.surfaceWarm,
    required this.surfaceCard,
    required this.surfaceHighlight,
    required this.borderSubtle,
    required this.borderWarm,
    required this.textEspresso,
    required this.textMuted,
    required this.textLight,
    required this.profitGreen,
    required this.profitGreenLight,
    required this.costRed,
    required this.costRedLight,
    required this.warningAmber,
    required this.warningAmberLight,
  });

  static const BakeryColorsExtension vainilla = BakeryColorsExtension(
    primaryCaramel: AppColors.primaryCaramel,
    primaryDarkCaramel: AppColors.primaryDarkCaramel,
    honeyAccent: AppColors.honeyAccent,
    butterCream: AppColors.butterCream,
    surfaceWarm: AppColors.surfaceWarm,
    surfaceCard: AppColors.surfaceCard,
    surfaceHighlight: AppColors.surfaceHighlight,
    borderSubtle: AppColors.borderSubtle,
    borderWarm: AppColors.borderWarm,
    textEspresso: AppColors.textEspresso,
    textMuted: AppColors.textMuted,
    textLight: AppColors.textLight,
    profitGreen: AppColors.profitGreen,
    profitGreenLight: AppColors.profitGreenLight,
    costRed: AppColors.costRed,
    costRedLight: AppColors.costRedLight,
    warningAmber: AppColors.warningAmber,
    warningAmberLight: AppColors.warningAmberLight,
  );

  static const BakeryColorsExtension cacao = BakeryColorsExtension(
    primaryCaramel: AppColors.cacaoPrimaryCaramel,
    primaryDarkCaramel: AppColors.cacaoPrimaryDarkCaramel,
    honeyAccent: AppColors.cacaoHoneyAccent,
    butterCream: AppColors.cacaoButterCream,
    surfaceWarm: AppColors.cacaoSurfaceWarm,
    surfaceCard: AppColors.cacaoSurfaceCard,
    surfaceHighlight: AppColors.cacaoSurfaceHighlight,
    borderSubtle: AppColors.cacaoBorderSubtle,
    borderWarm: AppColors.cacaoBorderWarm,
    textEspresso: AppColors.cacaoTextEspresso,
    textMuted: AppColors.cacaoTextMuted,
    textLight: AppColors.cacaoTextLight,
    profitGreen: AppColors.cacaoProfitGreen,
    profitGreenLight: AppColors.cacaoProfitGreenLight,
    costRed: AppColors.cacaoCostRed,
    costRedLight: AppColors.cacaoCostRedLight,
    warningAmber: AppColors.cacaoWarningAmber,
    warningAmberLight: AppColors.cacaoWarningAmberLight,
  );

  @override
  ThemeExtension<BakeryColorsExtension> copyWith({
    Color? primaryCaramel,
    Color? primaryDarkCaramel,
    Color? honeyAccent,
    Color? butterCream,
    Color? surfaceWarm,
    Color? surfaceCard,
    Color? surfaceHighlight,
    Color? borderSubtle,
    Color? borderWarm,
    Color? textEspresso,
    Color? textMuted,
    Color? textLight,
    Color? profitGreen,
    Color? profitGreenLight,
    Color? costRed,
    Color? costRedLight,
    Color? warningAmber,
    Color? warningAmberLight,
  }) {
    return BakeryColorsExtension(
      primaryCaramel: primaryCaramel ?? this.primaryCaramel,
      primaryDarkCaramel: primaryDarkCaramel ?? this.primaryDarkCaramel,
      honeyAccent: honeyAccent ?? this.honeyAccent,
      butterCream: butterCream ?? this.butterCream,
      surfaceWarm: surfaceWarm ?? this.surfaceWarm,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderWarm: borderWarm ?? this.borderWarm,
      textEspresso: textEspresso ?? this.textEspresso,
      textMuted: textMuted ?? this.textMuted,
      textLight: textLight ?? this.textLight,
      profitGreen: profitGreen ?? this.profitGreen,
      profitGreenLight: profitGreenLight ?? this.profitGreenLight,
      costRed: costRed ?? this.costRed,
      costRedLight: costRedLight ?? this.costRedLight,
      warningAmber: warningAmber ?? this.warningAmber,
      warningAmberLight: warningAmberLight ?? this.warningAmberLight,
    );
  }

  @override
  ThemeExtension<BakeryColorsExtension> lerp(
    covariant ThemeExtension<BakeryColorsExtension>? other,
    double t,
  ) {
    if (other is! BakeryColorsExtension) return this;
    return BakeryColorsExtension(
      primaryCaramel: Color.lerp(primaryCaramel, other.primaryCaramel, t)!,
      primaryDarkCaramel:
          Color.lerp(primaryDarkCaramel, other.primaryDarkCaramel, t)!,
      honeyAccent: Color.lerp(honeyAccent, other.honeyAccent, t)!,
      butterCream: Color.lerp(butterCream, other.butterCream, t)!,
      surfaceWarm: Color.lerp(surfaceWarm, other.surfaceWarm, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceHighlight:
          Color.lerp(surfaceHighlight, other.surfaceHighlight, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderWarm: Color.lerp(borderWarm, other.borderWarm, t)!,
      textEspresso: Color.lerp(textEspresso, other.textEspresso, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textLight: Color.lerp(textLight, other.textLight, t)!,
      profitGreen: Color.lerp(profitGreen, other.profitGreen, t)!,
      profitGreenLight:
          Color.lerp(profitGreenLight, other.profitGreenLight, t)!,
      costRed: Color.lerp(costRed, other.costRed, t)!,
      costRedLight: Color.lerp(costRedLight, other.costRedLight, t)!,
      warningAmber: Color.lerp(warningAmber, other.warningAmber, t)!,
      warningAmberLight:
          Color.lerp(warningAmberLight, other.warningAmberLight, t)!,
    );
  }
}

/// Convenience extension on BuildContext to access theme-aware bakery colors.
extension BakeryContextExtension on BuildContext {
  BakeryColorsExtension get bakeryColors =>
      Theme.of(this).extension<BakeryColorsExtension>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? BakeryColorsExtension.cacao
          : BakeryColorsExtension.vainilla);

  bool get isCacaoMode => Theme.of(this).brightness == Brightness.dark;
}
