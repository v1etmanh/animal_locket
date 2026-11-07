import 'package:animal_locket/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.purple,
        primary: AppColors.purple,
        surface: Colors.white,
      ),
    );
    final body = base.textTheme.apply(
      fontFamily: 'Plus Jakarta Sans',
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: body.copyWith(
        displayLarge: const TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 38,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
          height: 1.05,
        ),
        headlineLarge: const TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 30,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 26,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: .72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
      ),
    );
  }
}
