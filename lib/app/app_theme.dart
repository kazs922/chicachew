// lib/app/app_theme.dart
import 'package:flutter/material.dart';

/// 브랜드 시드 컬러: #BFEAD6
const Color kBrandSeed = Color(0xFFBFEAD6);

/// 라이트 테마(앱 기본)
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrandSeed,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: true,
    ),
    // ✅ CardTheme -> CardThemeData 로 교체
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      surfaceTintColor: Colors.transparent, // M3에서 강조 틴트 제거(선택)
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: scheme.surface,
      selectedItemColor: scheme.primary,
      unselectedItemColor: scheme.onSurfaceVariant,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: scheme.outlineVariant,
  );
}

/// (옵션) 다크 테마도 쓰고 싶을 때
ThemeData buildDarkAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrandSeed,
    brightness: Brightness.dark,
  );
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}

/// 테마색 명암 보정(“다른 색 필요하면 테마보다 살짝 어둡게”)
extension ColorShadeX on Color {
  Color darken([double amount = .12]) {
    final h = HSLColor.fromColor(this);
    return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  Color lighten([double amount = .12]) {
    final h = HSLColor.fromColor(this);
    return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}
