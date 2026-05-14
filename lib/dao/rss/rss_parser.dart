import 'package:webfeed/webfeed.dart';

import '../../models/ticker_entry.dart';

/// The result of parsing a raw feed string.
///
/// On success, [entries] contains the parsed items and [error] is `null`.
/// On failure, [entries] is empty and [error] describes the reason.
class FeedParseResult {
  /// Parsed ticker entries; empty when parsing failed.
  final List<TickerEntry> entries;

  /// Human-readable error description, or `null` on success.
  final String? error;

  const FeedParseResult({required this.entries, this.error});
}

/// Parses [xml] as an RSS 2.0 or Atom feed and returns a [FeedParseResult].
///
/// RSS is attempted first; Atom is tried as a fallback. Items with blank
/// titles are filtered out. Returns an empty result with an [error] message
/// when neither format can be parsed or no entries are found.
FeedParseResult extractTitlesFromFeed(String xml) {
  Object? rssError;
  try {
    final rssFeed = RssFeed.parse(xml);
    final feedTitle = rssFeed.title?.trim();
    final entries = (rssFeed.items ?? [])
        .map(
          (item) => TickerEntry(
            title: item.title?.trim() ?? '',
            link: item.link?.trim(),
            feedTitle: feedTitle,
          ),
        )
        .where((entry) => entry.title.isNotEmpty)
        .toList();
    if (entries.isNotEmpty) {
      return FeedParseResult(entries: entries);
    }
  } catch (e) {
    rssError = e;
  }

  Object? atomError;
  try {
    final atomFeed = AtomFeed.parse(xml);
    final feedTitle = atomFeed.title?.trim();
    final atomEntries = (atomFeed.items ?? [])
        .map(
          (item) => TickerEntry(
            title: item.title?.trim() ?? '',
            link: item.links?.firstOrNull?.href?.trim(),
            feedTitle: feedTitle,
          ),
        )
        .where((entry) => entry.title.isNotEmpty)
        .toList();
    if (atomEntries.isNotEmpty) {
      return FeedParseResult(entries: atomEntries);
    }
  } catch (e) {
    atomError = e;
  }

  String reason = 'No entries found in feed';
  if (rssError != null || atomError != null) {
    reason =
        'Parse failed (rss: ${rssError ?? 'n/a'}, atom: ${atomError ?? 'n/a'})';
  }

  return FeedParseResult(entries: const [], error: reason);
}
