import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/observability/observability_cubit.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';

class MockObservabilityRepository extends Mock
    implements IObservabilityRepository {}

void main() {
  late MockObservabilityRepository repository;

  setUp(() {
    repository = MockObservabilityRepository();
  });

  test('loadContainers populates state.containers on success', () async {
    when(() => repository.listContainers()).thenAnswer((_) async => [
          const ContainerInfo(
            name: 'pocketcoder-sqlpage',
            state: 'running',
            status: 'Up 1h',
          ),
        ]);
    final cubit = ObservabilityCubit(repository);
    addTearDown(cubit.close);

    await cubit.loadContainers();

    expect(cubit.state.containers, hasLength(1));
    expect(cubit.state.containers.first.name, 'pocketcoder-sqlpage');
  });

  test(
      'loadContainers surfaces a failure via UiFlowStatus.failure without touching stats',
      () async {
    when(() => repository.listContainers()).thenThrow(Exception('boom'));
    final cubit = ObservabilityCubit(repository);
    addTearDown(cubit.close);

    await cubit.loadContainers();

    expect(cubit.state.status, UiFlowStatus.failure);
    expect(cubit.state.stats, isNull);
  });
}
