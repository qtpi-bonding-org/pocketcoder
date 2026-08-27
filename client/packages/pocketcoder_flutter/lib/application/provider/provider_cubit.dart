import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

@injectable
class ProviderCubit extends AppCubit<ProviderState> {
  ProviderCubit(this._repo) : super(const ProviderState());

  final IProviderRepository _repo;

  StreamSubscription? _harnessesSub;
  StreamSubscription? _modelsSub;
  StreamSubscription? _harnessModelsSub;
  StreamSubscription? _providerKeysSub;
  StreamSubscription? _providerCatalogSub;

  @override
  Future<void> close() {
    _harnessesSub?.cancel();
    _modelsSub?.cancel();
    _harnessModelsSub?.cancel();
    _providerKeysSub?.cancel();
    _providerCatalogSub?.cancel();
    return super.close();
  }

  /// Subscribes to the repository's watch streams and reduces them into
  /// [ProviderState]. Mirrors `AgentConfigCubit.watchAll`: streams return
  /// `Stream` (not `Future`), so we listen for each field rather than going
  /// through `tryOperation`, and explicitly emit `UiFlowStatus.success` /
  /// `failure` on every emission (the library does not auto-set those).
  void watchAll() {
    emit(state.copyWith(status: UiFlowStatus.loading));

    _harnessesSub?.cancel();
    _harnessesSub = _repo.watchHarnesses().listen(
          (harnesses) => emit(state.copyWith(
            harnesses: harnesses,
            status: UiFlowStatus.success,
          )),
          onError: (Object e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );

    _modelsSub?.cancel();
    _modelsSub = _repo.watchModels().listen(
          (models) => emit(state.copyWith(
            models: models,
            status: UiFlowStatus.success,
          )),
          onError: (Object e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );

    _harnessModelsSub?.cancel();
    _harnessModelsSub = _repo.watchHarnessModels().listen(
          (harnessModels) => emit(state.copyWith(
            harnessModels: harnessModels,
            status: UiFlowStatus.success,
          )),
          onError: (Object e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );

    _providerKeysSub?.cancel();
    _providerKeysSub = _repo.watchProviderKeys().listen(
          (providerKeys) => emit(state.copyWith(
            providerKeys: providerKeys,
            status: UiFlowStatus.success,
          )),
          onError: (Object e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );

    _providerCatalogSub?.cancel();
    _providerCatalogSub = _repo.watchProviderCatalog().listen(
          (providerCatalog) => emit(state.copyWith(
            providerCatalog: providerCatalog,
            status: UiFlowStatus.success,
          )),
          onError: (Object e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );
  }

  Future<void> saveProviderKey(ProviderKey key) => tryOperation(() async {
        await _repo.saveProviderKey(key);
        return createSuccessState();
      });

  Future<void> deleteProviderKey(String id) => tryOperation(() async {
        await _repo.deleteProviderKey(id);
        return createSuccessState();
      });
}
