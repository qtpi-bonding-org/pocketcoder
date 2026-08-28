import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_cubit.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/domain/models/file_tree_entry.dart';

class MockFilesRepository extends Mock implements IFilesRepository {}

// A small fixture tree navigated by every test below:
//   main.go
//   src/
//     a.go
//     internal/
//       b.go
const _tree = [
  FileTreeEntry(name: 'main.go', isDir: false, size: 10, modTime: '2026-01-01'),
  FileTreeEntry(
    name: 'src',
    isDir: true,
    children: [
      FileTreeEntry(name: 'a.go', isDir: false, size: 5, modTime: '2026-01-01'),
      FileTreeEntry(
        name: 'internal',
        isDir: true,
        children: [
          FileTreeEntry(name: 'b.go', isDir: false, size: 3, modTime: '2026-01-01'),
        ],
      ),
    ],
  ),
];

void main() {
  late MockFilesRepository repo;
  FileBrowserCubit? lastCubit;

  FileBrowserCubit buildCubit() {
    final cubit = FileBrowserCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockFilesRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('FileBrowserCubit.open', () {
    test('fetches the whole tree once and lists entries at the given path',
        () async {
      when(() => repo.listFileTree('')).thenAnswer((_) async => _tree);
      final cubit = buildCubit();

      await cubit.open('src');

      expect(cubit.state.status, UiFlowStatus.success);
      expect(cubit.state.path, 'src');
      expect(cubit.state.entries, hasLength(2));
      expect(cubit.state.entries.map((e) => e.name), ['a.go', 'internal']);
      verify(() => repo.listFileTree('')).called(1);
    });

    test('reuses the already-fetched tree across a second open call -- '
        'exactly one network round trip covers every directory the user '
        'visits', () async {
      when(() => repo.listFileTree('')).thenAnswer((_) async => _tree);
      final cubit = buildCubit();

      await cubit.open('src');
      await cubit.open('');

      expect(cubit.state.path, '');
      expect(cubit.state.entries.map((e) => e.name), ['main.go', 'src']);
      verify(() => repo.listFileTree('')).called(1);
    });

    test('sets failure status when repository throws', () async {
      when(() => repo.listFileTree('')).thenThrow(Exception('boom'));
      final cubit = buildCubit();

      await cubit.open('src');

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error, isNotNull);
    });

    test('a path with no matching directory yields empty entries', () async {
      when(() => repo.listFileTree('')).thenAnswer((_) async => _tree);
      final cubit = buildCubit();

      await cubit.open('does-not-exist');

      expect(cubit.state.status, UiFlowStatus.success);
      expect(cubit.state.entries, isEmpty);
    });
  });

  group('FileBrowserCubit.navigateInto', () {
    test('appends the name to the current path and opens it', () async {
      when(() => repo.listFileTree('')).thenAnswer((_) async => _tree);
      final cubit = buildCubit();

      await cubit.open('src');
      await cubit.navigateInto('internal');

      expect(cubit.state.path, 'src/internal');
      expect(cubit.state.entries.map((e) => e.name), ['b.go']);
      verify(() => repo.listFileTree('')).called(1);
    });

    test('does not prefix with a slash when the current path is empty', () async {
      when(() => repo.listFileTree('')).thenAnswer((_) async => _tree);
      final cubit = buildCubit();

      await cubit.open('');
      await cubit.navigateInto('src');

      expect(cubit.state.path, 'src');
    });
  });

  group('FileBrowserCubit.navigateUp', () {
    test('strips the last path segment and reopens', () async {
      when(() => repo.listFileTree('')).thenAnswer((_) async => _tree);
      final cubit = buildCubit();

      await cubit.open('src/internal');
      await cubit.navigateUp();

      expect(cubit.state.path, 'src');
      expect(cubit.state.entries.map((e) => e.name), ['a.go', 'internal']);
      verify(() => repo.listFileTree('')).called(1);
    });

    test('is a no-op at the root path', () async {
      when(() => repo.listFileTree('')).thenAnswer((_) async => _tree);
      final cubit = buildCubit();

      await cubit.open('');
      await cubit.navigateUp();

      expect(cubit.state.path, '');
      verify(() => repo.listFileTree('')).called(1);
    });
  });
}
