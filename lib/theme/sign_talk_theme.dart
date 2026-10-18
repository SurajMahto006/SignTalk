import 'package:flutter/material.dart';

import 'sign_talk_colors.dart';

abstract final class SignTalkTheme {
  static ThemeData get light {
    const textTheme = TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
        color: SignTalkColors.primaryText,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: SignTalkColors.primaryText,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: SignTalkColors.primaryText,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: SignTalkColors.secondaryText,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: SignTalkColors.secondaryText,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: SignTalkColors.primaryText,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: SignTalkColors.primaryBlue,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: SignTalkColors.secondaryText,
      ),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SignTalkColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: SignTalkColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SignTalkColors.primaryBlue,
        primary: SignTalkColors.primaryBlue,
        surface: SignTalkColors.card,
        onSurface: SignTalkColors.primaryText,
      ),
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashColor: SignTalkColors.primaryBlue.withValues(alpha: 0.08),
      highlightColor: SignTalkColors.primaryBlue.withValues(alpha: 0.05),
      cardTheme: CardThemeData(
        color: SignTalkColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: SignTalkColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SignTalkColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SignTalkColors.primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SignTalkColors.primaryBlue,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: SignTalkColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SignTalkColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(
            color: SignTalkColors.primaryBlue,
            width: 1.5,
          ),
        ),
        labelStyle: const TextStyle(
          color: SignTalkColors.secondaryText,
          fontSize: 13,
        ),
      ),
    );
  }
}
