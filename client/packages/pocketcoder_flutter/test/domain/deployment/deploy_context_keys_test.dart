import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/deployment/deploy_context_keys.dart';

void main() {
  test('instanceContextKey round-trips an Instance through JSON', () {
    final instance = Instance(
      id: '999',
      label: 'provisioned-attempt-1',
      ipAddress: '203.0.113.10',
      status: InstanceStatus.running,
      created: DateTime.utc(2026, 1, 1),
      region: 'us-east',
      planType: 'g6-standard-2',
      provider: 'linode',
    );
    final json = instanceContextKey.toJson(instance);
    final decoded = instanceContextKey.fromJson(json);
    expect(decoded, instance);
  });

  test('instanceContextKey has a stable, unique name', () {
    expect(instanceContextKey.name, 'deploy.instance');
  });
}