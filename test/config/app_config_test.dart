import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rss_ticker/config/app_config.dart';

void main() {
  group('AppConfig defaults', () {
    const config = AppConfig();

    test('default textSpeed is 60', () {
      expect(config.textSpeed, 60.0);
    });

    test('default foregroundColor is white', () {
      expect(config.foregroundColor, Colors.white);
    });

    test('default backgroundColor is dark blue', () {
      expect(config.backgroundColor, const Color(0xFF0D47A1));
    });

    test('default separator is +++', () {
      expect(config.separator, '+++');
    });

    test('default refreshIntervalMinutes is 5', () {
      expect(config.refreshIntervalMinutes, 5);
    });
  });

  group('AppConfig copyWith', () {
    const original = AppConfig();

    test('copies textSpeed', () {
      final updated = original.copyWith(textSpeed: 120.0);
      expect(updated.textSpeed, 120.0);
      expect(updated.foregroundColor, original.foregroundColor);
    });

    test('copies foregroundColor', () {
      final updated = original.copyWith(foregroundColor: Colors.red);
      expect(updated.foregroundColor, Colors.red);
      expect(updated.textSpeed, original.textSpeed);
    });

    test('copies backgroundColor', () {
      final updated = original.copyWith(backgroundColor: Colors.black);
      expect(updated.backgroundColor, Colors.black);
    });

    test('copies separator', () {
      final updated = original.copyWith(separator: '---');
      expect(updated.separator, '---');
    });

    test('copies refreshIntervalMinutes', () {
      final updated = original.copyWith(refreshIntervalMinutes: 15);
      expect(updated.refreshIntervalMinutes, 15);
    });

    test('preserves all other fields when one is changed', () {
      final updated = original.copyWith(textSpeed: 90.0);
      expect(updated.backgroundColor, original.backgroundColor);
      expect(updated.foregroundColor, original.foregroundColor);
      expect(updated.separator, original.separator);
      expect(updated.refreshIntervalMinutes, original.refreshIntervalMinutes);
    });
  });
}
