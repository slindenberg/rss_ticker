import 'package:flutter/material.dart';

String colorToHex(Color color) {
  final value = color.toARGB32();
  return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

Color readColor(Object? value, {required Color fallback}) {
  if (value is String) {
    final hex = value.replaceAll('#', '');
    if (hex.length == 8) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) {
        return Color(parsed);
      }
    }
    if (hex.length == 6) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) {
        return Color(0xFF000000 | parsed);
      }
    }
  }
  return fallback;
}

double readDouble(Object? value, {required double fallback}) {
  if (value is num) {
    return value.toDouble().clamp(10, 300);
  }
  return fallback;
}

String readSeparator(Object? value, {required String fallback}) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}
