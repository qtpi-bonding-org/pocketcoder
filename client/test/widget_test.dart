import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/app/app.dart';
import 'package:get_it/get_it.dart';
import 'package:test_app/design_system/theme/theme_service.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalizationService extends Mock implements ILocalizationService {}

void main() {
  setUpAll(() {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<ThemeService>()) {
      getIt.registerSingleton<ThemeService>(ThemeService());
    }
    if (!getIt.isRegistered<ILocalizationService>()) {
      getIt.registerSingleton<ILocalizationService>(MockLocalizationService());
    }
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const App());

    // Verify that our home page shows up
    expect(find.text('Home Page'), findsOneWidget);
  });
}
