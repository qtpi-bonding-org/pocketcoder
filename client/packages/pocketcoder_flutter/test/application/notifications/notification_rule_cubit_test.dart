import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/notifications/notification_rule_cubit.dart';
import 'package:pocketcoder_flutter/application/notifications/notification_rule_state.dart';
import 'package:pocketcoder_flutter/domain/notifications/i_notification_rule_repository.dart';

class MockNotificationRuleRepository extends Mock
    implements INotificationRuleRepository {}

void main() {
  late MockNotificationRuleRepository repo;
  NotificationRuleCubit? lastCubit;

  NotificationRuleCubit buildCubit() {
    final cubit = NotificationRuleCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockNotificationRuleRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('NotificationRuleCubit.watchRules', () {
    test('emits loading then loaded on a successful stream', () async {
      final controller = StreamController<Map<String, bool>>();
      when(() => repo.watchRules()).thenAnswer((_) => controller.stream);

      final cubit = buildCubit();
      final states = <NotificationRuleState>[];
      final sub = cubit.stream.listen(states.add);

      cubit.watchRules();
      // Let the loading emit reach the listener.
      await Future<void>.delayed(Duration.zero);

      controller.add(const {'chat_reply': true, 'schedule': false});
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      await controller.close();

      expect(states, [
        const NotificationRuleState(status: UiFlowStatus.loading),
        const NotificationRuleState(
          status: UiFlowStatus.success,
          rules: {'chat_reply': true, 'schedule': false},
        ),
      ]);
    });

    test('emits error when the stream errors', () async {
      final controller = StreamController<Map<String, bool>>();
      when(() => repo.watchRules()).thenAnswer((_) => controller.stream);

      final cubit = buildCubit();

      cubit.watchRules();
      await Future<void>.delayed(Duration.zero);

      controller.addError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.hasError, isTrue);

      await controller.close();
    });
  });

  group('NotificationRuleCubit.setTypeEnabled', () {
    test('calls repository.setTypeEnabled with the given args', () async {
      when(() => repo.setTypeEnabled(any(), any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.setTypeEnabled('chat_reply', false);

      verify(() => repo.setTypeEnabled('chat_reply', false)).called(1);
    });

    test('emits error state on repository failure', () async {
      when(() => repo.setTypeEnabled(any(), any()))
          .thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.setTypeEnabled('chat_reply', false);

      expect(cubit.state.hasError, isTrue);
    });
  });
}
