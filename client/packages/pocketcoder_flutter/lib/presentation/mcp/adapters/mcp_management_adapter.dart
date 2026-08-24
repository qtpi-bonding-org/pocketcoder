import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';
import 'package:pocketcoder_flutter/presentation/mcp/widgets/mcp_management_view.dart';

class McpManagementAdapter extends CubitAdapter<McpCubit, McpState> {
  const McpManagementAdapter({super.key});

  static McpState _selectState(McpState state) => state;

  @override
  Widget buildAdapter(
      BuildContext context, CubitAdapterState<McpCubit, McpState> adapter) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<McpCubit>();
    return UiFlowListener<McpCubit, McpState>(
      child: ValueListenableBuilder<McpState>(
        valueListenable: state,
        builder: (context, value, _) => switch (value.status) {
          UiFlowStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          UiFlowStatus.failure => Center(
              child:
                  Text(safeErrorMessage(value.error))),
          UiFlowStatus.success => McpManagementView(
              servers: value.servers,
              oauthProviders: cubit.supportedOAuthProviders(),
              hasPendingDelivery: cubit.hasPendingOAuthDelivery,
              onAuthorize: (id, config) => cubit.authorize(id, config: config),
              onDeny: cubit.deny,
              onConnectOAuth: cubit.connectOAuth,
              onRetryOAuth: cubit.retryOAuthDelivery,
              onCreateServer: cubit.createServer,
            ),
          UiFlowStatus.idle => const SizedBox.shrink(),
        },
      ),
    );
  }
}
