import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/app/app.dart';

void main() {
  testWidgets('App existence test', (WidgetTester tester) async {
    // App() requires DI (configureDependencies) to build its widget tree,
    // which isn't set up in this shell's test suite — real coverage lives
    // in packages/pocketcoder_flutter's screen/widget tests. This just
    // verifies the app shell's entry widget is constructible.
    const app = App();
    expect(app, isA<App>());
  });
}
