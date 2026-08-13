import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';

void main() {
  test('Flutter operation inventory has one entry per custom operation', () {
    final actual = {
      ...ApiEndpoints.staticRoutes,
      ...ApiEndpoints.dynamicRoutes,
    };

    expect(actual, hasLength(25));
    expect(actual.every(ApiEndpoints.isCustomEndpoint), isTrue);
  });
}
