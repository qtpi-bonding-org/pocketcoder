import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/release/i_release_content_service.dart';

@LazySingleton(as: IReleaseContentService)
class ReleaseContentService implements IReleaseContentService {
  ReleaseContentService(
    this._http,
    this._storage,
    @Named('releaseBaseUrl') this._baseUrl,
    @Named('releaseRootPublicKey') this._rootPublicKey,
  );

  static const _maximumManifestBytes = 1024 * 1024;
  static const _maximumMetadataBytes = 256 * 1024;
  static const _stableFloor = 1;
  static const _appContractVersion = 1;

  final http.Client _http;
  final FlutterSecureStorage _storage;
  final String _baseUrl;
  final String _rootPublicKey;
  final Ed25519 _ed25519 = Ed25519();

  @override
  Future<VerifiedRelease> resolve({String channel = 'stable'}) {
    return tryMethod(() async {
      if (!const {'stable', 'beta', 'nightly'}.contains(channel)) {
        throw const ReleaseContentException('Unsupported release channel');
      }
      if (_rootPublicKey.isEmpty) {
        throw const ReleaseContentException(
            'Release trust root is not configured');
      }

      final delegationBytes = await _getBounded(
        Uri.parse('$_baseUrl/delegations/root.json'),
        _maximumMetadataBytes,
      );
      final delegationEnvelope = await _getJson(
        Uri.parse('$_baseUrl/delegations/root.json.sig'),
        16 * 1024,
      );
      final delegation = _decodeObject(delegationBytes);
      await _verifyEnvelope(
        payload: delegationBytes,
        envelope: delegationEnvelope,
        expectedRole: 'root',
        expectedKeyId: _string(delegation['rootKeyId']),
        publicKeyDer: base64Decode(_rootPublicKey),
      );
      if (delegation['schemaVersion'] != 1) {
        throw const ReleaseContentException('Unsupported root delegation');
      }
      final delegationSequence = _positiveInteger(delegation['sequence']);
      final persistedDelegation = await _readSequence('delegation');
      if (delegationSequence < persistedDelegation) {
        throw const ReleaseContentException(
            'Replayed root delegation rejected');
      }

      final pointerBytes = await _getBounded(
        Uri.parse('$_baseUrl/channels/$channel.json'),
        _maximumMetadataBytes,
      );
      final pointer = _decodeObject(pointerBytes);
      final pointerSignature = _object(pointer['signature']);
      final pointerSignatureUri = _allowlistedUri(
        pointerSignature['url'],
        RegExp('/channels/$channel/[1-9][0-9]*[.]sig\$'),
      );
      final pointerEnvelope = await _getJson(pointerSignatureUri, 16 * 1024);
      _validateSignatureDescriptor(pointerSignature, pointerEnvelope);
      await _verifyDelegated(
        payload: pointerBytes,
        envelope: pointerEnvelope,
        delegation: delegation,
        role: 'channel',
      );

      if (pointer['channel'] != channel) {
        throw const ReleaseContentException('Release channel does not match');
      }
      final sequence = _positiveInteger(pointer['sequence']);
      final persisted = await _readSequence('channel-$channel');
      final floor = channel == 'stable' && persisted < _stableFloor
          ? _stableFloor
          : persisted;
      if (sequence < floor) {
        throw const ReleaseContentException(
            'Replayed release channel rejected');
      }

      final manifestDescriptor = _object(pointer['manifest']);
      final digest = _string(manifestDescriptor['sha256']);
      final declaredBytes =
          _positiveInteger(manifestDescriptor['downloadBytes']);
      if (declaredBytes > _maximumManifestBytes) {
        throw const ReleaseContentException('Release manifest is too large');
      }
      final manifestUri = _allowlistedUri(
        manifestDescriptor['url'],
        RegExp('/releases/$digest[.]json\$'),
      );
      final manifestBytes = await _getBounded(manifestUri, declaredBytes);
      if (manifestBytes.length != declaredBytes ||
          sha256.convert(manifestBytes).toString() != digest) {
        throw const ReleaseContentException(
            'Release manifest identity mismatch');
      }
      final manifestSignature = _object(manifestDescriptor['signature']);
      final manifestEnvelope = await _getJson(
        _allowlistedUri(
          manifestSignature['url'],
          RegExp('/releases/$digest[.]json[.]sig\$'),
        ),
        16 * 1024,
      );
      _validateSignatureDescriptor(manifestSignature, manifestEnvelope);
      await _verifyDelegated(
        payload: manifestBytes,
        envelope: manifestEnvelope,
        delegation: delegation,
        role: 'release',
      );
      final manifest = _decodeObject(manifestBytes);
      if (manifest['schemaVersion'] != 1) {
        throw const ReleaseContentException('Unsupported release manifest');
      }
      _validateManifestForApp(manifest);

      final revocationsBytes = await _getBounded(
        Uri.parse('$_baseUrl/revocations/releases.json'),
        _maximumMetadataBytes,
      );
      final revocations = _decodeObject(revocationsBytes);
      final revocationSequence = _positiveInteger(revocations['sequence']);
      final persistedRevocation = await _readSequence('revocation');
      if (revocationSequence < persistedRevocation) {
        throw const ReleaseContentException('Replayed revocations rejected');
      }
      final revocationEnvelope = await _getJson(
        Uri.parse('$_baseUrl/revocations/releases/$revocationSequence.sig'),
        16 * 1024,
      );
      await _verifyDelegated(
        payload: revocationsBytes,
        envelope: revocationEnvelope,
        delegation: delegation,
        role: 'revocation',
      );
      final revoked = _object(revocations['revokedReleases']);
      if (revoked.containsKey(digest)) {
        throw const ReleaseContentException('The selected release is revoked');
      }

      await _writeSequence('channel-$channel', sequence);
      await _writeSequence('revocation', revocationSequence);
      await _writeSequence('delegation', delegationSequence);
      return VerifiedRelease(
        channel: channel,
        sequence: sequence,
        revocationSequence: revocationSequence,
        digest: digest,
        manifest: manifest,
      );
    }, ReleaseContentException.new, 'resolveRelease');
  }

