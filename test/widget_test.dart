import 'package:flutter_test/flutter_test.dart';
import 'package:rss_ticker/main.dart';

void main() {
  testWidgets('TickerApp smoke test – builds without throwing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TickerApp());
    // Only the first frame: initialization callbacks haven't run yet,
    // so no network calls or file I/O happen.
    expect(find.byType(TickerApp), findsOneWidget);
  });
}
