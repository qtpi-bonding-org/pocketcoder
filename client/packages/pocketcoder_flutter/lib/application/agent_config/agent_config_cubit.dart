import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_state.dart';
import 'package:pocketcoder_flutter/domain/agent_config/i_agent_config_repository.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

@injectable
class AgentConfigCubit extends AppCubit<AgentConfigState> {
  AgentConfigCubit(this._repo) : super(const AgentConfigState());

  final IAgentConfigRepository _repo;

  StreamSubscription? _configsSub;
  StreamSubscription? _promptsSub;
  StreamSubscription? _permissionModesSub;

  @override
  Future<void> close() {
    _configsSub?.cancel();
    _promptsSub?.cancel();
    _permissionModesSub?.cancel();
    return super.close();
  }

  /// Subscribes to the repository's watch streams and reduces them into
  /// [AgentConfigState]. Mirrors `AiConfigCubit.watchAll`: streams return
  /// `Stream` (not `Future`), so we listen for each field rather than going
  /// through `tryOperation`, and explicitly emit `UiFlowStatus.success` /
  /// `failure` on every emission (the library does not auto-set those).
  void watchAll() {
    emit(state.copyWith(status: UiFlowStatus.loading));

    _configsSub?.cancel();
    _configsSub = _repo.watchConfigs().listen(
          (configs) => emit(state.copyWith(
            configs: configs,
            status: UiFlowStatus.success,
          )),
          onError: (Object e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );

    _promptsSub?.cancel();
    _promptsSub = _repo.watchPrompts().listen(
          (prompts) => emit(state.copyWith(
            prompts: prompts,
            status: UiFlowStatus.success,
          )),
          onError: (Object e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );

    _permissionModesSub?.cancel();
    _permissionModesSub = _repo.watchPermissionModes().listen(
          (permissionModes) => emit(state.copyWith(
            permissionModes: permissionModes,
            status: UiFlowStatus.success,
          )),
          onError: (Object e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );
  }

  Future<void> saveConfig(PocoConfig config) => tryOperation(() async {
        await _repo.saveConfig(config);
        return createSuccessState();
      });

  Future<void> deleteConfig(String id) => tryOperation(() async {
        await _repo.deleteConfig(id);
        return createSuccessState();
      });

  Future<void> savePrompt(Prompt prompt) => tryOperation(() async {
        await _repo.savePrompt(prompt);
        return createSuccessState();
      });

  Future<void> deletePrompt(String id) => tryOperation(() async {
        await _repo.deletePrompt(id);
        return createSuccessState();
      });
}
