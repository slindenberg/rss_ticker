import 'package:flutter/material.dart';

import '../../config/app_config.dart' show AppConfig;
import '../../config/app_config.dart' as config_impl;
import '../../config/feeds_storage.dart' as storage;
import '../../models/ticker_entry.dart';
import '../../dao/network/feed_fetcher.dart' as fetcher;

/// Facade that aggregates all data-layer operations for the ticker.
///
/// UI code should depend only on [TickerService] and never import
/// `config`, `feeds_storage`, or `feed_fetcher` directly.
class TickerService {
  /// Performs one-time startup work (e.g. resolving the storage directory).
  Future<void> initialize() async {
    final storageDir = await config_impl.getStorageDirectory();
    debugPrint('Storage directory: ${storageDir.path}');
  }

  /// Loads the persisted [AppConfig] from disk.
  Future<AppConfig> loadConfig() => config_impl.loadConfig();

  /// Persists [config] to disk.
  Future<void> saveConfig(AppConfig config) => config_impl.saveConfig(config);

  /// Loads the persisted list of feed URLs from disk.
  Future<List<String>> loadFeeds() => storage.loadFeeds();

  /// Persists the list of feed [feeds] URLs to disk.
  Future<void> saveFeeds(List<String> feeds) => storage.saveFeeds(feeds);

  /// Fetches headlines from all [feeds] and returns the aggregated entries.
  Future<List<TickerEntry>> fetchHeadlines(List<String> feeds) =>
      fetcher.fetchHeadlines(feeds);

  /// Opens the URL from [entry] in the default browser.
  ///
  /// Returns `false` when the entry has no valid link or the browser
  /// could not be launched.
  Future<bool> openEntry(TickerEntry entry) async {
    final rawLink = entry.link?.trim();
    if (rawLink == null || rawLink.isEmpty) return false;

    Uri? uri = Uri.tryParse(rawLink);
    if (uri != null && !uri.hasScheme) {
      uri = Uri.tryParse('https://$rawLink');
    }
    if (uri == null || !uri.hasScheme) return false;

    debugPrint('Ticker link clicked: $uri');
    return fetcher.tryOpenInBrowser(uri);
  }
}
