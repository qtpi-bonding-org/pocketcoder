import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/notifications/notification_rule_cubit.dart';
import 'package:pocketcoder_flutter/application/notifications/notification_rule_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/notifications/notification_settings_screen.dart';

class NotificationSettingsAdapter
    extends CubitAdapter<NotificationRuleCubit, NotificationRuleState> {
  const NotificationSettingsAdapter({
    super.key,
    required this.onEnableDevice,
    required this.onConfigureSelfHostedPush,
  });

  final Future<bool> Function() onEnableDevice;
  final VoidCallback onConfigureSelfHostedPush;

  static NotificationRuleState _selectState(NotificationRuleState state) =>
      state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<NotificationRuleCubit, NotificationRuleState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    return UiFlowListener<NotificationRuleCubit, NotificationRuleState>(
      child: ValueListenableBuilder<NotificationRuleState>(
        valueListenable: state,
        builder: (context, value, _) => NotificationSettingsView(
          state: value,
          onChanged: context.read<NotificationRuleCubit>().setTypeEnabled,
          onEnableDevice: onEnableDevice,
          onConfigureSelfHostedPush: onConfigureSelfHostedPush,
        ),
      ),
    );
  }
}
