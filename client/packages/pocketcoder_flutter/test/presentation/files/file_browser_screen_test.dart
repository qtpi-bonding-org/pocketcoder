import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_cubit.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/files/file_browser_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockFileBrowserCubit extends Mock implements FileBrowserCubit {}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  late MockFileBrowserCubit cubit;

  setUp(() {
    cubit = MockFileBrowserCubit();
  });

  Widget buildTestable({void Function(BuildContext, String)? onOpenFile}) {
    return _wrap(
      BlocProvider<FileBrowserCubit>.value(
        value: cubit,
        child: FileBrowserScreen(onOpenFile: onOpenFile ?? (_, __) {}),
      ),
    );
  }

  testWidgets('renders entries as tappable rows', (tester) async {
    when(() => cubit.state).thenReturn(const FileBrowserState(
      status: UiFlowStatus.success,
      path: '',
      entries: [
        FileEntry(name: 'main.go', isDir: false, size: 10, modTime: ''),
        FileEntry(name: 'internal', isDir: true, size: 0, modTime: ''),
      ],
    ));
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('main.go'), findsOneWidget);
    expect(find.text('internal'), findsOneWidget);
  });

  testWidgets('tapping a directory row calls navigateInto', (tester) async {
    when(() => cubit.state).thenReturn(const FileBrowserState(
      status: UiFlowStatus.success,
      entries: [FileEntry(name: 'internal', isDir: true, size: 0, modTime: '')],
    ));
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.navigateInto(any())).thenAnswer((_) async {});

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('internal'));
    await tester.pumpAndSettle();

    verify(() => cubit.navigateInto('internal')).called(1);
  });

  testWidgets('tapping a file row invokes onOpenFile with the full path',
      (tester) async {
    when(() => cubit.state).thenReturn(const FileBrowserState(
      status: UiFlowStatus.success,
      path: 'src',
      entries: [
        FileEntry(name: 'main.go', isDir: false, size: 10, modTime: '')
      ],
    ));
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    String? openedPath;

    await tester
        .pumpWidget(buildTestable(onOpenFile: (_, path) => openedPath = path));
    await tester.pumpAndSettle();

    await tester.tap(find.text('main.go'));
    await tester.pumpAndSettle();

    expect(openedPath, 'src/main.go');
  });

  testWidgets('shows an empty-state message when entries is empty',
      (tester) async {
    when(() => cubit.state)
        .thenReturn(const FileBrowserState(status: UiFlowStatus.success));
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('NO FILES'), findsOneWidget);
  });
}
