import 'package:webfeed/webfeed.dart';

import '../models/ticker_entry.dart';

class FeedParseResult {
  final List<TickerEntry> entries;
  final String? error;

  const FeedParseResult({required this.entries, this.error});
}

FeedParseResult extractTitlesFromFeed(String xml) {
  Object? rssError;
  try {
    final rssFeed = RssFeed.parse(xml);
    final entries = (rssFeed.items ?? [])
        .map(
          (item) => TickerEntry(
            title: item.title?.trim() ?? '',
            link: item.link?.trim(),
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
    final atomEntries = (atomFeed.items ?? [])
        .map(
          (item) => TickerEntry(
            title: item.title?.trim() ?? '',
            link: item.links?.firstOrNull?.href?.trim(),
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
