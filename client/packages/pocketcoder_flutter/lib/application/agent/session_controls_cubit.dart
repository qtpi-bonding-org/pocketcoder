import 'dart:async';

import 'package:acp_dart/acp_dart.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';

import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_chat_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/chat/chat_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_daos.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'session_controls_state.dart';

@injectable
class SessionControlsCubit extends AppCubit<SessionControlsState> {
  SessionControlsCubit(
    this._repository,
    this._chatDao,
    this._pocoConfigDao,
    this._permissionModeDao,
    this._harnessModelDao,
    this._harnesseDao,
  ) : super(const SessionControlsState());

  final AgentChatRepository _repository;
  final ChatDao _chatDao;
  final PocoConfigDao _pocoConfigDao;
  final PermissionModeDao _permissionModeDao;
  final HarnessModelDao _harnessModelDao;
  final HarnesseDao _harnesseDao;

  StreamSubscription? _watchSub;
  String? _chatId;

  @override
  Future<void> close() {
    _watchSub?.cancel();
    return super.close();
  }

  /// Starts watching [chatId]'s reduced Conversation and surfaces its
  /// `sessionState.modes` + `sessionState.config` slices in
  /// [SessionControlsState]. Calling this again with a different chatId
  /// tears down the previous subscription first.
  void open(String chatId) {
    _chatId = chatId;
    _watchSub?.cancel();
    emit(state.copyWith(
      chatId: chatId,
      status: UiFlowStatus.loading,
      lastOperation: SessionControlsOperation.open,
    ));

    _watchSub = _repository.watch(chatId).listen(
      (conversation) {
        emit(state.copyWith(
          sessionState: conversation.sessionState,
          status: UiFlowStatus.success,
        ));
      },
      onError: (Object e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
          error: e,
          source: 'SessionControlsCubit',
          operation: 'watchStream',
        ));
        logError('🤖 [SessionControlsCubit] watch error', e);
        emit(state.copyWith(error: e, status: UiFlowStatus.failure));
      },
    );
  }

  /// Selects [modeId] as the active session mode.
  Future<void> selectMode(String modeId) async {
    final chatId = _chatId;
    if (chatId == null) {
      logWarning('🤖 [SessionControlsCubit] selectMode called before open()');
      return;
    }
    await tryOperation(() async {
      if (state.sessionState.isRunning) {
        await _repository.setMode(chatId, modeId);
      } else {
        final chat = await _chatDao.getOne(chatId);
        final profileId = chat.agentProfile;
        if (profileId == null || profileId.isEmpty) {
          throw StateError(
              'Chat $chatId has no agent_profile to persist a mode change onto');
        }
        final modes = await _permissionModeDao.getFullList(
            filter: _permissionModeDao.pb
                .filter('base_session_mode = {:mode}', {'mode': modeId}));
        if (modes.isEmpty) {
          throw StateError(
              'No permission_modes record has base_session_mode "$modeId"');
        }
        await _pocoConfigDao.save(profileId, {
          'permission_mode': modes.first.id,
        });
      }
      return state.copyWith(
        status: UiFlowStatus.success,
        lastOperation: SessionControlsOperation.selectMode,
      );
    });
  }

  /// Sets a session config option via the ACP-shaped
  /// [SetSessionConfigOptionRequest].
  Future<void> setOption(SetSessionConfigOptionRequest req) async {
    final chatId = _chatId;
    if (chatId == null) {
      logWarning('🤖 [SessionControlsCubit] setOption called before open()');
      return;
    }
    const persistedFields = <String, String>{
      'harnessModelOverride': 'harness_model_override',
      'ollamaModelOverride': 'ollama_model_override',
      'workspaceOverride': 'workspace_override',
    };
    await tryOperation(() async {
      if (state.sessionState.isRunning) {
        await _repository.setConfigOption(chatId, req);
      } else if (req.configId == 'model') {
        // The live ACP configId "model" only exists on an active run's
        // connection (coordinator.SetConfigOption -> ErrNoActiveRun once the
        // run finishes, run.go) -- there's no live session to send it to
        // between turns. Persist it as the chat's model override instead, so
        // it takes effect on the next run (sessionprofile.go).
        await _persistModelOverride(chatId, req.value);
      } else {
        final field = persistedFields[req.configId];
        if (field == null) {
          throw UnsupportedError(
              'Config option "${req.configId}" can only be changed while a session is running');
        }
        // workspace_override is a PocketBase JSON field the server unmarshals
        // into []string (sessionprofile.go), using element 0 as cwd -- it is
        // NOT a plain text field like the other two, so it must be written
        // as a JSON array, not the raw scalar value. An empty value clears
        // the override entirely rather than persisting a single empty path.
        final value = field == 'workspace_override'
            ? (req.value.isEmpty ? const <String>[] : [req.value])
            : req.value;
        await _chatDao.save(chatId, {field: value});
      }
      return state.copyWith(
        status: UiFlowStatus.success,
        lastOperation: SessionControlsOperation.setOption,
      );
    });
  }

  /// `harness_model_override` and `ollama_model_override` are mutually
  /// exclusive server-side (sessionprofile.go: ollama wins when both are
  /// set), so setting one must explicitly clear the other.
  Future<void> _persistModelOverride(String chatId, String value) async {
    if (value.isEmpty) {
      throw StateError('Config option "model" requires a non-empty value');
    }
    final chat = await _chatDao.getOne(chatId);
    final harnessId = chat.harness;
    if (harnessId == null || harnessId.isEmpty) {
      throw StateError(
          'Chat $chatId has no harness to resolve model "$value" against');
    }
    final matches = await _harnessModelDao.getFullList(
        filter: _harnessModelDao.pb.filter(
            'harness = {:h} && harness_model_id = {:m}',
            {'h': harnessId, 'm': value}));
    if (matches.isNotEmpty) {
      await _chatDao.save(chatId, {
        'harness_model_override': matches.first.id,
        'ollama_model_override': '',
      });
      return;
    }
    // No harness_models catalog row -- only treat this as an Ollama model
    // name (no catalog entries exist for those) when the chat's harness
    // actually supports Ollama; otherwise this is most likely a stale
    // catalog or a typo, and silently writing it to ollama_model_override
    // would poison the next run with an unusable model (ollama_model_override
    // takes priority over harness_model_override server-side) with no error
    // ever surfaced to the user.
    final harness = await _harnesseDao.getOne(harnessId);
    if (harness.supportsOllama != true) {
      throw StateError(
          'No harness_models catalog row for harness_model_id "$value" on '
          'harness $harnessId, and harness does not support Ollama models');
    }
    await _chatDao.save(chatId, {
      'ollama_model_override': value,
      'harness_model_override': '',
    });
  }
}
