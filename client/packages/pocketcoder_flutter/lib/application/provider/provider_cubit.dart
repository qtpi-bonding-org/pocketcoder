import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

@injectable
class ProviderCubit extends AppCubit<ProviderState> {
  ProviderCubit(this._repo) : super(const ProviderState());

  final IProviderRepository _repo;

  StreamSubscription? _harnessesSub;
  StreamSubscription? _harnessProvidersSub;
  StreamSubscription? _providerAPIKeysSub;
  StreamSubscription? _providerCatalogSub;
  int _modelsRequestId = 0;
  int _harnessModelsRequestId = 0;

  @override
  Future<void> close() {
    _harnessesSub?.cancel();
    _harnessProvidersSub?.cancel();
    _providerAPIKeysSub?.cancel();
    _providerCatalogSub?.cancel();
    return super.close();
  }

  void watchAll() {
    emit(state.copyWith(status: UiFlowStatus.loading));
    _harnessesSub?.cancel();
    _harnessesSub = _repo.watchHarnesses().listen(
        (items) => emit(
            state.copyWith(harnesses: items, status: UiFlowStatus.success)),
        onError: (Object e) =>
            emit(state.copyWith(error: e, status: UiFlowStatus.failure)));
    unawaited(_loadModels());
    unawaited(_loadHarnessModels());
    _harnessProvidersSub?.cancel();
    _harnessProvidersSub = _repo.watchHarnessProviders().listen(
        (items) => emit(state.copyWith(
            harnessProviders: items, status: UiFlowStatus.success)),
        onError: (Object e) =>
            emit(state.copyWith(error: e, status: UiFlowStatus.failure)));
    _providerAPIKeysSub?.cancel();
    _providerAPIKeysSub = _repo.watchProviderAPIKeys().listen(
        (items) => emit(state.copyWith(
            providerAPIKeys: items, status: UiFlowStatus.success)),
        onError: (Object e) =>
            emit(state.copyWith(error: e, status: UiFlowStatus.failure)));
    _providerCatalogSub?.cancel();
    _providerCatalogSub = _repo.watchProviderCatalog().listen(
        (items) => emit(state.copyWith(
            providerCatalog: items, status: UiFlowStatus.success)),
        onError: (Object e) =>
            emit(state.copyWith(error: e, status: UiFlowStatus.failure)));
  }

  /// The request id guards against a stale result from a prior watchAll()
  /// call overwriting newer state.
  Future<void> _loadModels() async {
    final requestId = ++_modelsRequestId;
    try {
      final items = await _repo.fetchModels();
      if (isClosed || requestId != _modelsRequestId) return;
      emit(state.copyWith(models: items, status: _statusAfterSuccess));
    } catch (e) {
      if (isClosed || requestId != _modelsRequestId) return;
      emit(state.copyWith(error: e, status: UiFlowStatus.failure));
    }
  }

  Future<void> _loadHarnessModels() async {
    final requestId = ++_harnessModelsRequestId;
    try {
      final items = await _repo.fetchHarnessModels();
      if (isClosed || requestId != _harnessModelsRequestId) return;
      emit(state.copyWith(harnessModels: items, status: _statusAfterSuccess));
    } catch (e) {
      if (isClosed || requestId != _harnessModelsRequestId) return;
      emit(state.copyWith(error: e, status: UiFlowStatus.failure));
    }
  }

  /// Preserves a failure from a concurrent sibling fetch instead of
  /// clobbering it with this one's success.
  UiFlowStatus get _statusAfterSuccess =>
      state.status == UiFlowStatus.failure
          ? UiFlowStatus.failure
          : UiFlowStatus.success;

  Future<void> saveProviderAPIKey(ProviderApiKey key) => tryOperation(() async {
        await _repo.saveProviderAPIKey(key);
        return createSuccessState();
      });

  Future<void> deleteProviderAPIKey(String id) => tryOperation(() async {
        await _repo.deleteProviderAPIKey(id);
        return createSuccessState();
      });
}
