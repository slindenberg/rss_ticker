import 'package:flutter_test/flutter_test.dart';
import 'package:rss_ticker/dao/network/feed_fetcher.dart';

void main() {
  group('normalizeFeedUrl', () {
    test('returns empty string unchanged', () {
      expect(normalizeFeedUrl(''), '');
    });

    test('trims whitespace', () {
      expect(
        normalizeFeedUrl('  https://example.com  '),
        'https://example.com',
      );
    });

    test('adds https:// when scheme is missing', () {
      expect(normalizeFeedUrl('example.com/feed'), 'https://example.com/feed');
    });

    test('keeps existing https:// scheme', () {
      expect(
        normalizeFeedUrl('https://example.com/feed'),
        'https://example.com/feed',
      );
    });

    test('keeps existing http:// scheme', () {
      expect(
        normalizeFeedUrl('http://example.com/feed'),
        'http://example.com/feed',
      );
    });

    test('maps github.com/blog.atom to github blog feed', () {
      expect(
        normalizeFeedUrl('github.com/blog.atom'),
        'https://github.blog/feed/',
      );
    });

    test('maps www.github.com/blog.atom to github blog feed', () {
      expect(
        normalizeFeedUrl('www.github.com/blog.atom'),
        'https://github.blog/feed/',
      );
    });

    test('does not modify unrelated github URL', () {
      expect(
        normalizeFeedUrl('github.com/user/repo/releases.atom'),
        'https://github.com/user/repo/releases.atom',
      );
    });
  });
}
