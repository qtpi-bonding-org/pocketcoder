import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// A package:http client whose trust anchor can be replaced for a deployment.
final class CaddyCaPinningHttpClient extends http.BaseClient {
  http.Client _delegate = http.Client();
  bool _closed = false;

  /// Trust only the supplied internal CA certificate for subsequent requests.
  void updatePin(String certificatePem) {
    _ensureOpen();
    final context = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(utf8.encode(certificatePem));
    final replacement = IOClient(HttpClient(context: context));
    final previous = _delegate;
    _delegate = replacement;
    previous.close();
  }

  /// Return to normal platform/system certificate trust.
  void clearPin() {
    _ensureOpen();
    final replacement = http.Client();
    final previous = _delegate;
    _delegate = replacement;
    previous.close();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    _ensureOpen();
    return _delegate.send(request);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _delegate.close();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('HTTP client is closed');
  }
}
