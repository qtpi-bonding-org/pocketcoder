import 'package:injectable/injectable.dart';
import 'package:webcrypto/webcrypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

@singleton
class SecurityService {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const String _keyPairAlias = 'pocketcoder_device_key';

  SecurityService()
      : _storage = const FlutterSecureStorage(),
        _localAuth = LocalAuthentication();

  /// Generates a new ECDSA P-256 key pair
  /// Returns the JWK of the public key to send to current server
  Future<Map<String, dynamic>> generateAndStoreKeyPair() async {
    // Generate P-256 key pair
    final keyPair = await EcdsaPrivateKey.generateKey(EllipticCurve.p256);

    // Export keys as JWK
    final privateJwk = await keyPair.privateKey.exportJsonWebKey();
    final publicJwk = await keyPair.publicKey.exportJsonWebKey();

    // Store Private Key securely
    await _storage.write(
      key: _keyPairAlias,
      value: jsonEncode(privateJwk),
    );

    return publicJwk;
  }

  /// Signs data using the stored private key after local auth
  /// Throws exception if auth fails or key not found
  Future<String> signChallenge(String challenge) async {
    // 1. Authenticate User (FaceID/TouchID)
    final didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'Please authenticate to sign this action',
    );

    if (!didAuthenticate) {
      throw PlatformException(
          code: 'AUTH_FAILED', message: 'User verification failed');
    }

    // 2. Retrieve Private Key
    final privateKeyString = await _storage.read(key: _keyPairAlias);
    if (privateKeyString == null) {
      throw Exception('No device key found. Please register device.');
    }

    // 3. Import Key
    final privateJwk = jsonDecode(privateKeyString);
    final privateKey = await EcdsaPrivateKey.importJsonWebKey(
      privateJwk,
      EllipticCurve.p256,
    );

    // 4. Sign Data (SHA-256)
    final signatureBytes = await privateKey.signBytes(
      utf8.encode(challenge),
      Hash.sha256,
    );

    // Return Base64 Encoded Signature
    return base64Encode(signatureBytes);
  }

  /// Checks if a key pair exists on this device
  Future<bool> hasKey() async {
    return await _storage.containsKey(key: _keyPairAlias);
  }
}
