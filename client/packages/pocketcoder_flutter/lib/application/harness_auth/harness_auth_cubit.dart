import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

import 'harness_auth_state.dart';

@injectable
class HarnessAuthCubit extends AppCubit<HarnessAuthState> {
  HarnessAuthCubit({
    required IProviderRepository providerRepository,
    required IHarnessAuthRepository authRepository,
  })  : _providerRepository = providerRepository,
        _authRepository = authRepository,
        super(const HarnessAuthState());

  final IProviderRepository _providerRepository;
  final IHarnessAuthRepository _authRepository;

  StreamSubscription<List<Harnesse>>? _harnessSub;
  StreamSubscription<List<HarnessProvider>>? _harnessProvidersSub;

  void watchData() {
    OnboardingLogger.event('harness auth data loading');
    emit(state.copyWith(status: UiFlowStatus.loading, error: null));
    _loadHarnesses();
    _loadHarnessProviders();
  }

  void _loadHarnesses() {
    _harnessSub?.cancel();
    _harnessSub = _providerRepository.watchHarnesses().listen((harnesses) {
      if (isClosed) return;
      emit(state.copyWith(
        harnesses: harnesses,
        status: UiFlowStatus.success,
        error: null,
      ));
      OnboardingLogger.event(
          'harness list loaded', {'count': harnesses.length});
      _refreshStatuses();
    }, onError: (Object e) {
      unawaited(pocketCoderDiagnosticCapture.capture(
        error: e,
        source: 'HarnessAuthCubit',
        operation: 'watchHarnesses',
      ));
      if (isClosed) return;
      emit(state.copyWith(status: UiFlowStatus.failure, error: e));
    });
  }

  void _loadHarnessProviders() {
    _harnessProvidersSub?.cancel();
    _harnessProvidersSub = _providerRepository.watchHarnessProviders().listen(
      (providers) {
        if (!isClosed) {
          emit(state.copyWith(
              harnessProviders: providers, harnessProvidersLoaded: true));
        }
        _refreshStatuses();
      },
      onError: (Object e) {
        if (!isClosed) {
          emit(state.copyWith(status: UiFlowStatus.failure, error: e));
        }
      },
    );
  }

  /// The one harness_providers edge this harness supports account login for,
  /// or null if it has none (e.g. a live-config/fan-out harness like Goose --
  /// account login is not offered for multi-provider harnesses in v1).
  String? _oauthProviderFor(String harnessId) {
    for (final edge in state.harnessProviders) {
      if (edge.harness == harnessId && edge.supportsOauth == true) {
        return edge.provider;
      }
    }
    return null;
  }

  Future<void> _setBusy(String harnessId, String provider, bool busy) async {
    if (isClosed) return;
    final key = HarnessProviderKey(harnessId, provider);
    final nextBusy = Set<HarnessProviderKey>.from(state.busyHarnesses);
    if (busy) {
      nextBusy.add(key);
    } else {
      nextBusy.remove(key);
    }
    emit(state.copyWith(busyHarnesses: nextBusy));
  }

