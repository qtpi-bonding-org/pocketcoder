import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/release/i_release_content_service.dart';

/// Selects bounded release metadata for the UI. This is intentionally not a
/// release-authentication boundary: the image installer and native OS manager
/// verify GitHub Sigstore attestations before anything executes.
@LazySingleton(as: IReleaseContentService)
class ReleaseContentService implements IReleaseContentService {
  ReleaseContentService(
      this._http, this._storage, @Named('releaseBaseUrl') this._baseUrl);

  static const _maximumManifestBytes = 1024 * 1024;
  static const _maximumMetadataBytes = 256 * 1024;
  static const _stableFloor = 1;
  static const _appContractVersion = 1;
  final http.Client _http;
  final FlutterSecureStorage _storage;
  final String _baseUrl;

  @override
  Future<ReleaseSelection> resolve({String channel = 'stable'}) =>
      tryMethod(() async {
        if (!const {'stable', 'beta', 'nightly'}.contains(channel)) {
          throw const ReleaseContentException('Unsupported release channel');
        }
        final pointerBytes = await _getBounded(
            Uri.parse('$_baseUrl/channels/$channel.json'),
            _maximumMetadataBytes);
        final pointer = _decodeObject(pointerBytes);
        if (pointer['schemaVersion'] != 1 || pointer['channel'] != channel) {
          throw const ReleaseContentException(
              'Unsupported release channel pointer');
        }
        final sequence = _positiveInteger(pointer['sequence']);
        _allowlistedUri(
            _object(pointer['attestation'])['url'],
            RegExp(
                '/attestations/channels/$channel/[1-9][0-9]*[.]sigstore[.]json'
                r'$'));
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
            manifestDescriptor['url'], RegExp('/releases/$digest[.]json' r'$'));
        _allowlistedUri(_object(manifestDescriptor['attestation'])['url'],
            RegExp('/attestations/releases/$digest[.]sigstore[.]json' r'$'));
        final manifestBytes = await _getBounded(manifestUri, declaredBytes);
        if (manifestBytes.length != declaredBytes ||
            sha256.convert(manifestBytes).toString() != digest) {
          throw const ReleaseContentException(
              'Release manifest identity mismatch');
        }
        final manifest = _decodeObject(manifestBytes);
        if (manifest['schemaVersion'] != 1) {
          throw const ReleaseContentException('Unsupported release manifest');
        }
        _validateManifestForApp(manifest);
        final revocationsBytes = await _getBounded(
            Uri.parse('$_baseUrl/revocations/releases.json'),
            _maximumMetadataBytes);
        final revocations = _decodeObject(revocationsBytes);
        if (revocations['schemaVersion'] != 1) {
          throw const ReleaseContentException(
              'Unsupported release revocations');
        }
        final revocationSequence = _positiveInteger(revocations['sequence']);
        final persistedRevocation = await _readSequence('revocation');
        if (revocationSequence < persistedRevocation) {
          throw const ReleaseContentException('Replayed revocations rejected');
        }
        _allowlistedUri(
            '$_baseUrl/attestations/revocations/releases/$revocationSequence.sigstore.json',
            RegExp(
                '/attestations/revocations/releases/[1-9][0-9]*[.]sigstore[.]json'
                r'$'));
        if (_object(revocations['revokedReleases']).containsKey(digest)) {
          throw const ReleaseContentException(
              'The selected release is revoked');
        }
        await _writeSequence('channel-$channel', sequence);
        await _writeSequence('revocation', revocationSequence);
        return ReleaseSelection(
            channel: channel,
            sequence: sequence,
            revocationSequence: revocationSequence,
            digest: digest,
            manifest: manifest);
      }, ReleaseContentException.new, 'resolveRelease');

  @override
  Future<Uint8List> fetchDocument(
          ReleaseSelection release, String documentId) =>
      tryMethod(() async {
        final descriptor =
            _object(_object(release.manifest['documents'])[documentId]);
        final digest = _string(descriptor['sha256']);
        final bytes = _positiveInteger(descriptor['downloadBytes']);
        final uri = _allowlistedUri(descriptor['url'],
            RegExp('/documents/$digest[.](json|txt|sh|go)' r'$'));
        final body = await _getBounded(uri, bytes);
        if (body.length != bytes || sha256.convert(body).toString() != digest) {
          throw const ReleaseContentException(
              'Release document identity mismatch');
        }
        return body;
      }, ReleaseContentException.new, 'fetchReleaseDocument');

  void _validateManifestForApp(Map<String, dynamic> manifest) {
    final platform = _object(manifest['platform']);
    final app = _object(_object(manifest['compatibility'])['app']);
    if (!RegExp(r'^[0-9a-f]{40}$')
            .hasMatch(_string(manifest['sourceCommit'])) ||
        platform['os'] != 'linux' ||
        platform['architecture'] != 'amd64' ||
        app['contractVersion'] != _appContractVersion ||
        _positiveInteger(manifest['dataVersion']) < 1 ||
        _object(manifest['documents']).isEmpty ||
        _object(manifest['osImages']).isEmpty) {
      throw const ReleaseContentException(
          'Release is incompatible with this app');
    }
  }

  Future<Uint8List> _getBounded(Uri uri, int maximumBytes) async {
    final response = await _http.send(http.Request('GET', uri));
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

  Future<int> _readSequence(String name) async =>
      int.tryParse(await _storage.read(key: 'release-sequence-$name') ?? '') ??
      0;
  Future<void> _writeSequence(String name, int value) =>
      _storage.write(key: 'release-sequence-$name', value: '$value');
  Map<String, dynamic> _decodeObject(Uint8List bytes) =>
      _object(jsonDecode(utf8.decode(bytes)));
  Map<String, dynamic> _object(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const ReleaseContentException('Expected a release object');
  }

  String _string(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    throw const ReleaseContentException('Expected release text');
  }

  int _positiveInteger(Object? value) {
    if (value is int && value > 0) return value;
    throw const ReleaseContentException('Expected positive release integer');
  }
}
