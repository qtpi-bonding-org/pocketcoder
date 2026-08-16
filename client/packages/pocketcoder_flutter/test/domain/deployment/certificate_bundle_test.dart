import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/deployment/certificate_bundle.dart';

void main() {
  test('round trips a hostname-keyed certificate bundle', () {
    const bundle = CertificateBundle(
      hostname: '66-228-35-248.sslip.io',
      issuer: 'acme-v02.api.letsencrypt.org-directory',
      certificatePem: 'CERTIFICATE',
      privateKeyPem: 'PRIVATE KEY',
    );

    final decoded = CertificateBundle.fromJson(
      jsonDecode(jsonEncode(bundle.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.hostname, bundle.hostname);
    expect(decoded.issuer, bundle.issuer);
    expect(decoded.privateKeyPem, bundle.privateKeyPem);
  });

  test('rejects incomplete bundles', () {
    expect(
      () => CertificateBundle.fromJson({'hostname': 'example.sslip.io'}),
      throwsFormatException,
    );
  });
}
