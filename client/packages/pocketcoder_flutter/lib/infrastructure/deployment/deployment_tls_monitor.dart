import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pocketcoder_flutter/domain/deployment/server_tls_status.dart';

/// Reads the same current status snapshot used by the rest of deployment
/// readiness. HTTP is intentional: it remains available while Caddy is still
/// obtaining the first certificate.
final class DeploymentTlsMonitor {
  const DeploymentTlsMonitor({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<ServerStatusSnapshot> read(String hostname) async {
    final client = _client ?? http.Client();
    try {
      final response = await client.get(
        Uri.parse('http://$hostname/_pocketcoder/status.json'),
      );
      if (response.statusCode != 200) {
        throw StateError('Deployment status returned ${response.statusCode}');
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Deployment status is not a JSON object');
      }
      return ServerStatusSnapshot.fromJson(json);
    } finally {
      if (_client == null) client.close();
    }
  }
}
