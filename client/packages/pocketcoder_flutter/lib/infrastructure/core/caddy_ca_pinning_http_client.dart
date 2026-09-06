import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_recovery.dart';

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
  String? _pinnedPem;
  http.Client _delegate = http.Client();
  final _pinChanges = StreamController<void>.broadcast();
  CaPinRecovery? _recovery;

  /// Wired in after the shared DI graph has been created -- CaPinRecovery
  /// depends on deployment-tracking state that isn't available yet at the
  /// point this singleton is constructed.
  void attachRecovery(CaPinRecovery recovery) {
    _recovery = recovery;
  }

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
    // A no-op call must not swap/close the delegate: that would abort any
    // request still in flight on it.
    if (certificatePem == _pinnedPem) return;
    logDebug('CaddyCaPinningHttpClient: updatePin (${certificatePem.length} '
        'byte PEM)');
    _pinnedPem = certificatePem;
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
    _pinnedPem = null;
    _context = null;
    final previous = _delegate;
    _delegate = http.Client();
    previous.close();
    _pinChanges.add(null);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    logDebug('CaddyCaPinningHttpClient: send', {
      'method': request.method,
      'url': request.url.toString(),
      'hasPin': _pinnedPem != null,
      'hasRecovery': _recovery != null,
    });
    try {
      final response = await _delegate.send(request);
      logDebug('CaddyCaPinningHttpClient: response', {
        'url': request.url.toString(),
        'statusCode': response.statusCode,
      });
      return response;
    } on Object catch (error, stackTrace) {
      final recovery = _recovery;
      final replay = request is http.Request ? _cloneRequest(request) : null;
      final isCertFailure = _isCertificateFailure(error);
      logDebug('CaddyCaPinningHttpClient: send threw', {
        'url': request.url.toString(),
        'errorType': error.runtimeType.toString(),
        'error': error.toString(),
        'isCertificateFailure': isCertFailure,
        'hasRecovery': recovery != null,
        'isReplayable': replay != null,
        'stackTrace': stackTrace.toString(),
      });
      if (recovery == null || replay == null || !isCertFailure) {
        rethrow;
      }
      // `recovered` alone can't drive the retry: an unchanged fingerprint
      // (recovered == false) still means updatePin() just installed a pin
      // the live client never had before, which alone justifies a retry.
      final hadPinBefore = _pinnedPem != null;
      final recovered = await recovery.recoverIfStale(requestUrl: request.url);
      final pinNowPresent = _pinnedPem != null;
      final shouldRetry = recovered || (!hadPinBefore && pinNowPresent);
      logDebug('CaddyCaPinningHttpClient: recoverIfStale result', {
        'url': request.url.toString(),
        'recovered': recovered,
        'hadPinBefore': hadPinBefore,
        'pinNowPresent': pinNowPresent,
        'shouldRetry': shouldRetry,
      });
      if (!shouldRetry) rethrow;
      logDebug('CaddyCaPinningHttpClient: retrying after CA-pin recovery',
          {'url': request.url.toString()});
      return _delegate.send(replay);
    }
  }

  /// A request object can only be sent once (`BaseRequest.finalize()`
  /// throws if called twice) -- retrying after recovery needs a fresh copy
  /// with the same method/url/headers/body, not the original object.
  /// Only `http.Request` (a fixed, re-readable byte body) is replayable
  /// this way; a `StreamedRequest`/`MultipartRequest`'s body is one-shot,
  /// so those are left to fail and succeed on the caller's own next call.
  static http.Request? _cloneRequest(http.Request original) {
    final clone = http.Request(original.method, original.url)
      ..headers.addAll(original.headers)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection
      ..bodyBytes = original.bodyBytes;
    return clone;
  }

  static bool _isCertificateFailure(Object error) =>
      error is HandshakeException || error is CertificateException;

  @override
  void close() {
    // PocketBase calls close() after every request; this is routine, not
    // spurious, so it's never actually closed.
    logDebug(
      'CaddyCaPinningHttpClient: close() called on the shared singleton '
      '-- ignoring (this client is never meant to be closed)',
    );
  }
}
