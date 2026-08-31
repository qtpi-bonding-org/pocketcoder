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
  StreamSubscription? _modelsSub;
  StreamSubscription? _harnessProvidersSub;
  StreamSubscription? _providerAPIKeysSub;
  StreamSubscription? _providerCatalogSub;
  int _harnessModelsRequestId = 0;

  @override
  Future<void> close() {
    _harnessesSub?.cancel();
    _modelsSub?.cancel();
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
    _modelsSub?.cancel();
    _modelsSub = _repo.watchModels().listen(
        (items) =>
            emit(state.copyWith(models: items, status: UiFlowStatus.success)),
        onError: (Object e) =>
            emit(state.copyWith(error: e, status: UiFlowStatus.failure)));
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

  /// Unlike the other five collections above, harness_models is a one-shot
  /// fetch, not a live stream -- see IProviderRepository.fetchHarnessModels
  /// for why. Matches the same manual status/error handling watchAll()
  /// already uses for its stream subscriptions, rather than switching this
  /// one call to tryOperation and having two different failure-handling
  /// idioms in the same method.
  ///
  /// A detached Future has no single-flight guarantee when watchAll() is
  /// called repeatedly, so the request id prevents an older result from
  /// overwriting newer state. The isClosed check prevents a late result from
  /// emitting after the cubit has been closed.
  Future<void> _loadHarnessModels() async {
    final requestId = ++_harnessModelsRequestId;
    try {
      final items = await _repo.fetchHarnessModels();
      if (isClosed || requestId != _harnessModelsRequestId) return;
      emit(state.copyWith(harnessModels: items, status: UiFlowStatus.success));
    } catch (e) {
      if (isClosed || requestId != _harnessModelsRequestId) return;
      emit(state.copyWith(error: e, status: UiFlowStatus.failure));
    }
  }

  Future<void> saveProviderAPIKey(ProviderApiKey key) => tryOperation(() async {
        await _repo.saveProviderAPIKey(key);
        return createSuccessState();
      });

  Future<void> deleteProviderAPIKey(String id) => tryOperation(() async {
        await _repo.deleteProviderAPIKey(id);
        return createSuccessState();
      });
}
