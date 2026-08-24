import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_pro/domain/deployment/deploy_operation_key.dart';
import 'package:pocketcoder_pro/domain/deployment/readiness_update.dart';
import 'package:pocketcoder_pro/domain/deployment/server_status_document.dart';

void main() {
  test('isTerminalError is false when statusDocument is null', () {
    final update = ReadinessUpdate(
      operationKey: DeployOperationKey.loadingImages,
      pollingAttempt: 1,
      statusTransportAuthenticated: true,
      statusDocument: null,
    );

    expect(update.isTerminalError, isFalse);
  });

  test('isTerminalError is false when errorCode is set but attempt < maxAttempts (transient error)', () {
    final doc = ServerStatusDocument.tryParse(
      '{"schema":3,"runId":"r1","operation":"loading_images","updatedAt":"2026-08-16T00:00:00Z",'
      '"errorCode":"release_install_failed","attempt":1,"maxAttempts":3}',
    );

    final update = ReadinessUpdate(
      operationKey: DeployOperationKey.loadingImages,
      pollingAttempt: 1,
      statusTransportAuthenticated: true,
      statusDocument: doc,
    );

    expect(update.isTerminalError, isFalse);
  });

  test('isTerminalError is true when errorCode is set and attempt >= maxAttempts (terminal error)', () {
    final doc = ServerStatusDocument.tryParse(
      '{"schema":3,"runId":"r1","operation":"loading_images","updatedAt":"2026-08-16T00:00:00Z",'
      '"errorCode":"release_install_failed","attempt":3,"maxAttempts":3}',
    );

    final update = ReadinessUpdate(
      operationKey: DeployOperationKey.loadingImages,
      pollingAttempt: 1,
      statusTransportAuthenticated: true,
      statusDocument: doc,
    );

    expect(update.isTerminalError, isTrue);
  });
}
