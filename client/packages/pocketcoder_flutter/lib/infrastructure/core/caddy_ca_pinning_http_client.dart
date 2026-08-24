import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'logger.dart';

/// The app's single source of truth for a deployment's TLS trust state,
/// and a `package:http` client built on top of it.
///
/// **Structural rule: nothing in this app may build its own independent
/// `HttpClient`/`SecurityContext` to reach a deployment.** Every HTTP
/// stack that might ever talk to a deployment (or to anything else --
/// this is also the general-purpose client for Linode OAuth, the OAuth
/// relay, image relay, etc.) must derive its trust from [createHttpClient]
/// and, if it's not `package:http`-based (e.g. a `dio.Dio` client used by
/// generated OpenAPI clients), subscribe to [onPinChanged] and rebuild its
/// own transport from [createHttpClient] whenever it fires. Two
/// independently-constructed HTTP stacks that each decide their own trust
/// is exactly the bug this class exists to prevent: `PocketCoderApiClient`
/// used to build its own bare `Dio()` with no knowledge of any pin at
/// all, so it could never reach a deployment's self-signed cert
/// regardless of what this class's trust state was -- see
/// `PocketCoderApiClient.fromPocketBase` for how it now derives from this
/// class instead of maintaining separate trust.
///
/// Registered as an app-lifetime singleton (see `external_module.dart`).
/// Nothing in the app ever closes it at teardown either, so it is never
/// meant to be closed at all. [close] is deliberately a no-op: a consumer
/// holding an injected `http.Client` and calling `.close()` on it when
/// it's done -- normal, correct hygiene for a client it actually owns --
/// would otherwise brick HTTP for the rest of the app's process lifetime
/// for every other consumer, with no way back. Confirmed live: this broke
/// a fresh Linode OAuth attempt with `Bad state: HTTP client is closed`,
/// unrelated to whatever actually called close().
final class CaddyCaPinningHttpClient extends http.BaseClient {
  SecurityContext? _context;
  http.Client _delegate = http.Client();
  final _pinChanges = StreamController<void>.broadcast();

  /// Fires after [updatePin] or [clearPin] changes the trust state.
  /// Non-`package:http` transports (Dio, etc.) that derive their own
  /// client from [createHttpClient] must listen for this and rebuild
  /// their transport when it fires -- there is no other way for them to
  /// find out the pin changed.
  Stream<void> get onPinChanged => _pinChanges.stream;

  /// Builds a fresh [HttpClient] reflecting the CURRENT trust state (the
  /// pinned CA plus normal system trust, or just normal system trust if
  /// nothing is pinned). The single source other transports must derive
  /// their own trust from -- never construct a `SecurityContext`/
  /// `HttpClient` independently.
  HttpClient createHttpClient() => HttpClient(context: _context);

  /// Additionally trust the supplied internal CA certificate for
  /// subsequent requests, on top of normal system/platform trust.
  ///
  /// `withTrustedRoots: true` must be passed explicitly -- Dart's
  /// [SecurityContext] constructor defaults it to `false`. Getting this
  /// wrong (whether by passing `false` or simply omitting it) is not
  /// obviously wrong at a glance: this client is a shared, app-lifetime
  /// singleton used for every HTTP consumer in the app, including ones
  /// with nothing to do with any deployment (Linode OAuth, the OAuth
  /// relay, image relay, etc.), so an implicit `false` here silently
  /// discards normal system CA trust entirely the moment any deployment's
  /// pin is applied, breaking every one of those unrelated HTTPS calls
  /// app-wide for the rest of the process's life -- confirmed live, a
  /// Linode API call started failing with `HandshakeException:
  /// CERTIFICATE_VERIFY_FAILED` immediately after a deployment's pin was
  /// fetched and applied for the first time.
  void updatePin(String certificatePem) {
    logDebug('CaddyCaPinningHttpClient: updatePin (${certificatePem.length} '
        'byte PEM)');
    _context = SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificatesBytes(utf8.encode(certificatePem));
    final previous = _delegate;
    _delegate = IOClient(createHttpClient());
    previous.close();
    _pinChanges.add(null);
  }

  /// Return to normal platform/system certificate trust.
  void clearPin() {
    logDebug('CaddyCaPinningHttpClient: clearPin');
    _context = null;
    final previous = _delegate;
    _delegate = http.Client();
    previous.close();
    _pinChanges.add(null);
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
