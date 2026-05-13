import 'package:flutter_test/flutter_test.dart';
import 'package:rss_ticker/models/ticker_entry.dart';

void main() {
  group('TickerEntry', () {
    test('stores title', () {
      const entry = TickerEntry(title: 'Breaking News');
      expect(entry.title, 'Breaking News');
    });

    test('link is null by default', () {
      const entry = TickerEntry(title: 'No Link');
      expect(entry.link, isNull);
    });

    test('stores optional link', () {
      const entry =
          TickerEntry(title: 'With Link', link: 'https://example.com');
      expect(entry.link, 'https://example.com');
    });

    test('allows empty title', () {
      const entry = TickerEntry(title: '');
      expect(entry.title, '');
    });
  });
}
