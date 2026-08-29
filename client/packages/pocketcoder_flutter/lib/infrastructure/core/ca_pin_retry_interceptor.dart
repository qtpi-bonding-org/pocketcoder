import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_recovery.dart';

/// Recovers a Dio request that failed TLS validation against a stale
/// pinned CA, mirroring AuthRetryInterceptor's onError-then-fetch shape.
///
/// A handshake/certificate failure happens at the transport layer, before
/// any request reaches the server, so (unlike the 401 case) it's always
/// safe to replay regardless of HTTP method -- the one exception is a
/// request body that can only be read once (a `Stream`), which this skips.
class CaPinRetryInterceptor extends Interceptor {
  CaPinRetryInterceptor(this._dio);

  static const retryMarker = 'pocketcoder.caPinRetry';

  final Dio _dio;
  CaPinRecovery? _recovery;

  /// Wired in after the shared DI graph has been created -- CaPinRecovery
  /// depends on deployment-tracking state that isn't available yet at the
  /// point this interceptor is constructed.
  void attachRecovery(CaPinRecovery recovery) {
    _recovery = recovery;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final recovery = _recovery;
    if (recovery == null ||
        request.extra[retryMarker] == true ||
        !_isCertificateFailure(err) ||
        request.data is Stream) {
      handler.next(err);
      return;
    }

    final recovered =
        await recovery.recoverIfStale(requestUrl: request.uri);
    if (!recovered) {
      handler.next(err);
      return;
    }

    try {
      final response = await _dio.fetch<dynamic>(
        request.copyWith(extra: {...request.extra, retryMarker: true}),
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  static bool _isCertificateFailure(DioException err) {
    final error = err.error;
    return error is HandshakeException || error is CertificateException;
  }
}
