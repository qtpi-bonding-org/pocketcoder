import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/files/files_repository.dart';

class MockPocketBase extends Mock implements PocketBase {}

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  late FilesRepository repo;
  late MockPocketBase pb;
  late MockHttpClient httpClient;
  late MockAuthStore authStore;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    pb = MockPocketBase();
    httpClient = MockHttpClient();
    authStore = MockAuthStore();
    when(() => pb.baseURL).thenReturn('http://pb.local:8090');
    when(() => pb.authStore).thenReturn(authStore);
    when(() => authStore.token).thenReturn('raw-token-value');
    repo = FilesRepository(pb, httpClient);
  });

  group('FilesRepository.listFiles', () {
    test('GETs files-list and maps entries', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/files-list/src',
            method: any(named: 'method'),
          )).thenAnswer((_) async => {
            'path': 'src',
            'entries': [
              {'name': 'main.go', 'isDir': false, 'size': 100, 'modTime': '2026-07-25T10:00:00Z'},
              {'name': 'internal', 'isDir': true, 'size': 0, 'modTime': ''},
            ],
          });

      final result = await repo.listFiles('src');

      expect(result, hasLength(2));
      expect(result[0].name, 'main.go');
      expect(result[1].isDir, isTrue);
      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/files-list/src',
            method: 'GET',
          )).called(1);
    });

    test('wraps failures in FilesException', () async {
      when(() => pb.send<dynamic>(any(), method: any(named: 'method')))
          .thenThrow(Exception('boom'));

      await expectLater(
        () => repo.listFiles('src'),
        throwsA(isA<FilesException>()),
      );
    });
  });

  group('FilesRepository.readFile', () {
    test('GETs the raw file endpoint with the auth token header, no Bearer prefix', () async {
      when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response.bytes([1, 2, 3], 200),
      );

      final result = await repo.readFile('main.go');

      expect(result, [1, 2, 3]);
      final captured = verify(() => httpClient.get(captureAny(), headers: captureAny(named: 'headers')))
          .captured;
      final uri = captured[0] as Uri;
      final headers = captured[1] as Map<String, String>;
      expect(uri.toString(), 'http://pb.local:8090/api/pocketcoder/files/main.go');
      expect(headers['Authorization'], 'raw-token-value');
    });

    test('wraps failures in FilesException', () async {
      when(() => httpClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('network down'));

      await expectLater(
        () => repo.readFile('main.go'),
        throwsA(isA<FilesException>()),
      );
    });

    test('throws FilesException on a non-2xx status instead of returning the error body', () async {
      when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response('Forbidden', 403),
      );

      await expectLater(
        () => repo.readFile('main.go'),
        throwsA(isA<FilesException>()),
      );
    });

    test('throws FilesException without making a request when the auth token is empty', () async {
      when(() => authStore.token).thenReturn('');

      await expectLater(
        () => repo.readFile('main.go'),
        throwsA(isA<FilesException>()),
      );
      verifyNever(() => httpClient.get(any(), headers: any(named: 'headers')));
    });
  });
}

class MockAuthStore extends Mock implements AuthStore {}
