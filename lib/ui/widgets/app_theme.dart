import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class TickerTheme {
  const TickerTheme._();

  static ThemeData themeData(AppConfig config) => ThemeData(
    colorScheme: ColorScheme.dark(
      primary: config.foregroundColor,
      surface: config.backgroundColor,
    ),
  );

  static TextStyle tickerText({required Color color, bool underline = false}) =>
      TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        decoration: underline ? TextDecoration.underline : TextDecoration.none,
        decorationColor: color,
      );

  static const TextStyle menuItemText = TextStyle(
    color: Colors.black,
    fontSize: 16,
  );
}
