import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_composer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders prompt and sends on keyboard submit', (tester) async {
    final controller = TextEditingController();
    var submitted = false;
    await tester.pumpWidget(_wrap(
      ChatComposer(
        controller: controller,
        enabled: true,
        isLoading: false,
        onSubmitted: () => submitted = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text(r'$ '), findsOneWidget);
    expect(find.text('>'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    field.onSubmitted?.call('hello');
    expect(submitted, isTrue);
    controller.dispose();
  });

  testWidgets('disables input and send action while loading', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(
      MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(2),
        ),
        child: ChatComposer(
          controller: controller,
          enabled: false,
          isLoading: true,
          onSubmitted: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(TerminalStatusGlyph), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
    controller.dispose();
  });

  testWidgets('fits a narrow mobile viewport while loading', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(
      ChatComposer(
        controller: controller,
        enabled: false,
        isLoading: true,
        onSubmitted: () {},
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
