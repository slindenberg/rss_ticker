import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'manage_feeds_dialog.dart';
import 'settings_dialog.dart';

typedef SettingsChangedCallback =
    void Function(
      AppConfig updated, {
      required bool speedChanged,
      required bool refreshChanged,
    });

Future<void> showSettingsDialog({
  required BuildContext context,
  required AppConfig config,
  required SettingsChangedCallback onChanged,
}) {
  return showDialog(
    context: context,
    builder: (context) => SettingsDialog(
      initialSpeed: config.textSpeed,
      initialForegroundColor: config.foregroundColor,
      initialBackgroundColor: config.backgroundColor,
      initialSeparator: config.separator,
      initialRefreshInterval: config.refreshIntervalMinutes,
      onSettingsChanged:
          ({
            required double speed,
            required Color foregroundColor,
            required Color backgroundColor,
            required String separator,
            required int refreshIntervalMinutes,
          }) {
            final updated = config.copyWith(
              textSpeed: speed,
              foregroundColor: foregroundColor,
              backgroundColor: backgroundColor,
              separator: separator,
              refreshIntervalMinutes: refreshIntervalMinutes,
            );
            onChanged(
              updated,
              speedChanged: (config.textSpeed - speed).abs() > 0.01,
              refreshChanged:
                  config.refreshIntervalMinutes != refreshIntervalMinutes,
            );
          },
    ),
  );
}

Future<void> showManageFeedsDialog({
  required BuildContext context,
  required List<String> feeds,
  required ValueChanged<List<String>> onChanged,
}) {
  return showDialog(
    context: context,
    builder: (context) =>
        ManageFeedsDialog(feeds: feeds, onFeedsChanged: onChanged),
  );
}
