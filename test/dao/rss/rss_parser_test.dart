import 'package:flutter_test/flutter_test.dart';
import 'package:rss_ticker/dao/rss/rss_parser.dart';

const _validRss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <item>
      <title>First Item</title>
      <link>https://example.com/1</link>
    </item>
    <item>
      <title>Second Item</title>
      <link>https://example.com/2</link>
    </item>
  </channel>
</rss>''';

const _rssWithBlankTitle = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <item>
      <title>   </title>
      <link>https://example.com/blank</link>
    </item>
    <item>
      <title>Real Item</title>
      <link>https://example.com/real</link>
    </item>
  </channel>
</rss>''';

const _validAtom = '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom Test Feed</title>
  <entry>
    <title>Atom Entry 1</title>
    <link href="https://example.com/atom/1"/>
  </entry>
  <entry>
    <title>Atom Entry 2</title>
    <link href="https://example.com/atom/2"/>
  </entry>
</feed>''';

const _invalidXml = 'this is not xml at all <<<>>>';

const _emptyRss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Empty Feed</title>
  </channel>
</rss>''';

void main() {
  group('extractTitlesFromFeed – RSS', () {
    test('parses titles from valid RSS', () {
      final result = extractTitlesFromFeed(_validRss);
      expect(result.error, isNull);
      expect(result.entries.length, 2);
      expect(result.entries[0].title, 'First Item');
      expect(result.entries[1].title, 'Second Item');
    });

    test('parses links from valid RSS', () {
      final result = extractTitlesFromFeed(_validRss);
      expect(result.entries[0].link, 'https://example.com/1');
      expect(result.entries[1].link, 'https://example.com/2');
    });

    test('filters out blank-title items', () {
      final result = extractTitlesFromFeed(_rssWithBlankTitle);
      expect(result.entries.length, 1);
      expect(result.entries[0].title, 'Real Item');
    });
  });

  group('extractTitlesFromFeed – Atom', () {
    test('parses titles from valid Atom feed', () {
      final result = extractTitlesFromFeed(_validAtom);
      expect(result.error, isNull);
      expect(result.entries.length, 2);
      expect(result.entries[0].title, 'Atom Entry 1');
      expect(result.entries[1].title, 'Atom Entry 2');
    });

    test('parses hrefs from Atom links', () {
      final result = extractTitlesFromFeed(_validAtom);
      expect(result.entries[0].link, 'https://example.com/atom/1');
    });
  });

  group('extractTitlesFromFeed – error cases', () {
    test('returns empty entries and error for invalid XML', () {
      final result = extractTitlesFromFeed(_invalidXml);
      expect(result.entries, isEmpty);
      expect(result.error, isNotNull);
    });

    test('returns empty entries and error for empty feed', () {
      final result = extractTitlesFromFeed(_emptyRss);
      expect(result.entries, isEmpty);
      expect(result.error, isNotNull);
    });

    test('FeedParseResult carries error message', () {
      final result = extractTitlesFromFeed(_invalidXml);
      expect(result.error, contains('Parse failed'));
    });
  });
}
