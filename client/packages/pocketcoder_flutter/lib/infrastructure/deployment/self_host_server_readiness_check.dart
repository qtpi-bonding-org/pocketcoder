import 'dart:async';

import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';

class SelfHostServerReadinessCheck implements IServerReadinessCheck {
  SelfHostServerReadinessCheck({required IAuthRepository authRepository})
      : _authRepository = authRepository;

  final IAuthRepository _authRepository;
  final _controller =
      StreamController<ServerReadinessSnapshot>.broadcast(sync: true);
  ServerReadinessSnapshot _current = const ServerReadinessSnapshot(
      status: ServerReadinessStatus.notProvisioned);

  @override
  ServerReadinessSnapshot get current => _current;

  @override
  Stream<ServerReadinessSnapshot> get readinessChanges => _controller.stream;

  @override
  Future<void> initialize() => _refresh();

  @override
  Future<void> retry() => _refresh();

  Future<void> _refresh() async {
    final url = await _authRepository.getSavedBaseUrl();
    _current = ServerReadinessSnapshot(
      status: url == null
          ? ServerReadinessStatus.notProvisioned
          : ServerReadinessStatus.ready,
    );
    _controller.add(_current);
  }
}
