import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFFEFDDF);
  static const card = Color(0xFFFFFFFF);
  static const pathBg = Color(0xFFE0EEF8);
  static const primary = Color(0xFFE87F24);
  static const primaryShadow = Color(0xFFC96A10);
  static const secondary = Color(0xFF73A5CA);
  static const secondaryShadow = Color(0xFF5A8AAD);
  static const gold = Color(0xFFFFC81E);
  static const goldShadow = Color(0xFFD4A400);
  static const flame = Color(0xFFFF9600);
  static const danger = Color(0xFFFF4B4B);
  static const dangerShadow = Color(0xFFCC3B3B);
  static const purple = Color(0xFFCE82FF);
  static const purpleShadow = Color(0xFFA560D9);
  static const textPrimary = Color(0xFF3C3C3C);
  static const textSecondary = Color(0xFF7A7A7A);
  static const lockBg = Color(0xFFE5E5E5);
  static const lockBorder = Color(0xFFC4C4C4);
}

class SubjectColors {
  static (Color bg, Color shadow) of(String subject) {
    switch (subject) {
      case 'math':
        return (AppColors.secondary, AppColors.secondaryShadow);
      case 'reading':
        return (AppColors.primary, AppColors.primaryShadow);
      case 'science':
        return (AppColors.gold, AppColors.goldShadow);
      default:
        return (AppColors.purple, AppColors.purpleShadow);
    }
  }
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    ),
  );
}
