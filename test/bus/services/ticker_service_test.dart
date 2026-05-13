import 'package:flutter_test/flutter_test.dart';
import 'package:rss_ticker/bus/services/ticker_service.dart';
import 'package:rss_ticker/models/ticker_entry.dart';

void main() {
  group('TickerService.openEntry – link validation', () {
    final service = TickerService();

    test('returns false when link is null', () async {
      const entry = TickerEntry(title: 'No link');
      final result = await service.openEntry(entry);
      expect(result, isFalse);
    });

    test('returns false when link is empty string', () async {
      const entry = TickerEntry(title: 'Empty link', link: '');
      final result = await service.openEntry(entry);
      expect(result, isFalse);
    });

    test('returns false when link is whitespace only', () async {
      const entry = TickerEntry(title: 'Whitespace link', link: '   ');
      final result = await service.openEntry(entry);
      expect(result, isFalse);
    });
  });
}
