import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/files/file_viewer_screen.dart';

class MockFilesRepository extends Mock implements IFilesRepository {}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  late MockFilesRepository repo;

  setUp(() {
    repo = MockFilesRepository();
  });

  testWidgets('renders text content as selectable text', (tester) async {
    when(() => repo.readFile('README.md'))
        .thenAnswer((_) async => utf8.encode('hello world'));

    await tester.pumpWidget(
        _wrap(FileViewerScreen(path: 'README.md', repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('hello world'), findsOneWidget);
  });

  testWidgets('renders a .png path as an image', (tester) async {
    // 1x1 transparent PNG.
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    when(() => repo.readFile('logo.png')).thenAnswer((_) async => pngBytes);

    await tester.pumpWidget(
        _wrap(FileViewerScreen(path: 'logo.png', repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders an unsupported-type message for non-UTF8 binary',
      (tester) async {
    // Invalid UTF-8 byte sequence, and not an image extension.
    when(() => repo.readFile('data.bin'))
        .thenAnswer((_) async => Uint8List.fromList([0xFF, 0xFE, 0xFD]));

    await tester.pumpWidget(
        _wrap(FileViewerScreen(path: 'data.bin', repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text("can't preview this file type"), findsOneWidget);
  });

  testWidgets('shows a too-large message instead of decoding a huge file',
      (tester) async {
    final hugeBytes = Uint8List(11 * 1024 * 1024); // 11 MB, over the 10 MB cap
    when(() => repo.readFile('huge.log')).thenAnswer((_) async => hugeBytes);

    await tester.pumpWidget(
        _wrap(FileViewerScreen(path: 'huge.log', repository: repo)));
    await tester.pumpAndSettle();

    expect(find.textContaining('too large'), findsOneWidget);
  });
}
