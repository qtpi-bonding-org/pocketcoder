import 'dart:convert';

/// The public trust anchor used to validate a deployment's internal TLS.
///
/// This intentionally contains no private-key material.
final class CaddyCaPin {
  const CaddyCaPin({required this.fingerprint, required this.certificatePem});

  final String fingerprint;
  final String certificatePem;

  Map<String, dynamic> toJson() => {
        'fingerprint': fingerprint,
        'certificatePem': certificatePem,
      };

  factory CaddyCaPin.fromJson(Map<String, dynamic> json) => CaddyCaPin(
        fingerprint: json['fingerprint'] as String,
        certificatePem: json['certificatePem'] as String,
      );

  /// Parses the exact JSON document emitted by `export-ca-fingerprint`.
  factory CaddyCaPin.fromExportJson(Map<String, dynamic> json) => CaddyCaPin(
        fingerprint: json['fingerprint'] as String,
        certificatePem: utf8.decode(
          base64.decode(json['certificatePemBase64'] as String),
        ),
      );
}
