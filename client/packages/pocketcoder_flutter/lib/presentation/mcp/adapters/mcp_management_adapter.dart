import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/mcp/widgets/mcp_management_view.dart';

class McpManagementAdapter extends CubitAdapter<McpCubit, McpState> {
  const McpManagementAdapter({super.key});

  static McpState _selectState(McpState state) => state;

  @override
  Widget buildAdapter(BuildContext context, CubitAdapterState<McpCubit, McpState> adapter) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<McpCubit>();
    return UiFlowListener<McpCubit, McpState>(
      child: ValueListenableBuilder<McpState>(
        valueListenable: state,
        builder: (context, value, _) => value.maybeWhen(
          loaded: (servers) => McpManagementView(
            servers: servers,
            oauthProviders: cubit.supportedOAuthProviders(),
            hasPendingDelivery: cubit.hasPendingOAuthDelivery,
            onAuthorize: (id, config) => cubit.authorize(id, config: config),
            onDeny: cubit.deny,
            onConnectOAuth: cubit.connectOAuth,
            onRetryOAuth: cubit.retryOAuthDelivery,
            onCreateServer: cubit.createServer,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (message) => Center(child: Text('ERROR: $message')),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
