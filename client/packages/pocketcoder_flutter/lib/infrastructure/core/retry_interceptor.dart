import 'dart:async';

import 'package:dio/dio.dart';

/// Retries only safe GET requests after transient transport/server failures.
/// Mutations are deliberately left to their repositories.
class SafeGetRetryInterceptor extends Interceptor {
  SafeGetRetryInterceptor(
    this._dio, {
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 250),
  });

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;

  static const _retryCountKey = 'pocketcoder.retryCount';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (request.method.toUpperCase() != 'GET' ||
        !isTransient(err) ||
        maxRetries <= 0) {
      handler.next(err);
      return;
    }

    final attempt = request.extra[_retryCountKey] as int? ?? 0;
    if (attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(Duration(
      milliseconds: baseDelay.inMilliseconds * (1 << attempt),
    ));

    try {
      final response = await _dio.fetch<dynamic>(
        request.copyWith(
          extra: {
            ...request.extra,
            _retryCountKey: attempt + 1,
          },
        ),
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  static bool isTransient(DioException error) {
    final status = error.response?.statusCode;
    if (status != null) {
      return status == 408 || status == 425 || status == 429 || status >= 500;
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      _ => false,
    };
  }
}
