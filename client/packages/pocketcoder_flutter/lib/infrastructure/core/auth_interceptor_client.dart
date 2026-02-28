import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_aeroform/infrastructure/core/logger.dart';

class AuthInterceptorClient extends http.BaseClient {
  final http.Client _inner;
  final FlutterSecureStorage _storage;

  AuthInterceptorClient(this._inner, this._storage);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final seedStr = await _storage.read(key: 'ssh_private_seed');
      final fingerprint = await _storage.read(key: 'ssh_fingerprint');

      if (seedStr != null &&
          seedStr.isNotEmpty &&
          fingerprint != null &&
          fingerprint.isNotEmpty) {
        // 1. Generate Nonce & Time
        final uuid = const Uuid().v4();
        final timestampMs =
            DateTime.now().toUtc().millisecondsSinceEpoch.toString();

        // 2. Read Request Body for Signature
        String bodyString = '';
        if (request is http.Request) {
          bodyString = request.body;
        } else if (request is http.MultipartRequest) {
          // Note: Full multipart signing requires matching Go parsing logic.
          // Leaving it empty here to avoid signature breaking over boundary randomizations,
          // although technically less secure for file uploads.
        }

        // 3. Construct Payload to Sign
        final uri = request.url.path +
            (request.url.hasQuery ? '?${request.url.query}' : '');
        final payloadString = '$uri|$bodyString|$uuid|$timestampMs';
        final payloadBytes = utf8.encode(payloadString);

        // 4. Load key and sign
        final seedBytes = base64.decode(seedStr);
        final algorithm = Ed25519();

        final keyPair = await algorithm.newKeyPairFromSeed(seedBytes);

        final signature = await algorithm.sign(
          payloadBytes,
          keyPair: keyPair,
        );

        // 5. Attach X-PC headers so backend knows we authenticated as our device
        request.headers['X-PC-Signature'] = base64.encode(signature.bytes);
        request.headers['X-PC-Nonce'] = uuid;
        request.headers['X-PC-Timestamp'] = timestampMs;
        request.headers['X-PC-Fingerprint'] = fingerprint;
      }
    } catch (e, stack) {
      logError('AuthInterceptorClient: Failed to sign request: $e', e, stack);
    }

    return _inner.send(request);
  }
}