  @override
  Future<Uint8List> fetchDocument(
    VerifiedRelease release,
    String documentId,
  ) {
    return tryMethod(() async {
      final documents = _object(release.manifest['documents']);
      final descriptor = _object(documents[documentId]);
      final digest = _string(descriptor['sha256']);
      final bytes = _positiveInteger(descriptor['downloadBytes']);
      final uri = _allowlistedUri(
        descriptor['url'],
        RegExp('/documents/$digest[.](json|txt|sh|go)\$'),
      );
      final body = await _getBounded(uri, bytes);
      if (body.length != bytes || sha256.convert(body).toString() != digest) {
        throw const ReleaseContentException(
            'Release document identity mismatch');
      }
      return body;
    }, ReleaseContentException.new, 'fetchReleaseDocument');
  }

  Future<void> _verifyDelegated({
    required Uint8List payload,
    required Map<String, dynamic> envelope,
    required Map<String, dynamic> delegation,
    required String role,
  }) async {
    final keyId = _string(envelope['keyId']);
    final revoked = _list(delegation['revokedKeyIds']).cast<String>();
    if (revoked.contains(keyId)) {
      throw const ReleaseContentException('Release signing key is revoked');
    }
    final roles = _object(delegation['roles']);
    final now = DateTime.now().toUtc();
    Map<String, dynamic>? selected;
    for (final value in _list(roles[role])) {
      final key = _object(value);
      final from = DateTime.tryParse(_string(key['validFrom']));
      final untilValue = key['validUntil'];
      final until =
          untilValue == null ? null : DateTime.tryParse(_string(untilValue));
      if (key['keyId'] == keyId &&
          from != null &&
          !now.isBefore(from) &&
          (until == null || !now.isAfter(until))) {
        selected = key;
        break;
      }
    }
    final key = selected;
    if (key == null) {
      throw const ReleaseContentException('No active delegated signing key');
    }
    await _verifyEnvelope(
      payload: payload,
      envelope: envelope,
      expectedRole: role,
      publicKeyDer: base64Decode(_string(key['publicKey'])),
    );
  }