  Future<void> _withBusy(
      String harnessId, String provider, Future<void> Function() action) async {
    await _setBusy(harnessId, provider, true);
    try {
      await action();
      if (!isClosed) {
        emit(state.copyWith(status: UiFlowStatus.success, error: null));
      }
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
        error: e,
        source: 'HarnessAuthCubit',
        operation: 'harnessOperation',
      );
      if (!isClosed) {
        emit(state.copyWith(status: UiFlowStatus.failure, error: e));
      }
    } finally {
      await _setBusy(harnessId, provider, false);
    }
  }

  void _updateStatus(
      String harnessId, String provider, HarnessAuthStatus status) {
    if (isClosed) return;
    final next = Map<HarnessProviderKey, HarnessAuthStatus>.from(state.statuses)
      ..[HarnessProviderKey(harnessId, provider)] = status;
    emit(state.copyWith(
        statuses: next, status: UiFlowStatus.success, error: null));
  }

  Future<void> _refreshStatuses() async {
    if (state.harnesses.isEmpty) return;
    await Future.wait(state.harnesses.map((h) => _safeRefreshHarness(h.id)));
  }

  Future<void> _safeRefreshHarness(String harnessId) async {
    final provider = _oauthProviderFor(harnessId);
    if (provider == null) {
      return; // no oauth-capable provider -- nothing to check
    }
    try {
      _updateStatus(
          harnessId,
          provider,
          await _authRepository.status(
              harnessId: harnessId, provider: provider));
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
        error: e,
        source: 'HarnessAuthCubit',
        operation: 'refreshStatus',
      );
      if (!isClosed) {
        emit(state.copyWith(status: UiFlowStatus.failure, error: e));
      }
    }
  }

  Future<void> refreshHarness(String harnessId,
      [String? requestedProvider]) async {
    final provider = requestedProvider ?? _oauthProviderFor(harnessId);
    if (provider == null) return;
    final snapshot = state.statusFor(harnessId, provider);
    return _withBusy(
        harnessId,
        provider,
        () => _authRepository
            .status(
              harnessId: harnessId,
              provider: provider,
              accountId: snapshot?.accountId,
              attemptId: snapshot?.attempt?.id,
            )
            .then((s) => _updateStatus(harnessId, provider, s)));
  }

  Future<void> startWithAccount({
    required String harnessId,
    required String provider,
    required String visibility,
  }) async =>
      _withBusy(
          harnessId,
          provider,
          () => _authRepository
              .start(
                harnessId: harnessId,
                provider: provider,
                mode: 'oauth',
                visibility: visibility,
              )
              .then((s) => _updateStatus(harnessId, provider, s)));

  /// [provider] is required for a multi-provider/non-oauth harness (e.g.
  /// Goose, OpenCode) -- those have no single [_oauthProviderFor] result, so
  /// the caller must resolve which provider's credential this applies to
  /// (e.g. the one the user just entered an API key for). Falls back to
  /// [_oauthProviderFor] when omitted, for the existing single-provider
  /// harness call site.
  Future<void> startWithNone(String harnessId,
      {String? provider, required String visibility}) async {
    final resolvedProvider = provider ?? _oauthProviderFor(harnessId);
    if (resolvedProvider == null) return;
    await _withBusy(
        harnessId,
        resolvedProvider,
        () => _authRepository
            .start(
              harnessId: harnessId,
              provider: resolvedProvider,
              mode: 'none',
              visibility: visibility,
            )
            .then((s) => _updateStatus(harnessId, resolvedProvider, s)));
  }

  Future<void> poll(String harnessId, [String? requestedProvider]) async {
    final provider = requestedProvider ?? _oauthProviderFor(harnessId);
    if (provider == null) return;
    final snapshot = state.statusFor(harnessId, provider);
    await _withBusy(
        harnessId,
        provider,
        () => _authRepository
            .poll(
              harnessId: harnessId,
              provider: provider,
              accountId: snapshot?.accountId,
              attemptId: snapshot?.attempt?.id,
            )
            .then((s) => _updateStatus(harnessId, provider, s)));
  }

  Future<void> submitCode(
      {required String harnessId,
      required String code,
      String? provider}) async {
    provider ??= _oauthProviderFor(harnessId);
    if (provider == null) return;
    final selectedProvider = provider;
    final snapshot = state.statusFor(harnessId, selectedProvider);
    await _withBusy(
        harnessId,
        selectedProvider,
        () => _authRepository
            .submit(
              harnessId: harnessId,
              provider: selectedProvider,
              accountId: snapshot?.accountId,
              code: code,
              attemptId: snapshot?.attempt?.id,
            )
            .then((s) => _updateStatus(harnessId, selectedProvider, s)));
  }

  Future<void> cancel(String harnessId, [String? requestedProvider]) async {
    final provider = requestedProvider ?? _oauthProviderFor(harnessId);
    if (provider == null) return;
    final snapshot = state.statusFor(harnessId, provider);
    await _withBusy(
        harnessId,
        provider,
        () => _authRepository
            .cancel(
              harnessId: harnessId,
              provider: provider,
              accountId: snapshot?.accountId,
              attemptId: snapshot?.attempt?.id,
            )
            .then((s) => _updateStatus(harnessId, provider, s)));
  }

  Future<void> disconnect(String harnessId, [String? requestedProvider]) async {
    final provider = requestedProvider ?? _oauthProviderFor(harnessId);
    if (provider == null) return;
    final snapshot = state.statusFor(harnessId, provider);
    await _withBusy(
        harnessId,
        provider,
        () => _authRepository
            .disconnect(
              harnessId: harnessId,
              provider: provider,
              accountId: snapshot?.accountId,
            )
            .then((s) => _updateStatus(harnessId, provider, s)));
  }

  @override
  Future<void> close() {
    _harnessSub?.cancel();
    _harnessProvidersSub?.cancel();
    return super.close();
  }
}
