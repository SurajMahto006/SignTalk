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
      splashColor: SignTalkColors.primaryBlue.withValues(alpha: 0.08),
      highlightColor: SignTalkColors.primaryBlue.withValues(alpha: 0.05),
    );
  }
}
