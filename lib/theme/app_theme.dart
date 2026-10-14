import 'package:flutter/material.dart';

// 앱 전체에서 쓰는 색 모음. 브랜드 색은 대구대학교 색상규정(전용색상)을 따른다.
class AppColors {
  // 대구대 전용색상 (화면용 RGB 근사값)
  static const deepGreen = Color(0xFF00816D); // DU DEEP GREEN · PANTONE 569C
  static const green = Color(0xFF6CBE45); // DU GREEN · PANTONE 361C
  static const lightGreen = Color(0xFFDCD31F); // DU LIGHTGREEN · PANTONE 3956C
  static const black = Color(0xFF231F20); // DU BLACK · PANTONE Black C

  // Backgrounds
  static const bgLight = Color(0xFFF4F7F5);
  static const bgDark = Color(0xFF0B1110);

  // Surfaces / Cards
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF141B19);
  static const elevatedDark = Color(0xFF1B2421);

  // Borders
  static const borderLight = Color(0xFFE3EAE6);
  static const borderDark = Color(0xFF24302C);

  // Text
  static const textLight = black;
  static const textDark = Color(0xFFF1F5F3);
  static const subLight = Color(0xFF6B7280);
  static const subDark = Color(0xFF9CA3AF);

  // Status
  static const danger = Color(0xFFEF4444);
  static const success = deepGreen;

  /// 브랜드 그라데이션: DU DEEP GREEN → DU GREEN
  static const LinearGradient brandGradient = LinearGradient(
    colors: [deepGreen, green],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// 아이콘 상자 등 정사각형에 쓰는 대각선 그라데이션
  static const LinearGradient brandGradientDiagonal = LinearGradient(
    colors: [deepGreen, green],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color text(BuildContext context) =>
      isDark(context) ? textDark : textLight;
  static Color sub(BuildContext context) =>
      isDark(context) ? subDark : subLight;
  static Color surface(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;
  static Color border(BuildContext context) =>
      isDark(context) ? borderDark : borderLight;

  /// 강조 글자색. 다크 모드에서는 DEEP GREEN 이 어두워 DU GREEN 을 쓴다.
  static Color accent(BuildContext context) =>
      isDark(context) ? green : deepGreen;
}

/// 라이트/다크 공통 테마. 색은 [AppColors]에서 가져온다.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final cs =
      ColorScheme.fromSeed(
        seedColor: AppColors.deepGreen,
        brightness: brightness,
      ).copyWith(
        primary: isDark ? AppColors.green : AppColors.deepGreen,
        onPrimary: Colors.white,
        secondary: AppColors.green,
        tertiary: AppColors.lightGreen,
        onTertiary: AppColors.black,
        surface: isDark ? AppColors.bgDark : AppColors.bgLight,
        surfaceContainerLowest: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        onSurface: isDark ? AppColors.textDark : AppColors.textLight,
        onSurfaceVariant: isDark ? AppColors.subDark : AppColors.subLight,
        outlineVariant: isDark ? AppColors.borderDark : AppColors.borderLight,
        primaryContainer: isDark
            ? const Color(0xFF0E3A32)
            : const Color(0xFFE2F2EE),
        onPrimaryContainer: isDark ? AppColors.green : AppColors.deepGreen,
        error: AppColors.danger,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: cs,
    scaffoldBackgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      foregroundColor: cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: cs.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: cs.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
    ),
    dividerColor: cs.outlineVariant,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.deepGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: cs.onSurfaceVariant),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
