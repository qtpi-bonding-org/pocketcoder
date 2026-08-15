import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/auth_retry_interceptor.dart';

import '../../helpers/capturing_dio_adapter.dart';

void main() {
  test('refreshes and replays a GET once after a 401', () async {
    var requests = 0;
    var refreshes = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://pb.local'))
      ..httpClientAdapter = CapturingDioAdapter((_, __) {
        requests++;
        return jsonResponse(
          requests == 1 ? {'error': 'expired'} : {'ok': true},
          statusCode: requests == 1 ? 401 : 200,
        );
      });
    final interceptor = AuthRetryInterceptor(dio)
      ..setRefreshCallback(() async {
        refreshes++;
        return AuthRefreshResult.refreshed;
      });
    dio.interceptors.add(interceptor);

    final response = await dio.get<void>('/health');

    expect(response.statusCode, 200);
    expect(requests, 2);
    expect(refreshes, 1);
  });

  test('refreshes but does not replay an unsafe mutation', () async {
    var requests = 0;
    var refreshes = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://pb.local'))
      ..httpClientAdapter = CapturingDioAdapter((_, __) {
        requests++;
        return jsonResponse({'error': 'expired'}, statusCode: 401);
      });
    final interceptor = AuthRetryInterceptor(dio)
      ..setRefreshCallback(() async {
        refreshes++;
        return AuthRefreshResult.refreshed;
      });
    dio.interceptors.add(interceptor);

    await expectLater(
      dio.post<void>('/mutate'),
      throwsA(isA<DioException>()),
    );

    expect(requests, 1);
    expect(refreshes, 1);
  });
}
