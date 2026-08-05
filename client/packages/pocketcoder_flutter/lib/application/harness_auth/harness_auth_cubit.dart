import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';

import 'harness_auth_state.dart';

class HarnessAuthCubit extends Cubit<HarnessAuthState> {
  HarnessAuthCubit({
    required IProviderRepository providerRepository,
    required IHarnessAuthRepository authRepository,
  })  : _providerRepository = providerRepository,
        _authRepository = authRepository,
        super(const HarnessAuthState());

  final IProviderRepository _providerRepository;
  final IHarnessAuthRepository _authRepository;

  StreamSubscription<List<Harnesse>>? _harnessSub;
  StreamSubscription<List<ProviderKey>>? _providerKeysSub;

  void watchData() {
    emit(state.copyWith(isLoading: true, clearError: true));
    _loadHarnesses();
    _loadProviderKeys();
  }

  void _loadHarnesses() {
    _harnessSub?.cancel();
    _harnessSub = _providerRepository.watchHarnesses().listen((harnesses) {
      emit(
        state.copyWith(
          harnesses: harnesses,
          isLoading: false,
          clearError: true,
        ),
      );
      _refreshStatuses();
    }, onError: (Object e) {
      unawaited(pocketCoderDiagnosticCapture.capture(
        error: e,
        source: 'HarnessAuthCubit',
        operation: 'watchHarnesses',
      ));
      emit(state.copyWith(error: e));
    });
  }

  void _loadProviderKeys() {
    _providerKeysSub?.cancel();
    _providerKeysSub = _providerRepository.watchProviderKeys().listen(
      (providerKeys) => emit(state.copyWith(providerKeys: providerKeys)),
      onError: (Object e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
          error: e,
          source: 'HarnessAuthCubit',
          operation: 'watchProviderKeys',
        ));
        emit(state.copyWith(error: e));
      },
    );
  }

  Future<void> _setBusy(String harnessId, bool busy) async {
    final nextBusy = Set<String>.from(state.busyHarnesses);
    if (busy) {
      nextBusy.add(harnessId);
    } else {
      nextBusy.remove(harnessId);
    }
    emit(state.copyWith(busyHarnesses: nextBusy));
  }

  Future<void> _withBusy(
      String harnessId, Future<void> Function() action) async {
    await _setBusy(harnessId, true);
    try {
      await action();
      emit(state.copyWith(clearError: true));
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
        error: e,
        source: 'HarnessAuthCubit',
        operation: 'harnessOperation',
      );
      emit(state.copyWith(error: e));
    } finally {
      await _setBusy(harnessId, false);
    }
  }

  void _updateStatus(String harnessId, HarnessAuthStatus status) {
    final next = Map<String, HarnessAuthStatus>.from(state.statuses);
    next[harnessId] = status;
    emit(state.copyWith(statuses: next, clearError: true));
  }

  Future<void> _refreshStatuses() async {
    if (state.harnesses.isEmpty) return;

    await Future.wait(
      state.harnesses.map((h) => _safeRefreshHarness(h.id)),
    );
  }

  Future<void> _safeRefreshHarness(String harnessId) async {
    try {
      final status = await _authRepository.status(harnessId: harnessId);
      _updateStatus(harnessId, status);
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
        error: e,
        source: 'HarnessAuthCubit',
        operation: 'refreshStatus',
      );
      emit(state.copyWith(error: e));
    }
  }

  Future<void> refreshHarness(String harnessId) async {
    final snapshot = state.statuses[harnessId];
    return _withBusy(
      harnessId,
      () => _authRepository
          .status(
            harnessId: harnessId,
            attemptId: snapshot?.attempt?.id,
          )
          .then((status) => _updateStatus(harnessId, status)),
    );
  }

  Future<void> startWithAccount({
    required String harnessId,
    required String provider,
  }) async {
    return _withBusy(
      harnessId,
      () => _authRepository
          .start(
            harnessId: harnessId,
            credentialMode: 'account',
            provider: provider,
          )
          .then((status) => _updateStatus(harnessId, status)),
    );
  }

  Future<void> startWithApiKey({
    required String harnessId,
    required String providerKey,
  }) async {
    return _withBusy(
      harnessId,
      () => _authRepository
          .start(
            harnessId: harnessId,
            credentialMode: 'api_key',
            providerKey: providerKey,
          )
          .then((status) => _updateStatus(harnessId, status)),
    );
  }

  Future<void> startWithNone(String harnessId) async {
    return _withBusy(
      harnessId,
      () => _authRepository
          .start(harnessId: harnessId, credentialMode: 'none')
          .then((status) => _updateStatus(harnessId, status)),
    );
  }

  Future<void> poll(String harnessId) async {
    final snapshot = state.statuses[harnessId];
    await _withBusy(
      harnessId,
      () => _authRepository
          .poll(harnessId: harnessId, attemptId: snapshot?.attempt?.id)
          .then((status) => _updateStatus(harnessId, status)),
    );
  }

  Future<void> submitCode({
    required String harnessId,
    required String code,
  }) async {
    final snapshot = state.statuses[harnessId];
    final attemptId = snapshot?.attempt?.id;
    await _withBusy(
      harnessId,
      () => _authRepository
          .submit(harnessId: harnessId, code: code, attemptId: attemptId)
          .then((status) => _updateStatus(harnessId, status)),
    );
  }

  Future<void> cancel(String harnessId) async {
    final snapshot = state.statuses[harnessId];
    await _withBusy(
      harnessId,
      () => _authRepository
          .cancel(
            harnessId: harnessId,
            attemptId: snapshot?.attempt?.id,
          )
          .then((status) => _updateStatus(harnessId, status)),
    );
  }

  Future<void> disconnect(String harnessId) async {
    await _withBusy(
      harnessId,
      () => _authRepository
          .disconnect(harnessId: harnessId)
          .then((status) => _updateStatus(harnessId, status)),
    );
  }

  List<ProviderKey> providerKeysForHarness(String harnessProvider) {
    final provider = harnessProvider.trim().toLowerCase();
    if (provider.isEmpty) return const [];

    final match = state.providerKeys.where((key) {
      final keyProvider = key.provider.trim().toLowerCase();
      return keyProvider == provider;
    }).toList();

    return match;
  }

  @override
  Future<void> close() {
    _harnessSub?.cancel();
    _providerKeysSub?.cancel();
    return super.close();
  }
}
