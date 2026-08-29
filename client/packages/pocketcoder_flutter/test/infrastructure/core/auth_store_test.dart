import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/core/auth_store.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('restores persisted auth state during store construction', () async {
    const storage = FlutterSecureStorage();
    final expiry = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
    String encodePart(Map<String, Object> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = [
      encodePart({'alg': 'HS256', 'typ': 'JWT'}),
      encodePart({'exp': expiry}),
      'signature',
    ].join('.');
    await storage.write(
      key: 'pb_auth',
      value: jsonEncode({
        'token': token,
        'model': {
          'id': 'record-id',
          'collectionId': 'users',
          'collectionName': 'users',
          'username': 'test-user',
          'email': 'test@example.com',
        },
      }),
    );

    final config = AuthStoreConfig(storage);
    final authStore = await config.createAuthStore();

    expect(authStore.isValid, isTrue);
    expect(authStore.record?.id, 'record-id');
    expect(authStore.token, token);
  });
}