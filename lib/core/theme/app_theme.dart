import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// The shared MindCheck theme: team colour palette ([AppColors]), Poppins
/// for headings and Nunito Sans for body text.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.purple).copyWith(
      primary: AppColors.purple,
      onPrimary: Colors.white,
      primaryContainer: AppColors.purpleLight,
      onPrimaryContainer: AppColors.purpleDark,
      secondary: AppColors.sage,
      onSecondary: AppColors.sageInk,
      secondaryContainer: AppColors.sageLight,
      onSecondaryContainer: AppColors.sageDark,
      tertiary: AppColors.coral,
      onTertiary: AppColors.coralDark,
      tertiaryContainer: AppColors.coralLight,
      onTertiaryContainer: AppColors.coralDark,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.textSecondary,
      outlineVariant: AppColors.outline,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: const Color(0xFFFBFAFD),
      surfaceContainer: const Color(0xFFF1EEF6),
      surfaceContainerHigh: const Color(0xFFECE8F2),
      surfaceContainerHighest: const Color(0xFFE6E1EE),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );
    final textTheme = _textTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.sageLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.purple, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.sage,
        side: const BorderSide(color: AppColors.outline),
        labelStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      // Clean bottom bar: white, no pill, active item in the accent colour.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x33000000),
        height: 72,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? AppColors.purple
                : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.purple
                : AppColors.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.purpleDark,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.purple,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Nunito Sans for body text, Poppins for display, headline and title
  /// styles.
  static TextTheme _textTheme(TextTheme base) {
    final body = GoogleFonts.nunitoSansTextTheme(base);
    TextStyle? heading(TextStyle? s) => GoogleFonts.poppins(textStyle: s);
    return body
        .copyWith(
          displayLarge: heading(body.displayLarge),
          displayMedium: heading(body.displayMedium),
          displaySmall: heading(body.displaySmall),
          headlineLarge: heading(body.headlineLarge),
          headlineMedium: heading(body.headlineMedium),
          headlineSmall: heading(body.headlineSmall),
          titleLarge: heading(body.titleLarge),
          titleMedium: heading(body.titleMedium),
          titleSmall: heading(body.titleSmall),
        )
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );
  }
}
