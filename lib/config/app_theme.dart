import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FindMoSer App Theme — Clean White Neumorphism with blue accents
class AppTheme {
  AppTheme._();

  // ─── Brand Colors (Blue) ───
  static const Color primary = Color(0xFF245EA8); // Clean blue
  static const Color primaryLight = Color(0xFF3B70B4);
  static const Color primaryDark = Color(0xFF184B8A);
  static const Color accent = Color(0xFF315D91); // Soft blue

  // ─── Background Colors (Neumorphic base) ───
  static const Color background = Color(0xFFECEFF1); // Cool light gray
  static const Color surface = Color(
    0xFFECEFF1,
  ); // Same as bg for true neumorphism
  static const Color surfaceVariant = Color(0xFFE0E3E7); // Slightly darker

  // ─── Text Colors (Cool) ───
  static const Color textPrimary = Color(0xFF2D3436); // Cool dark
  static const Color textSecondary = Color(0xFF636E72); // Cool medium
  static const Color textHint = Color(0xFF596873); // Cool light
  static const Color border = Color(0xFFDFE6E9); // Cool border

  // ─── Status Colors ───
  static const Color success = Color(0xFF13745C); // Teal green
  static const Color warning = Color(0xFF805A08); // Golden
  static const Color error = Color(0xFFB43D30); // Coral
  static const Color online = Color(0xFF13745C);
  static const Color offline = Color(0xFF596873);

  // ─── Neumorphic Shadow Colors ───
  static const Color neumorphicLight = Color(
    0xFFFFFFFF,
  ); // Pure white highlight
  static const Color neumorphicDark = Color(0xFFD1D9E6); // Cool shadow

  // ─── Neumorphic Decorations ───

  /// Raised/convex neumorphic surface — the "popping out" look
  static BoxDecoration neumorphicDecoration({
    double borderRadius = 20,
    Color? color,
    double intensity = 0.65,
    Offset lightOffset = const Offset(-4, -4),
    Offset darkOffset = const Offset(4, 4),
    double blurRadius = 10,
  }) {
    return BoxDecoration(
      color: color ?? background,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: neumorphicLight.withValues(alpha: 0.85 * intensity),
          offset: lightOffset,
          blurRadius: blurRadius,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: neumorphicDark.withValues(alpha: 0.55 * intensity),
          offset: darkOffset,
          blurRadius: blurRadius,
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Pressed/concave neumorphic surface — the "pushed in" look
  static BoxDecoration neumorphicInsetDecoration({
    double borderRadius = 16,
    Color? color,
    double intensity = 0.65,
  }) {
    return BoxDecoration(
      color: color ?? surfaceVariant.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border),
    );
  }

  /// Flat neumorphic — no shadows, just the background color
  static BoxDecoration neumorphicFlatDecoration({
    double borderRadius = 20,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? background,
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  // ─── Legacy Gradient (kept for smooth migration) ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF3B70B4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFF345F92)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Card Shadows (Neumorphic) ───
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: neumorphicLight.withValues(alpha: 0.85),
      offset: const Offset(-3, -3),
      blurRadius: 8,
    ),
    BoxShadow(
      color: neumorphicDark.withValues(alpha: 0.45),
      offset: const Offset(3, 3),
      blurRadius: 8,
    ),
  ];

  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: neumorphicLight.withValues(alpha: 0.9),
      offset: const Offset(-5, -5),
      blurRadius: 12,
    ),
    BoxShadow(
      color: neumorphicDark.withValues(alpha: 0.55),
      offset: const Offset(5, 5),
      blurRadius: 12,
    ),
  ];

  // ─── Theme Data ───
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: textHint, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: background,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: textHint,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
