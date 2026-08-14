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
}

class _Fixture {
  _Fixture(this.routes, this.digest);
  final Map<String, Uint8List> routes;
  final String digest;
  static const base = 'https://images.relay.pocketcoder.org/v1';
  ReleaseContentService service() =>
      ReleaseContentService(MockClient((request) async {
        final body = routes[request.url.path];
        return body == null
            ? http.Response('missing', 404)
            : http.Response.bytes(body, 200);
      }), const FlutterSecureStorage(), base);
  static Future<_Fixture> create(
      {bool revoked = false, bool tampered = false}) async {
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
    final pointer = json({
      'schemaVersion': 1,
      'channel': 'stable',
      'sequence': 1,
      'promotedAt': '2026-08-12T20:00:00Z',
      'attestation': {
        'url': '$base/attestations/channels/stable/1.sigstore.json',
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
      '/v1/channels/stable.json': pointer,
      '/v1/releases/$digest.json': served,
      '/v1/revocations/releases.json': revocations,
      '/v1/documents/$documentDigest.txt': document
    }, digest);
  }
}
