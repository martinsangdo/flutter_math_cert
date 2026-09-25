import 'package:flutter/material.dart';

/// Playful, chunky "learning" look: blue primary, amber for the main action,
/// pink accents, Baloo 2 headings over the platform font for body text.
class AppTheme {
  const AppTheme._();

  static final light = _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF2563EB),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDBEAFE),
      onPrimaryContainer: Color(0xFF1E3A8A),
      secondary: Color(0xFFF59E0B),
      onSecondary: Color(0xFF0F172A),
      secondaryContainer: Color(0xFFFEF3C7),
      onSecondaryContainer: Color(0xFF78350F),
      tertiary: Color(0xFFEC4899),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFCE7F3),
      onTertiaryContainer: Color(0xFF831843),
      error: Color(0xFFDC2626),
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: Colors.white,
      onSurface: Color(0xFF0F172A),
      onSurfaceVariant: Color(0xFF475569),
      surfaceContainerHighest: Color(0xFFE8EFFC),
      outline: Color(0xFF64748B),
      outlineVariant: Color(0xFFCBD9F5),
    ),
    background: const Color(0xFFEFF6FF),
  );

  static final dark = _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF8AB4FF),
      onPrimary: Color(0xFF0B1B3D),
      primaryContainer: Color(0xFF1E3A8A),
      onPrimaryContainer: Color(0xFFDBEAFE),
      secondary: Color(0xFFFBBF24),
      onSecondary: Color(0xFF1C1400),
      secondaryContainer: Color(0xFF5A3D00),
      onSecondaryContainer: Color(0xFFFEF3C7),
      tertiary: Color(0xFFF472B6),
      onTertiary: Color(0xFF3B0A24),
      tertiaryContainer: Color(0xFF6B1D45),
      onTertiaryContainer: Color(0xFFFCE7F3),
      error: Color(0xFFF87171),
      onError: Color(0xFF3B0A0A),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: Color(0xFF131C2E),
      onSurface: Color(0xFFE5EDFF),
      onSurfaceVariant: Color(0xFFA8B5CC),
      surfaceContainerHighest: Color(0xFF243250),
      outline: Color(0xFF8593AD),
      outlineVariant: Color(0xFF2C3A58),
    ),
    background: const Color(0xFF0B1220),
  );

  /// Cycled for contests and skill domains.
  static const accents = <Color>[
    Color(0xFF2563EB),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF16A34A),
    Color(0xFF7C3AED),
    Color(0xFF0D9488),
  ];

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
  );

  static TextStyle heading(double size, int weight, {Color? color, double height = 1.2}) => TextStyle(
        fontFamily: 'Baloo2',
        fontSize: size,
        height: height,
        color: color,
        fontWeight: FontWeight.values[weight ~/ 100 - 1],
        fontVariations: [FontVariation('wght', weight.toDouble())],
      );

  static ThemeData _build(ColorScheme s, {required Color background}) {
    final base = ThemeData(useMaterial3: true, colorScheme: s);
    final radius = BorderRadius.circular(18);
    final buttonText = heading(18, 700, height: 1.1);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.copyWith(
        displayMedium: heading(48, 800, color: s.onSurface, height: 1.1),
        headlineMedium: heading(30, 700, color: s.onSurface),
        headlineSmall: heading(26, 700, color: s.onSurface),
        titleLarge: heading(22, 700, color: s.onSurface),
        titleMedium: heading(18, 600, color: s.onSurface),
        titleSmall: heading(16, 600, color: s.onSurface),
        labelLarge: heading(16, 600, color: s.onSurface),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: s.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: heading(22, 700, color: s.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: s.outlineVariant, width: 2),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: s.outlineVariant, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: s.outlineVariant, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: s.primary, width: 3),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: s.primary,
        linearTrackColor: s.primaryContainer,
        circularTrackColor: s.primaryContainer,
        linearMinHeight: 10,
        borderRadius: BorderRadius.circular(99),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: heading(22, 700, color: s.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: s.outlineVariant, thickness: 1.5, space: 1.5),
    );
  }
}

extension AppColors on ColorScheme {
  Color get success =>
      brightness == Brightness.light ? const Color(0xFF15803D) : const Color(0xFF4ADE80);
  Color get warning =>
      brightness == Brightness.light ? const Color(0xFFB45309) : const Color(0xFFFBBF24);
}
