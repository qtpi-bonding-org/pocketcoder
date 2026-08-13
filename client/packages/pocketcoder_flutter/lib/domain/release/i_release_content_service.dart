import 'dart:typed_data';

class VerifiedRelease {
  const VerifiedRelease({
    required this.channel,
    required this.sequence,
    required this.revocationSequence,
    required this.digest,
    required this.manifest,
  });

  final String channel;
  final int sequence;
  final int revocationSequence;
  final String digest;
  final Map<String, dynamic> manifest;

  String get serverVersion => manifest['serverVersion'] as String? ?? '';
  int get dataVersion => manifest['dataVersion'] as int? ?? 0;
}

abstract interface class IReleaseContentService {
  Future<VerifiedRelease> resolve({String channel = 'stable'});

  Future<Uint8List> fetchDocument(
    VerifiedRelease release,
    String documentId,
  );
}

class ReleaseContentException implements Exception {
  const ReleaseContentException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'ReleaseContentException: $message';
}
