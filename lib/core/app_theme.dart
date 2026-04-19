import 'package:flutter/material.dart';

/// KuaFlex Design System
/// 4px grid spacing, consistent color tokens, reusable styles

// ─── Color Tokens ─────────────────────────────────────────────
/// Static brand & semantic colors — never change between themes.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFC69749);
  static const Color primaryLight = Color(0xFFE0B878);
  static const Color primaryDark = Color(0xFFA07830);

  // Surfaces
  static const Color bg = Color(0xFF0F0F0F);
  static const Color surface = Color(0xFF181818);
  static const Color surfaceLight = Color(0xFF222222);
  static const Color surfaceBorder = Color(0xFF2A2A2A);

  // Text
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textTertiary = Color(0xFF616161);
  static const Color textHint = Color(0xFF4A4A4A);

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color successSoft = Color(0xFF1B3A1B);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningSoft = Color(0xFF3A2E10);
  static const Color error = Color(0xFFEF5350);
  static const Color errorSoft = Color(0xFF3A1515);
  static const Color info = Color(0xFF7C8BFF);
  static const Color infoSoft = Color(0xFF1A1A30);

  static const Color primarySoft = Color(0xFF2A2000);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Dynamic Color Tokens (theme-aware) ──────────────────────
/// Surface / text / background colors that switch between themes.
/// Access via the [BuildContext.ct] extension:  `context.ct.bg`
class DynamicColors extends ThemeExtension<DynamicColors> {
  final Color bg;
  final Color surface;
  final Color surfaceLight;
  final Color surfaceBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textHint;
  final Color successSoft;
  final Color warningSoft;
  final Color errorSoft;
  final Color infoSoft;
  final Color primarySoft;

  const DynamicColors({
    required this.bg,
    required this.surface,
    required this.surfaceLight,
    required this.surfaceBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textHint,
    required this.successSoft,
    required this.warningSoft,
    required this.errorSoft,
    required this.infoSoft,
    required this.primarySoft,
  });

  // ── Dark palette ─────────────────────────────────────────────
  static const dark = DynamicColors(
    bg:            AppColors.bg,
    surface:       AppColors.surface,
    surfaceLight:  AppColors.surfaceLight,
    surfaceBorder: AppColors.surfaceBorder,
    textPrimary:   AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary:  AppColors.textTertiary,
    textHint:      AppColors.textHint,
    successSoft:   AppColors.successSoft,
    warningSoft:   AppColors.warningSoft,
    errorSoft:     AppColors.errorSoft,
    infoSoft:      AppColors.infoSoft,
    primarySoft:   AppColors.primarySoft,
  );

  // ── Light palette (warm cream × gold accents) ─────────────
  static const light = DynamicColors(
    bg:            Color(0xFFF5F0E8), // warm cream
    surface:       Color(0xFFFFFFFF), // clean white
    surfaceLight:  Color(0xFFEDE8DF), // warm off-white
    surfaceBorder: Color(0xFFE2D9CC), // warm light border
    textPrimary:   Color(0xFF1C1008), // deep warm charcoal
    textSecondary: Color(0xFF6B5D50), // medium warm brown
    textTertiary:  Color(0xFF9C8B7E), // muted warm
    textHint:      Color(0xFFBFB0A4), // hint warm
    successSoft:   Color(0xFFEBF8EC), // soft green
    warningSoft:   Color(0xFFFFF8E1), // soft amber
    errorSoft:     Color(0xFFFFF0F0), // soft red
    infoSoft:      Color(0xFFEEEFFF), // soft indigo-blue
    primarySoft:   Color(0xFFFFF8EE), // soft gold
  );

  @override
  DynamicColors copyWith({
    Color? bg, Color? surface, Color? surfaceLight, Color? surfaceBorder,
    Color? textPrimary, Color? textSecondary, Color? textTertiary, Color? textHint,
    Color? successSoft, Color? warningSoft, Color? errorSoft,
    Color? infoSoft, Color? primarySoft,
  }) => DynamicColors(
    bg:            bg            ?? this.bg,
    surface:       surface       ?? this.surface,
    surfaceLight:  surfaceLight  ?? this.surfaceLight,
    surfaceBorder: surfaceBorder ?? this.surfaceBorder,
    textPrimary:   textPrimary   ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary:  textTertiary  ?? this.textTertiary,
    textHint:      textHint      ?? this.textHint,
    successSoft:   successSoft   ?? this.successSoft,
    warningSoft:   warningSoft   ?? this.warningSoft,
    errorSoft:     errorSoft     ?? this.errorSoft,
    infoSoft:      infoSoft      ?? this.infoSoft,
    primarySoft:   primarySoft   ?? this.primarySoft,
  );

