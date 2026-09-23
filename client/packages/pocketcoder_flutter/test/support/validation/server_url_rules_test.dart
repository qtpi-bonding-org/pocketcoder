import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/support/validation/server_url_rules.dart';

void main() {
  test('http and https URLs with a host are valid, with or without a path', () {
    for (final url in [
      'https://192-155-89-165.sslip.io',
      'http://127.0.0.1:8090',
      'https://server.example.com/pb',
      'HTTPS://server.example.com',
    ]) {
      expect(serverUrlIssue(url), isNull, reason: url);
    }
  });

  test('a URL without http:// or https:// is missing its scheme', () {
    for (final url in [
      '192-155-89-165.sslip.io',
      'localhost:8090',
      'ftp://server.example.com',
    ]) {
      expect(serverUrlIssue(url), ServerUrlIssue.missingScheme, reason: url);
    }
  });

  test('a URL with a scheme but no usable host is invalid', () {
    for (final url in [
      'https://',
      'https:// server.example.com',
      'http://a b'
    ]) {
      expect(serverUrlIssue(url), ServerUrlIssue.invalid, reason: url);
    }
  });
}
