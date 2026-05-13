import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../util/color_utils.dart';

class AppConfig {
  final double textSpeed;
  final Color foregroundColor;
  final Color backgroundColor;
  final String separator;

  const AppConfig({
    this.textSpeed = 60,
    this.foregroundColor = Colors.white,
    this.backgroundColor = const Color(0xFF0D47A1),
    this.separator = '+++',
  });

  AppConfig copyWith({
    double? textSpeed,
    Color? foregroundColor,
    Color? backgroundColor,
    String? separator,
  }) {
    return AppConfig(
      textSpeed: textSpeed ?? this.textSpeed,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      separator: separator ?? this.separator,
    );
  }
}

Future<Directory> getStorageDirectory() async {
  String homeDir =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';

  if (homeDir.contains('Library/Containers')) {
    final user = Platform.environment['USER'] ?? '';
    if (user.isNotEmpty) {
      homeDir = '/Users/$user';
    } else {
      final parts = homeDir.split('/');
      if (parts.length > 1 && parts[0].isEmpty && parts[1] == 'Users') {
        homeDir = '/${parts[1]}/${parts[2]}';
      }
    }
  }

  final dir = Directory('$homeDir/.rssticker');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<File> getConfigFile() async {
  final dir = await getStorageDirectory();
  return File('${dir.path}/config.json');
}

Future<AppConfig> loadConfig() async {
  try {
    final file = await getConfigFile();
    if (!await file.exists()) {
      return const AppConfig();
    }
    final contents = await file.readAsString();
    final Map<String, dynamic> json =
        jsonDecode(contents) as Map<String, dynamic>;
    return AppConfig(
      textSpeed: readDouble(json['textSpeed'], fallback: 60),
      foregroundColor: readColor(
        json['foregroundColor'],
        fallback: Colors.white,
      ),
      backgroundColor: readColor(
        json['backgroundColor'],
        fallback: const Color(0xFF0D47A1),
      ),
      separator: readSeparator(json['separator'], fallback: '+++'),
    );
  } catch (e) {
    debugPrint('Error loading config: $e');
    return const AppConfig();
  }
}

Future<void> saveConfig(AppConfig config) async {
  try {
    final file = await getConfigFile();
    final json = {
      'textSpeed': config.textSpeed,
      'foregroundColor': colorToHex(config.foregroundColor),
      'backgroundColor': colorToHex(config.backgroundColor),
      'separator': config.separator,
    };
    await file.writeAsString(jsonEncode(json));
  } catch (e) {
    debugPrint('Error saving config: $e');
  }
}
