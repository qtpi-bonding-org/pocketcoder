import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:flutter_aeroform/domain/observability/i_observability_repository.dart';
import 'package:flutter_aeroform/domain/exceptions.dart';
import 'package:flutter_aeroform/infrastructure/core/logger.dart';
import 'package:flutter_aeroform/core/try_operation.dart';
import 'package:pocketbase/pocketbase.dart';
import '../core/api_endpoints.dart';

@LazySingleton(as: IObservabilityRepository)
class ObservabilityRepository implements IObservabilityRepository {
  final PocketBase _pb;

  ObservabilityRepository(this._pb);

  @override
  Stream<String> watchLogs(String containerName) {
    final controller = StreamController<String>();
    final url = "${_pb.baseURL}${ApiEndpoints.logs(containerName)}";

    logInfo('📈 [Observability] Subscribing to logs: $url');

    final subscription = SSEClient.subscribeToSSE(
      method: SSERequestType.GET,
      url: url,
      header: {
        "Accept": "text/event-stream",
        "Cache-Control": "no-cache",
        "Authorization": "Bearer ${_pb.authStore.token}",
      },
    ).listen((event) {
      if (event.data != null) {
        // SSEClient handles the "data: " prefix and heartbeats
        controller.add(event.data!);
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
          ApiEndpoints.observability,
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
}

class ObservabilityException extends DomainException {
  ObservabilityException(super.message, [super.error]);
}
