import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketcoder_flutter/domain/release/i_release_content_service.dart';
import 'package:pocketcoder_flutter/infrastructure/release/release_content_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('resolves signed metadata and verifies a bounded document', () async {
    final fixture = await _ReleaseFixture.create();
    final service = fixture.service();

    final release = await service.resolve();
    final document = await service.fetchDocument(release, 'walkthrough');
    final goDocument = await service.fetchDocument(release, 'walkthrough-go');

    expect(release.digest, fixture.manifestDigest);
    expect(release.sequence, 1);
    expect(utf8.decode(document), 'hello from poco');
    expect(utf8.decode(goDocument), 'package release');
  });

  test('rejects a replayed channel pointer', () async {
    final fixture = await _ReleaseFixture.create();
    FlutterSecureStorage.setMockInitialValues({
      'release-sequence-channel-stable': '2',
    });

    expect(
      fixture.service().resolve(),
      throwsA(isA<ReleaseContentException>()),
    );
  });

  test('rejects a revoked selected release', () async {
    final fixture = await _ReleaseFixture.create(revokeManifest: true);

    expect(
      fixture.service().resolve(),
      throwsA(isA<ReleaseContentException>()),
    );
  });

  test('rejects modified signed payload bytes', () async {
    final fixture = await _ReleaseFixture.create(tamperManifest: true);

    expect(
      fixture.service().resolve(),
      throwsA(isA<ReleaseContentException>()),
    );
  });

  test('rejects a signed manifest for a newer app contract', () async {
    final fixture = await _ReleaseFixture.create(appContractVersion: 2);

    expect(
      fixture.service().resolve(),
      throwsA(isA<ReleaseContentException>()),
    );
  });
}

class _ReleaseFixture {
  _ReleaseFixture({
    required this.routes,
    required this.rootPublicKey,
    required this.manifestDigest,
  });

  static const _baseUrl = 'https://images.pocketcoder.org/v1';
  static final _algorithm = Ed25519();

  final Map<String, Uint8List> routes;
  final String rootPublicKey;
  final String manifestDigest;

  ReleaseContentService service() {
    final client = MockClient((request) async {
      final body = routes[request.url.path];
      if (body == null) return http.Response('missing', 404);
      return http.Response.bytes(body, 200);
    });
    return ReleaseContentService(
      client,
      const FlutterSecureStorage(),
      _baseUrl,
      rootPublicKey,
    );
  }

