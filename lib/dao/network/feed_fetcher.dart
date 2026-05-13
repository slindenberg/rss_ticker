import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../models/ticker_entry.dart';
import '../rss/rss_parser.dart';

/// Fetches and parses all [feeds], returning a flat list of [TickerEntry] items.
///
/// Each URL is normalised via [normalizeFeedUrl] before the HTTP request.
/// Per-feed errors are included as error entries rather than thrown, so the
/// ticker always has something to display.
Future<List<TickerEntry>> fetchHeadlines(List<String> feeds) async {
  if (feeds.isEmpty) {
    return const [
      TickerEntry(title: 'No feeds configured. Add feeds in Manage Feeds.'),
    ];
  }

  final List<TickerEntry> allEntries = [];

  for (final feedUrl in feeds) {
    final normalizedFeedUrl = normalizeFeedUrl(feedUrl);
    try {
      final uri = Uri.tryParse(normalizedFeedUrl);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        _logFeedError(
          feedUrl: feedUrl,
          normalizedFeedUrl: normalizedFeedUrl,
          reason: 'Invalid URL',
        );
        allEntries.add(
          TickerEntry(title: 'Error loading ($feedUrl): Invalid URL'),
        );
        continue;
      }

      final response = await http
          .get(uri, headers: const {'User-Agent': 'rss-ticker/1.0 (+Flutter)'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(
          response.bodyBytes,
          allowMalformed: true,
        );
        final parseResult = extractTitlesFromFeed(responseBody);
        if (parseResult.entries.isNotEmpty) {
          allEntries.addAll(parseResult.entries);
        } else {
          final reason = parseResult.error ?? 'No entries found in feed';
          _logFeedError(
            feedUrl: feedUrl,
            normalizedFeedUrl: normalizedFeedUrl,
            reason: reason,
          );
          allEntries.add(
            TickerEntry(title: 'Error loading ($feedUrl): $reason'),
          );
        }
      } else {
        final reason =
            'HTTP ${response.statusCode} ${response.reasonPhrase ?? ''}'.trim();
        _logFeedError(
          feedUrl: feedUrl,
          normalizedFeedUrl: normalizedFeedUrl,
          reason: reason,
        );
        allEntries.add(TickerEntry(title: 'Error loading ($feedUrl): $reason'));
      }
    } on TimeoutException catch (e) {
      _logFeedError(
        feedUrl: feedUrl,
        normalizedFeedUrl: normalizedFeedUrl,
        reason: 'Request timeout',
        error: e,
      );
      allEntries.add(
        TickerEntry(title: 'Error loading ($feedUrl): Request timeout'),
      );
    } on SocketException catch (e) {
      _logFeedError(
        feedUrl: feedUrl,
        normalizedFeedUrl: normalizedFeedUrl,
        reason: 'Network error',
        error: e,
      );
      allEntries.add(
        TickerEntry(title: 'Error loading ($feedUrl): Network error'),
      );
    } on HttpException catch (e) {
      _logFeedError(
        feedUrl: feedUrl,
        normalizedFeedUrl: normalizedFeedUrl,
        reason: 'HTTP exception',
        error: e,
      );
      allEntries.add(
        TickerEntry(title: 'Error loading ($feedUrl): HTTP exception'),
      );
    } catch (e) {
      _logFeedError(
        feedUrl: feedUrl,
        normalizedFeedUrl: normalizedFeedUrl,
        reason: 'Unexpected error',
        error: e,
      );
      allEntries.add(
        TickerEntry(title: 'Error loading ($feedUrl): Unexpected error'),
      );
    }
  }

  return allEntries.isNotEmpty
      ? allEntries
      : const [TickerEntry(title: 'No headlines found')];
}

/// Normalises a user-supplied feed URL string.
///
/// - Trims whitespace.
/// - Prepends `https://` when no scheme is present.
/// - Rewrites well-known GitHub Atom paths to their canonical equivalents.
String normalizeFeedUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  String normalized = trimmed;
  Uri? uri = Uri.tryParse(normalized);

  if (uri == null || uri.scheme.isEmpty) {
    normalized = 'https://$trimmed';
    uri = Uri.tryParse(normalized);
  }

  if (uri == null) {
    return normalized;
  }

  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  if ((host == 'github.com' || host == 'www.github.com') &&
      path.startsWith('/blog.atom')) {
    return 'https://github.blog/feed/';
  }

  return normalized;
}

/// Attempts to open [uri] in the default external browser.
///
/// Tries `url_launcher` first, then falls back to platform-native commands
/// (`open` on macOS, `xdg-open` on Linux, `start` on Windows).
/// Returns `true` if any method succeeds.
Future<bool> tryOpenInBrowser(Uri uri) async {
  try {
    final canLaunch = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (canLaunch) {
      return true;
    }
    debugPrint('url_launcher returned false for: ${uri.toString()}');
  } catch (e) {
    debugPrint('url_launcher failed for ${uri.toString()}: $e');
  }

  try {
    if (Platform.isMacOS) {
      final result = await Process.run('open', [uri.toString()]);
      if (result.exitCode == 0) {
        return true;
      }
      debugPrint('open failed (${result.exitCode}): ${result.stderr}');
    } else if (Platform.isLinux) {
      final result = await Process.run('xdg-open', [uri.toString()]);
      if (result.exitCode == 0) {
        return true;
      }
      debugPrint('xdg-open failed (${result.exitCode}): ${result.stderr}');
    } else if (Platform.isWindows) {
      final result = await Process.run('cmd', [
        '/c',
        'start',
        '',
        uri.toString(),
      ]);
      if (result.exitCode == 0) {
        return true;
      }
      debugPrint('start failed (${result.exitCode}): ${result.stderr}');
    }
  } catch (e) {
    debugPrint('Process fallback failed for ${uri.toString()}: $e');
  }

  return false;
}

void _logFeedError({
  required String feedUrl,
  required String normalizedFeedUrl,
  required String reason,
  Object? error,
}) {
  final suffix = error != null ? ' | error: $error' : '';
  debugPrint(
    'Feed load error | input: $feedUrl | normalized: $normalizedFeedUrl | reason: $reason$suffix',
  );
}
