import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import 'manage_feeds_dialog.dart';
import 'settings_dialog.dart';

/// Callback signature for settings changes.
///
/// [updated] is the new [AppConfig] with all changes applied.
/// [speedChanged] is `true` when the scroll speed changed (scroll must restart).
/// [refreshChanged] is `true` when the refresh interval changed (timer must restart).
typedef SettingsChangedCallback =
    void Function(
      AppConfig updated, {
      required bool speedChanged,
      required bool refreshChanged,
    });

/// Shows the [SettingsDialog] and calls [onChanged] whenever any setting is
/// modified. The caller is responsible for persisting the returned config.
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
      initialShowFeedTitle: config.showFeedTitle,
      onSettingsChanged:
          ({
            required double speed,
            required Color foregroundColor,
            required Color backgroundColor,
            required String separator,
            required int refreshIntervalMinutes,
            required bool showFeedTitle,
          }) {
            final updated = config.copyWith(
              textSpeed: speed,
              foregroundColor: foregroundColor,
              backgroundColor: backgroundColor,
              separator: separator,
              refreshIntervalMinutes: refreshIntervalMinutes,
              showFeedTitle: showFeedTitle,
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

/// Shows the [ManageFeedsDialog] and forwards feed list changes to [onChanged].
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
