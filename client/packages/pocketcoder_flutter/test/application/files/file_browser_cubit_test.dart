import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_cubit.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';

class MockFilesRepository extends Mock implements IFilesRepository {}

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
    test('lists entries and sets path/status on success', () async {
      when(() => repo.listFiles('src')).thenAnswer((_) async => const [
            FileEntry(name: 'main.go', isDir: false, size: 10, modTime: ''),
          ]);
      final cubit = buildCubit();

      await cubit.open('src');

      expect(cubit.state.status, UiFlowStatus.success);
      expect(cubit.state.path, 'src');
      expect(cubit.state.entries, hasLength(1));
    });

    test('sets failure status when repository throws', () async {
      when(() => repo.listFiles('src')).thenThrow(Exception('boom'));
      final cubit = buildCubit();

      await cubit.open('src');

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error, isNotNull);
    });
  });

  group('FileBrowserCubit.navigateInto', () {
    test('appends the name to the current path and opens it', () async {
      when(() => repo.listFiles('src')).thenAnswer((_) async => const []);
      when(() => repo.listFiles('src/internal')).thenAnswer((_) async => const []);
      final cubit = buildCubit();

      await cubit.open('src');
      await cubit.navigateInto('internal');

      expect(cubit.state.path, 'src/internal');
      verify(() => repo.listFiles('src/internal')).called(1);
    });

    test('does not prefix with a slash when the current path is empty', () async {
      when(() => repo.listFiles('')).thenAnswer((_) async => const []);
      when(() => repo.listFiles('src')).thenAnswer((_) async => const []);
      final cubit = buildCubit();

      await cubit.open('');
      await cubit.navigateInto('src');

      expect(cubit.state.path, 'src');
    });
  });

  group('FileBrowserCubit.navigateUp', () {
    test('strips the last path segment and reopens', () async {
      when(() => repo.listFiles('src/internal')).thenAnswer((_) async => const []);
      when(() => repo.listFiles('src')).thenAnswer((_) async => const []);
      final cubit = buildCubit();

      await cubit.open('src/internal');
      await cubit.navigateUp();

      expect(cubit.state.path, 'src');
      verify(() => repo.listFiles('src')).called(1);
    });

    test('is a no-op at the root path', () async {
      when(() => repo.listFiles('')).thenAnswer((_) async => const []);
      final cubit = buildCubit();

      await cubit.open('');
      await cubit.navigateUp();

      expect(cubit.state.path, '');
      verify(() => repo.listFiles('')).called(1);
    });
  });
}
