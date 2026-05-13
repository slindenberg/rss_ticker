import 'package:flutter/material.dart';

import '../../config/app_config.dart' show AppConfig;
import '../../config/app_config.dart' as config_impl;
import '../../config/feeds_storage.dart' as storage;
import '../../models/ticker_entry.dart';
import '../../dao/network/feed_fetcher.dart' as fetcher;

class TickerService {
  Future<void> initialize() async {
    final storageDir = await config_impl.getStorageDirectory();
    debugPrint('Storage directory: ${storageDir.path}');
  }

  Future<AppConfig> loadConfig() => config_impl.loadConfig();

  Future<void> saveConfig(AppConfig config) => config_impl.saveConfig(config);

  Future<List<String>> loadFeeds() => storage.loadFeeds();

  Future<void> saveFeeds(List<String> feeds) => storage.saveFeeds(feeds);

  Future<List<TickerEntry>> fetchHeadlines(List<String> feeds) =>
      fetcher.fetchHeadlines(feeds);

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
