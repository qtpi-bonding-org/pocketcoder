import 'package:dio/dio.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';

/// Refreshes the PocketCoder session once after a 401 response.
///
/// All 401s trigger the shared refresh attempt. Only safe requests are
/// replayed automatically; mutations must explicitly opt into replay with
/// [idempotentMarker].
class AuthRetryInterceptor extends Interceptor {
  AuthRetryInterceptor(this._dio);

  static const retryMarker = 'pocketcoder.authRetry';
  static const idempotentMarker = 'pocketcoder.idempotent';

  final Dio _dio;
  Future<AuthRefreshResult> Function()? _refresh;

  void setRefreshCallback(Future<AuthRefreshResult> Function() refresh) {
    _refresh = refresh;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        request.extra[retryMarker] == true ||
        _refresh == null) {
      handler.next(err);
      return;
    }

    final refreshResult = await _refresh!();
    if (refreshResult != AuthRefreshResult.refreshed || !canReplay(request)) {
      handler.next(err);
      return;
    }

    try {
      final response = await _dio.fetch<dynamic>(
        request.copyWith(
          extra: {
            ...request.extra,
            retryMarker: true,
          },
        ),
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  static bool canReplay(RequestOptions request) {
    final method = request.method.toUpperCase();
    return method == 'GET' ||
        method == 'HEAD' ||
        request.extra[idempotentMarker] == true;
  }
}
