import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// LGS+ 建設現場向けテーマ（濃紺×安全黄）
class AppTheme {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color navyMid = Color(0xFF163A5F);
  static const Color safetyYellow = Color(0xFFF5B800);
  static const Color steel = Color(0xFF4A6B8A);
  static const Color surface = Color(0xFFF3F6FA);
  static const Color accent = Color(0xFF1F8A70);
  static const Color danger = Color(0xFFC0392B);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: safetyYellow,
        surface: surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: surface,
    );

    return base.copyWith(
      textTheme: GoogleFonts.notoSansJpTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.notoSansJp(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: safetyYellow,
        foregroundColor: navy,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.notoSansJp(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: navy, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: navyMid, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? navy : null,
        ),
      ),
    );
  }
}