  @override
  DynamicColors lerp(DynamicColors? other, double t) {
    if (other is! DynamicColors) return this;
    return DynamicColors(
      bg:            Color.lerp(bg,            other.bg,            t)!,
      surface:       Color.lerp(surface,       other.surface,       t)!,
      surfaceLight:  Color.lerp(surfaceLight,  other.surfaceLight,  t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary:  Color.lerp(textTertiary,  other.textTertiary,  t)!,
      textHint:      Color.lerp(textHint,      other.textHint,      t)!,
      successSoft:   Color.lerp(successSoft,   other.successSoft,   t)!,
      warningSoft:   Color.lerp(warningSoft,   other.warningSoft,   t)!,
      errorSoft:     Color.lerp(errorSoft,     other.errorSoft,     t)!,
      infoSoft:      Color.lerp(infoSoft,      other.infoSoft,      t)!,
      primarySoft:   Color.lerp(primarySoft,   other.primarySoft,   t)!,
    );
  }
}

/// Convenience extension — use `context.ct.bg`, `context.ct.surface`, etc.
extension AppThemeX on BuildContext {
  DynamicColors get ct => Theme.of(this).extension<DynamicColors>()!;
}

// ─── Spacing (4px Grid) ───────────────────────────────────────
class Spacing {
  Spacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 48;
}

// ─── Border Radius ────────────────────────────────────────────
class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 100;
}

// ─── Theme Data ───────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: Colors.white,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5, height: 1.2),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3, height: 1.3),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.3),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.4),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textTertiary, height: 1.4),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiary, letterSpacing: 0.5),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      iconTheme: IconThemeData(color: AppColors.textSecondary, size: 22),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        disabledBackgroundColor: AppColors.primary.withAlpha(80),
        disabledForegroundColor: Colors.white.withAlpha(120),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.surfaceBorder),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.lg + 2),
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 15),
      labelStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
      prefixIconColor: AppColors.textTertiary,
      suffixIconColor: AppColors.textTertiary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: AppColors.surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: AppColors.surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: AppColors.surfaceBorder.withAlpha(80)),
      ),
      margin: EdgeInsets.zero,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      contentTextStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: AppColors.textTertiary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      disabledColor: AppColors.surface,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      side: BorderSide(color: AppColors.surfaceBorder),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.surfaceBorder.withAlpha(100),
      thickness: 1,
      space: 1,
    ),
    extensions: const [DynamicColors.dark],
  );
}

// ─── Light Theme (sıcak krem / altın aksanlı) ─────────────────
ThemeData buildLightAppTheme() {
  const Color bg = Color(0xFFF5F0E8);
  const Color surface = Colors.white;
  const Color surfaceLight = Color(0xFFF0EBE3);
  const Color border = Color(0xFFE0D8CC);
  const Color textPrimary = Color(0xFF1A1A1A);
  const Color textSecondary = Color(0xFF555555);
  const Color textTertiary = Color(0xFF888888);
  const Color textHint = Color(0xFFBBB0A0);

  return ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      error: AppColors.error,
      onError: Colors.white,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5, height: 1.2),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3, height: 1.3),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary, height: 1.3),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary, height: 1.4),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary, height: 1.4),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textTertiary, height: 1.4),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textTertiary, letterSpacing: 0.5),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
      iconTheme: IconThemeData(color: textSecondary, size: 22),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        disabledBackgroundColor: AppColors.primary.withAlpha(80),
        disabledForegroundColor: Colors.white.withAlpha(120),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: const BorderSide(color: border),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.lg + 2),
      hintStyle: const TextStyle(color: textHint, fontSize: 15),
      labelStyle: const TextStyle(color: textTertiary, fontSize: 14),
      prefixIconColor: textTertiary,
      suffixIconColor: textTertiary,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: AppColors.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl), side: const BorderSide(color: border)),
      margin: EdgeInsets.zero,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceLight,
      contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.xxl))),
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
      contentTextStyle: TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    extensions: const [DynamicColors.light],
  );
}

