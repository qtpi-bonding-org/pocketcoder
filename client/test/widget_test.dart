import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/app/app.dart';
import 'package:get_it/get_it.dart';
import 'package:test_app/design_system/theme/theme_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalizationService extends Mock {}

void main() {
  setUpAll(() {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<ThemeService>()) {
      getIt.registerSingleton<ThemeService>(ThemeService());
    }
  });

  testWidgets('App existence test', (WidgetTester tester) async {
    // Just verify the app widget can be instantiated
    const app = App();
    expect(app, isA<App>());
  });
}
