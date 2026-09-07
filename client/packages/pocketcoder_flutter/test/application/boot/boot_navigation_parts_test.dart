import 'package:flutter_test/flutter_test.dart';
import 'package:nav_snapshot/nav_snapshot.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';

import 'boot_routing_decider_test.dart' as fakes;

void main() {
  test('readiness is observed: ready immediately, never loading', () {
    final readiness = fakes.FakeReadiness(
      const ServerReadinessSnapshot(status: ServerReadinessStatus.resolving),
    );
    final parts = fakes.buildParts(readiness: readiness);

    expect(parts.readiness.peek(), isA<PartReady<ServerReadinessSnapshot>>());
    expect(parts.readiness.peek().valueOrNull?.status,
        ServerReadinessStatus.resolving);
    parts.dispose();
  });

  test('a readiness emission updates the part without a loading flash',
      () async {
    final readiness = fakes.FakeReadiness(
      const ServerReadinessSnapshot(status: ServerReadinessStatus.resolving),
    );
    final parts = fakes.buildParts(readiness: readiness);

    final sawLoading = <bool>[];
    parts.readiness.addListener(
      () => sawLoading.add(parts.readiness.peek().isLoading),
    );

    readiness.set(const ServerReadinessSnapshot(
      status: ServerReadinessStatus.ready,
      instanceId: 'i1',
    ));
    await Future<void>.delayed(Duration.zero);

    expect(parts.readiness.peek().valueOrNull?.status,
        ServerReadinessStatus.ready);
    expect(sawLoading, everyElement(isFalse));
    parts.dispose();
  });

  test('existence re-queries when the ready epoch changes', () async {
    final resolver =
        fakes.FakeInstanceExistenceResolver(InstanceExistenceResult.exists);
    final parts = fakes.buildParts(existenceResolver: resolver);

    parts.existence?.read();
    await Future<void>.delayed(Duration.zero);
    expect(resolver.calls, 1);

    parts.readyEpoch++;
    parts.existence?.read();
    await Future<void>.delayed(Duration.zero);
    expect(resolver.calls, 2, reason: 'cacheKey includes the ready epoch');
    parts.dispose();
  });

  test('existence re-queries after a sign-in round trip it never observed',
      () async {
    final resolver =
        fakes.FakeInstanceExistenceResolver(InstanceExistenceResult.exists);
    final parts = fakes.buildParts(existenceResolver: resolver);

    parts.existence?.read();
    await Future<void>.delayed(Duration.zero);
    expect(resolver.calls, 1);

    await fakes.setSignedIn(parts, true);
    await fakes.setSignedIn(parts, false);
    await Future<void>.delayed(Duration.zero);

    parts.existence?.read();
    await Future<void>.delayed(Duration.zero);

    expect(resolver.calls, 2,
        reason: 'a monotone key survives a round trip nothing read');
    parts.dispose();
  });

  test('the harness is re-probed on every input event', () async {
    final harness = fakes.FakeHarness(connected: false);
    final parts = fakes.buildParts(harness: harness);

    parts.harness.read();
    await Future<void>.delayed(Duration.zero);
    expect(harness.calls, 1);

    await fakes.emitReadiness(parts);
    parts.harness.read();
    await Future<void>.delayed(Duration.zero);

    expect(harness.calls, 2);
    parts.dispose();
  });

  test('FOSS builds have no existence or deployment-auth part', () {
    final parts = fakes.buildParts(
      existenceResolver: null,
      deploymentAuthStatus: null,
    );

    expect(parts.existence, isNull);
    expect(parts.deploymentAuth, isNull);
    expect(parts.all, isNot(contains(isNull)));
    parts.dispose();
  });
}
