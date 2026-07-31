import 'package:cubit_ui_flow/cubit_ui_flow.dart';

import 'server_update_state.dart';

class ServerUpdateMessageMapper implements IStateMessageMapper<ServerUpdateState> {
  @override
  MessageKey? map(ServerUpdateState state) {
    if (state.status.isSuccess && state.result != null) {
      return state.result!.succeeded
          ? MessageKey.success('serverUpdate.success', {})
          : MessageKey.error(
              'serverUpdate.commandFailed',
              {'exitCode': state.result!.exitCode.toString()},
            );
    }

    if (state.status.isLoading) {
      return MessageKey.info('serverUpdate.inProgress', {});
    }

    if (state.hasError) {
      return MessageKey.error(
        'serverUpdate.error',
        {'message': state.error?.toString() ?? 'Unknown error'},
      );
    }

    return null;
  }
}
