import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/llm/i_llm_repository.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_aeroform/infrastructure/core/logger.dart';
import 'llm_state.dart';

@injectable
class LlmCubit extends Cubit<LlmState> {
  final ILlmRepository _repository;
  StreamSubscription? _keysSub;
  StreamSubscription? _providersSub;
  StreamSubscription? _configSub;

  LlmCubit(this._repository) : super(LlmState.initial());

  @override
  Future<void> close() {
    _keysSub?.cancel();
    _providersSub?.cancel();
    _configSub?.cancel();
    return super.close();
  }

  void watchAll() {
    emit(state.copyWith(status: UiFlowStatus.loading));

    _keysSub?.cancel();
    _keysSub = _repository.watchKeys().listen(
          (keys) => emit(
              state.copyWith(keys: keys, status: UiFlowStatus.success)),
          onError: (e) {
            logError('LLM: Failed to watch keys', e);
            emit(state.copyWith(error: e, status: UiFlowStatus.failure));
          },
        );

    _providersSub?.cancel();
    _providersSub = _repository.watchProviders().listen(
          (providers) => emit(
              state.copyWith(providers: providers, status: UiFlowStatus.success)),
          onError: (e) {
            logError('LLM: Failed to watch providers', e);
            emit(state.copyWith(error: e, status: UiFlowStatus.failure));
          },
        );

    _configSub?.cancel();
    _configSub = _repository.watchConfig().listen(
          (configs) => emit(
              state.copyWith(configs: configs, status: UiFlowStatus.success)),
          onError: (e) {
            logError('LLM: Failed to watch config', e);
            emit(state.copyWith(error: e, status: UiFlowStatus.failure));
          },
        );
  }

  Future<void> saveKey(String providerId, Map<String, dynamic> envVars) async {
    try {
      await _repository.saveKey(providerId, envVars);
    } catch (e) {
      logError('LLM: Failed to save key', e);
      emit(state.copyWith(error: e, status: UiFlowStatus.failure));
    }
  }

  Future<void> deleteKey(String id) async {
    try {
      await _repository.deleteKey(id);
    } catch (e) {
      logError('LLM: Failed to delete key', e);
      emit(state.copyWith(error: e, status: UiFlowStatus.failure));
    }
  }

  Future<void> setModel(String model, {String? chat}) async {
    try {
      await _repository.setModel(model, chat: chat);
    } catch (e) {
      logError('LLM: Failed to set model', e);
      emit(state.copyWith(error: e, status: UiFlowStatus.failure));
    }
  }
}
