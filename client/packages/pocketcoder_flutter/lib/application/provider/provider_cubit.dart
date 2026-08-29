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
  StreamSubscription? _harnessModelsSub;
  StreamSubscription? _harnessProvidersSub;
  StreamSubscription? _providerAPIKeysSub;
  StreamSubscription? _providerCatalogSub;

  @override
  Future<void> close() {
    _harnessesSub?.cancel();
    _modelsSub?.cancel();
    _harnessModelsSub?.cancel();
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
    _harnessModelsSub?.cancel();
    _harnessModelsSub = _repo.watchHarnessModels().listen(
        (items) => emit(
            state.copyWith(harnessModels: items, status: UiFlowStatus.success)),
        onError: (Object e) =>
            emit(state.copyWith(error: e, status: UiFlowStatus.failure)));
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

  Future<void> saveProviderAPIKey(ProviderApiKey key) => tryOperation(() async {
        await _repo.saveProviderAPIKey(key);
        return createSuccessState();
      });

  Future<void> deleteProviderAPIKey(String id) => tryOperation(() async {
        await _repo.deleteProviderAPIKey(id);
        return createSuccessState();
      });
}
