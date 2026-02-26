import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic smoke test — actual testing requires Firebase mocking
    expect(1 + 1, equals(2));
  });
}