  static Future<_ReleaseFixture> create({
    bool revokeManifest = false,
    bool tamperManifest = false,
    int appContractVersion = 1,
  }) async {
    final rootKey = await _algorithm.newKeyPair();
    final operationsKey = await _algorithm.newKeyPair();
    final rootPublic = await rootKey.extractPublicKey();
    final operationsPublic = await operationsKey.extractPublicKey();
    final rootDer = Uint8List.fromList([
      0x30,
      0x2a,
      0x30,
      0x05,
      0x06,
      0x03,
      0x2b,
      0x65,
      0x70,
      0x03,
      0x21,
      0x00,
      ...rootPublic.bytes,
    ]);
    final operationsDer = Uint8List.fromList([
      0x30,
      0x2a,
      0x30,
      0x05,
      0x06,
      0x03,
      0x2b,
      0x65,
      0x70,
      0x03,
      0x21,
      0x00,
      ...operationsPublic.bytes,
    ]);

    final delegation = _bytes({
      'schemaVersion': 1,
      'sequence': 1,
      'issuedAt': '2026-08-12T19:00:00Z',
      'rootKeyId': 'test-root',
      'roles': {
        for (final role in ['release', 'channel', 'metadata', 'revocation'])
          role: [
            {
              'keyId': 'test-operations',
              'algorithm': 'ed25519',
              'publicKey': base64Encode(operationsDer),
              'validFrom': '2020-01-01T00:00:00Z',
              'validUntil': null,
            },
          ],
      },
      'revokedKeyIds': <String>[],
    });
    final delegationEnvelope = await _envelope(
      delegation,
      rootKey,
      role: 'root',
      keyId: 'test-root',
    );

    final document = Uint8List.fromList(utf8.encode('hello from poco'));
    final documentDigest = sha256.convert(document).toString();
    final goDocument = Uint8List.fromList(utf8.encode('package release'));
    final goDocumentDigest = sha256.convert(goDocument).toString();
    final manifest = _bytes({
      'schemaVersion': 1,
      'serverVersion': '1.0.0',
      'sourceCommit': '0123456789abcdef0123456789abcdef01234567',
      'platform': {'os': 'linux', 'architecture': 'amd64'},
      'dataVersion': 1,
      'compatibility': {
        'app': {'contractVersion': appContractVersion},
      },
      'documents': {
        'walkthrough': {
          'url': '$_baseUrl/documents/$documentDigest.txt',
          'sha256': documentDigest,
          'downloadBytes': document.length,
        },
        'walkthrough-go': {
          'url': '$_baseUrl/documents/$goDocumentDigest.go',
          'sha256': goDocumentDigest,
          'downloadBytes': goDocument.length,
        },
      },
      'osImages': {
        'debian': {
          'delivery': {'kind': 'provider'},
          'bootstrap': {'kind': 'generated-config'},
        },
      },
    });
    final manifestDigest = sha256.convert(manifest).toString();
    final manifestEnvelope = await _envelope(
      manifest,
      operationsKey,
      role: 'release',
      keyId: 'test-operations',
    );
    final servedManifest =
        tamperManifest ? Uint8List.fromList([...manifest, 0x20]) : manifest;

    final pointer = _bytes({
      'schemaVersion': 1,
      'channel': 'stable',
      'sequence': 1,
      'manifest': {
        'url': '$_baseUrl/releases/$manifestDigest.json',
        'sha256': manifestDigest,
        'downloadBytes': servedManifest.length,
        'signature': {
          'algorithm': 'ed25519',
          'keyId': 'test-operations',
          'url': '$_baseUrl/releases/$manifestDigest.json.sig',
        },
      },
      'signature': {
        'algorithm': 'ed25519',
        'keyId': 'test-operations',
        'url': '$_baseUrl/channels/stable/1.sig',
      },
    });
    final pointerEnvelope = await _envelope(
      pointer,
      operationsKey,
      role: 'channel',
      keyId: 'test-operations',
    );

    final revocations = _bytes({
      'schemaVersion': 1,
      'sequence': 1,
      'issuedAt': '2026-08-12T19:00:00Z',
      'revokedReleases': revokeManifest
          ? {
              manifestDigest: {
                'reasonCode': 'test-release',
                'summary': 'This release is unsafe.',
                'revokedAt': '2026-08-12T19:00:00Z',
              },
            }
          : <String, Object>{},
    });
    final revocationEnvelope = await _envelope(
      revocations,
      operationsKey,
      role: 'revocation',
      keyId: 'test-operations',
    );

    return _ReleaseFixture(
      rootPublicKey: base64Encode(rootDer),
      manifestDigest: manifestDigest,
      routes: {
        '/v1/delegations/root.json': delegation,
        '/v1/delegations/root.json.sig': delegationEnvelope,
        '/v1/channels/stable.json': pointer,
        '/v1/channels/stable/1.sig': pointerEnvelope,
        '/v1/releases/$manifestDigest.json': servedManifest,
        '/v1/releases/$manifestDigest.json.sig': manifestEnvelope,
        '/v1/revocations/releases.json': revocations,
        '/v1/revocations/releases/1.sig': revocationEnvelope,
        '/v1/documents/$documentDigest.txt': document,
        '/v1/documents/$goDocumentDigest.go': goDocument,
      },
    );
  }

  static Uint8List _bytes(Map<String, Object?> value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(value)));

  static Future<Uint8List> _envelope(
    Uint8List payload,
    KeyPair keyPair, {
    required String role,
    required String keyId,
  }) async {
    final signature = await _algorithm.sign(payload, keyPair: keyPair);
    return _bytes({
      'schemaVersion': 1,
      'algorithm': 'ed25519',
      'role': role,
      'keyId': keyId,
      'payloadSha256': sha256.convert(payload).toString(),
      'signature': base64Encode(signature.bytes),
    });
  }
}
