import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'logger.dart';

/// A package:http client whose trust anchor can be replaced for a deployment.
///
/// This is registered as an app-lifetime singleton (see `external_module.dart`)
/// and shared by every consumer that talks HTTP -- including ones with no
/// relation to any deployment, like Linode OAuth. Nothing in the app ever
/// closes it at teardown either, so it is never meant to be closed at all.
/// [close] is deliberately a no-op: a consumer holding an injected
/// `http.Client` and calling `.close()` on it when it's done -- normal,
/// correct hygiene for a client it actually owns -- would otherwise brick
/// HTTP for the rest of the app's process lifetime for every other consumer,
/// with no way back. Confirmed live: this broke a fresh Linode OAuth attempt
/// with `Bad state: HTTP client is closed`, unrelated to whatever actually
/// called close().
final class CaddyCaPinningHttpClient extends http.BaseClient {
  http.Client _delegate = http.Client();

  /// Trust only the supplied internal CA certificate for subsequent requests.
  void updatePin(String certificatePem) {
    logDebug('CaddyCaPinningHttpClient: updatePin (${certificatePem.length} '
        'byte PEM)');
    final context = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(utf8.encode(certificatePem));
    final replacement = IOClient(HttpClient(context: context));
    final previous = _delegate;
    _delegate = replacement;
    previous.close();
  }

  /// Return to normal platform/system certificate trust.
  void clearPin() {
    logDebug('CaddyCaPinningHttpClient: clearPin');
    final replacement = http.Client();
    final previous = _delegate;
    _delegate = replacement;
    previous.close();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    logDebug('CaddyCaPinningHttpClient: send',
        {'method': request.method, 'url': request.url.toString()});
    return _delegate.send(request);
  }

  @override
  void close() {
    // Deliberately not closing _delegate either -- see class doc. Logging
    // the caller's stack so a future spurious close() attempt is
    // identifiable instead of silent.
    logWarning(
      'CaddyCaPinningHttpClient: close() called on the shared singleton '
      '-- ignoring (this client is never meant to be closed)',
    );
    logDebug('CaddyCaPinningHttpClient: close() call site',
        {'stack': StackTrace.current.toString()});
  }
}