  void _validateSignatureDescriptor(
    Map<String, dynamic> descriptor,
    Map<String, dynamic> envelope,
  ) {
    if (descriptor['algorithm'] != 'ed25519' ||
        envelope['algorithm'] != descriptor['algorithm'] ||
        envelope['keyId'] != descriptor['keyId']) {
      throw const ReleaseContentException(
        'Release signature descriptor does not match its envelope',
      );
    }
  }

  void _validateManifestForApp(Map<String, dynamic> manifest) {
    final sourceCommit = _string(manifest['sourceCommit']);
    final platform = _object(manifest['platform']);
    final compatibility = _object(manifest['compatibility']);
    final app = _object(compatibility['app']);
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sourceCommit) ||
        platform['os'] != 'linux' ||
        platform['architecture'] != 'amd64' ||
        app['contractVersion'] != _appContractVersion ||
        _positiveInteger(manifest['dataVersion']) < 1 ||
        _object(manifest['documents']).isEmpty ||
        _object(manifest['osImages']).isEmpty) {
      throw const ReleaseContentException(
        'Release is incompatible with this app',
      );
    }
  }

  Future<void> _verifyEnvelope({
    required Uint8List payload,
    required Map<String, dynamic> envelope,
    required String expectedRole,
    required Uint8List publicKeyDer,
    String? expectedKeyId,
  }) async {
    if (envelope['schemaVersion'] != 1 ||
        envelope['algorithm'] != 'ed25519' ||
        envelope['role'] != expectedRole ||
        (expectedKeyId != null && envelope['keyId'] != expectedKeyId) ||
        envelope['payloadSha256'] != sha256.convert(payload).toString()) {
      throw const ReleaseContentException('Invalid release signature envelope');
    }
    if (publicKeyDer.length < 32) {
      throw const ReleaseContentException('Invalid release public key');
    }
    final rawKey = publicKeyDer.sublist(publicKeyDer.length - 32);
    final valid = await _ed25519.verify(
      payload,
      signature: Signature(
        base64Decode(_string(envelope['signature'])),
        publicKey: SimplePublicKey(rawKey, type: KeyPairType.ed25519),
      ),
    );
    if (!valid) {
      throw const ReleaseContentException(
          'Release signature verification failed');
    }
  }

  Future<Uint8List> _getBounded(Uri uri, int maximumBytes) async {
    final request = http.Request('GET', uri);
    final response = await _http.send(request);
    if (response.statusCode != 200) {
      throw ReleaseContentException(
          'Release service returned ${response.statusCode}');
    }
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in response.stream) {
      length += chunk.length;
      if (length > maximumBytes) {
        throw const ReleaseContentException(
            'Release response exceeds its bound');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, int maximumBytes) async =>
      _decodeObject(await _getBounded(uri, maximumBytes));

  Uri _allowlistedUri(Object? value, RegExp pathPattern) {
    final uri = Uri.tryParse(_string(value));
    final base = Uri.parse(_baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != base.host ||
        !uri.path.startsWith('${base.path}/') ||
        !pathPattern.hasMatch(uri.path)) {
      throw const ReleaseContentException('Release URL is not allowlisted');
    }
    return uri;
  }

  Future<int> _readSequence(String name) async {
    final value = await _storage.read(key: 'release-sequence-$name');
    return int.tryParse(value ?? '') ?? 0;
  }

  Future<void> _writeSequence(String name, int value) =>
      _storage.write(key: 'release-sequence-$name', value: '$value');

  Map<String, dynamic> _decodeObject(Uint8List bytes) =>
      _object(jsonDecode(utf8.decode(bytes)));

  Map<String, dynamic> _object(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const ReleaseContentException('Expected a release object');
  }

  List<dynamic> _list(Object? value) {
    if (value is List<dynamic>) return value;
    throw const ReleaseContentException('Expected a release list');
  }

  String _string(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    throw const ReleaseContentException('Expected release text');
  }

  int _integer(Object? value) {
    if (value is int && value >= 0) return value;
    throw const ReleaseContentException('Expected a release integer');
  }

  int _positiveInteger(Object? value) {
    final result = _integer(value);
    if (result > 0) return result;
    throw const ReleaseContentException('Expected positive release integer');
  }
}
