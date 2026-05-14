import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../util/color_utils.dart';

/// Immutable configuration for the RSS ticker.
///
/// All visual and behavioural settings are held here and persisted to
/// `~/.rssticker/config.json`.
class AppConfig {
  /// Scroll speed of the ticker in logical pixels per second.
  final double textSpeed;

  /// Foreground (text) color of the ticker bar.
  final Color foregroundColor;

  /// Background color of the ticker bar.
  final Color backgroundColor;

  /// String inserted between headline items (e.g. `+++`).
  final String separator;

  /// How often the feeds are automatically refreshed, in minutes.
  /// A value ≤ 0 disables automatic refresh.
  final int refreshIntervalMinutes;

  /// Whether to show the feed title label before each headline.
  final bool showFeedTitle;

  const AppConfig({
    this.textSpeed = 60,
    this.foregroundColor = Colors.white,
    this.backgroundColor = const Color(0xFF0D47A1),
    this.separator = '+++',
    this.refreshIntervalMinutes = 5,
    this.showFeedTitle = true,
  });

  /// Returns a copy of this config with the specified fields replaced.
  AppConfig copyWith({
    double? textSpeed,
    Color? foregroundColor,
    Color? backgroundColor,
    String? separator,
    int? refreshIntervalMinutes,
    bool? showFeedTitle,
  }) {
    return AppConfig(
      textSpeed: textSpeed ?? this.textSpeed,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      separator: separator ?? this.separator,
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      showFeedTitle: showFeedTitle ?? this.showFeedTitle,
    );
  }
}

/// Returns the application's storage directory (`~/.rssticker`),
/// creating it if it does not yet exist.
///
/// Handles sandboxed macOS environments by resolving the real home
/// directory from environment variables.
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

/// Returns the [File] reference for the config JSON file.
Future<File> getConfigFile() async {
  final dir = await getStorageDirectory();
  return File('${dir.path}/config.json');
}

/// Loads [AppConfig] from disk.
///
/// Returns [AppConfig] with default values if the file does not exist
/// or cannot be parsed.
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
      refreshIntervalMinutes: (json['refreshIntervalMinutes'] as int?) ?? 5,
      showFeedTitle: (json['showFeedTitle'] as bool?) ?? true,
    );
  } catch (e) {
    debugPrint('Error loading config: $e');
    return const AppConfig();
  }
}

/// Persists [config] to the config JSON file on disk.
///
/// Errors are caught and logged via [debugPrint].
Future<void> saveConfig(AppConfig config) async {
  try {
    final file = await getConfigFile();
    final json = {
      'textSpeed': config.textSpeed,
      'foregroundColor': colorToHex(config.foregroundColor),
      'backgroundColor': colorToHex(config.backgroundColor),
      'separator': config.separator,
      'refreshIntervalMinutes': config.refreshIntervalMinutes,
      'showFeedTitle': config.showFeedTitle,
    };
    await file.writeAsString(jsonEncode(json));
  } catch (e) {
    debugPrint('Error saving config: $e');
  }
}
