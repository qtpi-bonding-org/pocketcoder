import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';

void main() {
  test('Flutter operation inventory matches the repository route manifest', () {
    final file = File('../../../api/pocketcoder-routes.json');
    final manifest =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final routes = manifest['routes'] as List<dynamic>;
    final expected = routes
        .map((route) => (route as Map<String, dynamic>)['path'] as String)
        .toSet();
    final actual = {
      ...ApiEndpoints.staticRoutes,
      ...ApiEndpoints.dynamicRoutes,
    };

    expect(actual, expected);
    expect(actual, hasLength(25));
  });
}
