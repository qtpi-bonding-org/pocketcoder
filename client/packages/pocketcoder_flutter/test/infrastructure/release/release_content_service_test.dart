import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketcoder_flutter/domain/release/i_release_content_service.dart';
import 'package:pocketcoder_flutter/infrastructure/release/release_content_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('selects bounded metadata and verifies a document digest', () async {
    final fixture = await _Fixture.create();
    final service = fixture.service();
    final release = await service.resolve();
    expect(release.digest, fixture.digest);
    expect(utf8.decode(await service.fetchDocument(release, 'walkthrough')),
        'hello from poco');
  });
  test('retries a 404 once with a cache-busting query', () async {
    final fixture = await _Fixture.create();
    var requests = 0;
    Uri? retryUri;
    final service = fixture.service(client: MockClient((request) async {
      requests++;
      if (requests == 1) {
        return http.Response('not published yet', 404);
      }
      if (requests == 2) retryUri = request.url;
      final body = fixture.routes[request.url.path];
      return body == null
          ? http.Response('missing', 404)
          : http.Response.bytes(body, 200);
    }));

    final release = await service.resolve();

    expect(release.digest, fixture.digest);
    expect(requests, 4);
    expect(retryUri?.queryParameters['_refresh'], isNotEmpty);
  });
  test('rejects a replayed pointer', () async {
    final fixture = await _Fixture.create();
    FlutterSecureStorage.setMockInitialValues(
        {'release-sequence-channel-stable': '2'});
    expect(
        fixture.service().resolve(), throwsA(isA<ReleaseContentException>()));
  });
  test('rejects a revoked selection', () async {
    final fixture = await _Fixture.create(revoked: true);
    expect(
        fixture.service().resolve(), throwsA(isA<ReleaseContentException>()));
  });
  test('rejects changed manifest bytes', () async {
    final fixture = await _Fixture.create(tampered: true);
    expect(
        fixture.service().resolve(), throwsA(isA<ReleaseContentException>()));
  });

  group('useTestingChannel', () {
    test('false (the default) still fetches the plain channel path',
        () async {
      final fixture = await _Fixture.create();
      final service = fixture.service();

      final release = await service.resolve();

      expect(release.digest, fixture.digest);
      expect(fixture.requestedPaths, contains('/v1/channels/stable.json'));
      expect(fixture.requestedPaths,
          isNot(contains('/v1/channels/stable-testing.json')));
    });

    test('true fetches the -testing path, and still verifies against the '
        "pointer's unqualified channel field", () async {
      final fixture = await _Fixture.create(testingVariant: true);
      final service = fixture.service(useTestingChannel: true);

      final release = await service.resolve();

      expect(release.digest, fixture.digest);
      expect(fixture.requestedPaths,
          contains('/v1/channels/stable-testing.json'));
      expect(fixture.requestedPaths,
          isNot(contains('/v1/channels/stable.json')));
    });

    test('still rejects a pointer whose channel field does not match, even '
        'on the testing path', () async {
      final fixture = await _Fixture.create(
          testingVariant: true, mismatchedChannelField: true);

      expect(
        fixture.service(useTestingChannel: true).resolve(),
        throwsA(isA<ReleaseContentException>()),
      );
    });
  });
}

class _Fixture {
  _Fixture(this.routes, this.digest);
  final Map<String, Uint8List> routes;
  final String digest;
  final requestedPaths = <String>[];
  static const base = 'https://images.relay.pocketcoder.org/v1';
  ReleaseContentService service(
          {http.Client? client, bool useTestingChannel = false}) =>
      ReleaseContentService(
          client ??
              MockClient((request) async {
                requestedPaths.add(request.url.path);
                final body = routes[request.url.path];
                return body == null
                    ? http.Response('missing', 404)
                    : http.Response.bytes(body, 200);
              }),
          const FlutterSecureStorage(),
          base,
          useTestingChannel);
  static Future<_Fixture> create(
      {bool revoked = false,
      bool tampered = false,
      bool testingVariant = false,
      bool mismatchedChannelField = false}) async {
    final document = Uint8List.fromList(utf8.encode('hello from poco'));
    final documentDigest = sha256.convert(document).toString();
    final manifest = Uint8List.fromList(utf8.encode(jsonEncode({
      'schemaVersion': 1,
      'sourceCommit': '0123456789abcdef0123456789abcdef01234567',
      'platform': {'os': 'linux', 'architecture': 'amd64'},
      'dataVersion': 1,
      'compatibility': {
        'app': {'contractVersion': 1}
      },
      'documents': {
        'walkthrough': {
          'url': '$base/documents/$documentDigest.txt',
          'sha256': documentDigest,
          'downloadBytes': document.length
        }
      },
      'osImages': {'nixos': {}}
    })));
    final digest = sha256.convert(manifest).toString();
    final served = tampered ? Uint8List.fromList([...manifest, 32]) : manifest;
    Uint8List json(Map<String, dynamic> value) =>
        Uint8List.fromList(utf8.encode(jsonEncode(value)));
    // The server writes the testing-path pointer's own "channel" field as
    // the base name ("stable"), same as the real production pointer -- only
    // the file's path carries the "-testing" suffix. mismatchedChannelField
    // simulates a corrupted/wrong pointer to prove that identity check still
    // runs on the testing path, not just the production one.
    final pathSegment = testingVariant ? 'stable-testing' : 'stable';
    final pointer = json({
      'schemaVersion': 1,
      'channel': mismatchedChannelField ? 'not-stable' : 'stable',
      'sequence': 1,
      'promotedAt': '2026-08-12T20:00:00Z',
      'attestation': {
        'url': '$base/attestations/channels/$pathSegment/1.sigstore.json',
        'downloadBytes': 1
      },
      'manifest': {
        'url': '$base/releases/$digest.json',
        'sha256': digest,
        'downloadBytes': served.length,
        'attestation': {
          'url': '$base/attestations/releases/$digest.sigstore.json',
          'downloadBytes': 1
        }
      }
    });
    final revocations = json({
      'schemaVersion': 1,
      'sequence': 1,
      'publishedAt': '2026-08-12T20:00:00Z',
      'revokedReleases': revoked ? {digest: {}} : <String, dynamic>{}
    });
    return _Fixture({
      '/v1/channels/$pathSegment.json': pointer,
      '/v1/releases/$digest.json': served,
      '/v1/revocations/releases.json': revocations,
      '/v1/documents/$documentDigest.txt': document
    }, digest);
  }
}
