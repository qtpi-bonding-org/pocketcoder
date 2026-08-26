import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:built_collection/built_collection.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;
import '../core/api_endpoints.dart';
import '../core/pocketbase_auth_header.dart';
import '../core/pocketcoder_api_client.dart';

@LazySingleton(as: IObservabilityRepository)
class ObservabilityRepository implements IObservabilityRepository {
  final PocketBase _pb;
  final PocketCoderApiClient _api;

  ObservabilityRepository(this._pb, this._api);

  @override
  Stream<String> watchLogs(String containerName) {
    final controller = StreamController<String>();
    final url = "${_pb.baseURL}${StreamingEndpoints.logs(containerName)}";

    logInfo('📈 [Observability] Subscribing to container log stream');

    final headers = <String, String>{
      "Accept": "text/event-stream",
      "Cache-Control": "no-cache",
    };
    // This stream historically attempted anonymously when signed out, so
    // preserve that behavior by omitting Authorization when there is no token.
    final authHeader = pocketBaseAuthHeaderValue(_pb);
    if (authHeader != null) headers["Authorization"] = authHeader;

    final subscription = SSEClient.subscribeToSSE(
      method: SSERequestType.GET,
      url: url,
      header: headers,
    ).listen((event) {
      final data = event.data;
      if (data != null) {
        // SSEClient handles the "data: " prefix and heartbeats
        controller.add(data);
      }
    }, onError: (e, stack) {
      logError('📈 [Observability] Log stream error', e, stack);
      controller.addError(e, stack);
    }, onDone: () {
      logInfo('📈 [Observability] Log stream closed');
      controller.close();
    });

    controller.onCancel = () {
      logInfo('📈 [Observability] Unsubscribing from logs');
      subscription.cancel();
    };

    return controller.stream;
  }

  @override
  Future<SystemStats> fetchSystemStats() async {
    return tryMethod(
      () async {
        final response = await _pb.send(
          StreamingEndpoints.observability,
          method: 'GET',
        );

        if (response is List) {
          // SQLPage might return a list of objects if multiple statements are used
          // but the first one confirms 'json' component.
          // Usually it merges them into a single object if we use specific patterns.
          // Let's assume it's the merged object based on our index.sql.
          final Map<String, dynamic> merged = {};
          for (final item in response) {
            if (item is Map<String, dynamic>) {
              merged.addAll(item);
            }
          }
          return SystemStats.fromJson(merged);
        }

        if (response is Map<String, dynamic>) {
          return SystemStats.fromJson(response);
        }

        throw ObservabilityException('Unexpected response format from SQLPage');
      },
      ObservabilityException.new,
      'fetchSystemStats',
    );
  }

  @override
  Future<List<ContainerInfo>> listContainers() {
    return tryMethod(
      () async {
        final response = await _api.logs.listContainers();
        final containers = response.data?.containers ??
            BuiltList<generated.ContainerSummary>();
        return containers
            .map((c) => ContainerInfo(
                  name: c.name,
                  state: c.state,
                  status: c.status,
                ))
            .toList();
      },
      ObservabilityException.new,
      'listContainers',
    );
  }
}
