import 'package:flutter/material.dart';

import '../../config/app_config.dart';

/// Central theme helpers for the RSS ticker UI.
///
/// Use [themeData] to build a [ThemeData] from an [AppConfig], and the
/// static [TextStyle] factories for consistent text styling across widgets.
class TickerTheme {
  const TickerTheme._();

  /// Builds a [ThemeData] that maps [AppConfig] colors to [ColorScheme] roles:
  /// - `primary` → foreground text color
  /// - `surface` → ticker bar background color
  static ThemeData themeData(AppConfig config) => ThemeData(
    colorScheme: ColorScheme.dark(
      primary: config.foregroundColor,
      surface: config.backgroundColor,
    ),
  );

  /// Returns the [TextStyle] used for ticker headline text.
  ///
  /// Pass [underline] `true` to add an underline decoration (used on hover).
  static TextStyle tickerText({required Color color, bool underline = false}) =>
      TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        decoration: underline ? TextDecoration.underline : TextDecoration.none,
        decorationColor: color,
      );

  /// [TextStyle] used for dropdown menu item labels.
  static const TextStyle menuItemText = TextStyle(
    color: Colors.black,
    fontSize: 16,
  );
}
