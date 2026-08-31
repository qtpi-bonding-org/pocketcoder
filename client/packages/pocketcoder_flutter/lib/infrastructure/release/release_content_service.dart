import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/release/i_image_relay_proof_provider.dart';
import 'package:pocketcoder_flutter/domain/release/i_release_content_service.dart';

/// Selects bounded release metadata for the UI. This is intentionally not a
/// release-authentication boundary: the image installer and native OS manager
/// verify GitHub Sigstore attestations before anything executes.
@LazySingleton(as: IReleaseContentService)
class ReleaseContentService implements IReleaseContentService {
  ReleaseContentService(
      this._http, this._storage, this._proofProvider,
      @Named('releaseBaseUrl') this._baseUrl,
      [@Named('useTestingChannel') this._useTestingChannel = false,
      @Named('releaseChannel') this._defaultChannel = 'stable']);

  static const _maximumManifestBytes = 1024 * 1024;
  static const _maximumMetadataBytes = 256 * 1024;
  static const _stableFloor = 1;
  static const _appContractVersion = 1;
  final http.Client _http;
  final FlutterSecureStorage _storage;
  final IImageRelayProofProvider _proofProvider;
  final String _baseUrl;
  final bool _useTestingChannel;
  final String _defaultChannel;

  @override
  Future<ReleaseSelection> resolve({String? channel}) => tryMethod(() async {
        // kReleaseMode is a second, independent guard on BOTH knobs below:
        // even if a debug-only dart-define somehow leaked into a release
        // build, a genuine `--release` build ignores it and only ever
        // fetches the real, non-testing 'stable' channel. The pointer's own
        // "channel" field always holds the unqualified name regardless of
        // which path served it, so identity verification below is
        // unaffected by this path choice.
        final resolvedChannel =
            kReleaseMode ? 'stable' : (channel ?? _defaultChannel);
        if (!const {'stable', 'beta', 'nightly'}.contains(resolvedChannel)) {
          throw const ReleaseContentException('Unsupported release channel');
        }
        final pathSegment = _useTestingChannel && !kReleaseMode
            ? '$resolvedChannel-testing'
            : resolvedChannel;
        final pointerBytes = await _getBounded(
            Uri.parse('$_baseUrl/channels/$pathSegment.json'),
            _maximumMetadataBytes);
        final pointer = _decodeObject(pointerBytes);
        if (pointer['schemaVersion'] != 1 ||
            pointer['channel'] != resolvedChannel) {
          throw const ReleaseContentException(
              'Unsupported release channel pointer');
        }
        final sequence = _positiveInteger(pointer['sequence']);
        _allowlistedUri(
            _object(pointer['attestation'])['url'],
            RegExp(
                '/attestations/channels/$pathSegment/[1-9][0-9]*[.]sigstore[.]json'
                r'$'));
        final persisted = await _readSequence('channel-$pathSegment');
        final floor = resolvedChannel == 'stable' && persisted < _stableFloor
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
        await _writeSequence('channel-$pathSegment', sequence);
        await _writeSequence('revocation', revocationSequence);
        return ReleaseSelection(
            channel: resolvedChannel,
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
    final credential = await _proofProvider.credential();
    var requestUri = uri;
    var retriedNotFound = false;
    late http.StreamedResponse response;
    while (true) {
      final proof = await _proofProvider.proof(
        method: 'GET',
        url: requestUri.toString(),
      );
      final request = http.Request('GET', requestUri)
        ..headers['Pocketcoder-Credential'] = credential
        ..headers['Pocketcoder-Proof'] = proof;
      response = await _http.send(request);
      if (response.statusCode != 404 || retriedNotFound) break;

      // Release metadata can briefly return 404 while the release service's
      // pointer/object cache catches up. Retry once without reusing a cached
      // response; all other HTTP errors remain terminal.
      retriedNotFound = true;
      requestUri = requestUri.replace(queryParameters: {
        ...requestUri.queryParameters,
        '_refresh': DateTime.now().microsecondsSinceEpoch.toString(),
      });
    }
    if (response.statusCode != 200) {
      throw ReleaseContentException(
        'Release service returned ${response.statusCode}',
        null,
        response.statusCode,
      );
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
