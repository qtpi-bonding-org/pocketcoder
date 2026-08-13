import 'package:cubit_ui_flow/cubit_ui_flow.dart';

import 'pocketcoder_update_state.dart';

class PocketCoderUpdateMessageMapper
    implements IStateMessageMapper<PocketCoderUpdateState> {
  @override
  MessageKey? map(PocketCoderUpdateState state) {
    final result = state.result;
    if (state.status.isSuccess && result != null) {
      return result.succeeded
          ? MessageKey.success('pocketCoderUpdate.success', {})
          : MessageKey.error(
              'pocketCoderUpdate.commandFailed',
              {'exitCode': result.exitCode.toString()},
            );
    }

    if (state.status.isLoading) {
      return MessageKey.info('pocketCoderUpdate.inProgress', {});
    }

    if (state.hasError) {
      return MessageKey.error(
        'pocketCoderUpdate.error',
        {'message': state.error?.toString() ?? 'Unknown error'},
      );
    }

    return null;
  }
}
