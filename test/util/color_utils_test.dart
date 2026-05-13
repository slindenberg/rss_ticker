import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rss_ticker/util/color_utils.dart';

void main() {
  group('colorToHex', () {
    test('converts white to hex string', () {
      expect(colorToHex(const Color(0xFFFFFFFF)), '#FFFFFFFF');
    });

    test('converts blue to hex string', () {
      expect(colorToHex(const Color(0xFF0D47A1)), '#FF0D47A1');
    });

    test('converts transparent black', () {
      expect(colorToHex(const Color(0x00000000)), '#00000000');
    });
  });

  group('readColor', () {
    test('parses 8-digit AARRGGBB hex string', () {
      expect(readColor('#FFFFFFFF', fallback: Colors.black),
          const Color(0xFFFFFFFF));
    });

    test('parses 6-digit RRGGBB hex string (adds FF alpha)', () {
      expect(readColor('#0D47A1', fallback: Colors.black),
          const Color(0xFF0D47A1));
    });

    test('returns fallback for null', () {
      expect(readColor(null, fallback: Colors.red), Colors.red);
    });

    test('returns fallback for invalid string', () {
      expect(readColor('not-a-color', fallback: Colors.red), Colors.red);
    });

    test('returns fallback for non-string type', () {
      expect(readColor(12345, fallback: Colors.red), Colors.red);
    });

    test('parses hex without leading #', () {
      expect(readColor('FFFFFFFF', fallback: Colors.black),
          const Color(0xFFFFFFFF));
    });
  });

  group('readDouble', () {
    test('returns value for int input', () {
      expect(readDouble(120, fallback: 60.0), 120.0);
    });

    test('returns value for double input', () {
      expect(readDouble(75.5, fallback: 60.0), 75.5);
    });

    test('clamps to minimum 10', () {
      expect(readDouble(5, fallback: 60.0), 10.0);
    });

    test('clamps to maximum 300', () {
      expect(readDouble(999, fallback: 60.0), 300.0);
    });

    test('returns fallback for null', () {
      expect(readDouble(null, fallback: 60.0), 60.0);
    });

    test('returns fallback for non-numeric', () {
      expect(readDouble('fast', fallback: 60.0), 60.0);
    });
  });

  group('readSeparator', () {
    test('returns trimmed string value', () {
      expect(readSeparator('  |||  ', fallback: '+++'), '|||');
    });

    test('returns fallback for null', () {
      expect(readSeparator(null, fallback: '+++'), '+++');
    });

    test('returns fallback for blank string', () {
      expect(readSeparator('   ', fallback: '+++'), '+++');
    });

    test('returns fallback for empty string', () {
      expect(readSeparator('', fallback: '+++'), '+++');
    });

    test('returns fallback for non-string', () {
      expect(readSeparator(42, fallback: '+++'), '+++');
    });
  });
}
