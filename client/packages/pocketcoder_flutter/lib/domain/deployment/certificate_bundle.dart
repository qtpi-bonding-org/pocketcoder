import 'dart:convert';
import 'dart:typed_data';

final class CertificateBundle {
  const CertificateBundle({
    required this.hostname,
    this.issuer,
    required this.certificatePem,
    required this.privateKeyPem,
  });

  final String hostname;
  final String? issuer;
  final String certificatePem;
  final String privateKeyPem;

  factory CertificateBundle.fromJson(Map<String, dynamic> json) {
    final hostname = json['hostname'] as String? ?? '';
    final cert = _decode(json['certificatePemBase64'] as String?);
    final key = _decode(json['privateKeyPemBase64'] as String?);
    if (hostname.isEmpty || cert.isEmpty || key.isEmpty) {
      throw const FormatException('Incomplete Caddy certificate bundle');
    }
    return CertificateBundle(
      hostname: hostname,
      issuer: json['issuer'] as String?,
      certificatePem: cert,
      privateKeyPem: key,
    );
  }

  Map<String, dynamic> toJson() => {
    'hostname': hostname,
    if (issuer != null) 'issuer': issuer,
    'certificatePemBase64': base64Encode(utf8.encode(certificatePem)),
    'privateKeyPemBase64': base64Encode(utf8.encode(privateKeyPem)),
  };

  static String _decode(String? value) {
    if (value == null || value.isEmpty) return '';
    try {
      return utf8.decode(base64Decode(value));
    } on FormatException {
      return '';
    }
  }

  Uint8List get encodedJson =>
      Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
}
