// Regression test for a live crash: "Bad state: Cannot emit new states
// after calling close" thrown from HarnessAuthCubit._safeRefreshHarness.
//
// Root cause: _loadHarnesses()'s stream listener fires _refreshStatuses()
// (fire-and-forget, not awaited), which calls _authRepository.status() for
// each harness. If the cubit is closed (e.g. the user navigates away)
// while that network call is still in flight, the continuation resumes
// after close() and tries to emit() -- which throws, since bloc forbids
// emitting on a closed cubit. Same shape of bug existed at every other
// emit() site in this cubit that follows an async gap (_setBusy,
// _withBusy, _updateStatus, the watchHarnesses/watchProviderKeys stream
// listeners) -- all guarded with `if (isClosed) return;` by this fix.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';

class _MockProviderRepository extends Mock implements IProviderRepository {}

class _MockAuthRepository extends Mock implements IHarnessAuthRepository {}

const _providerId = 'provider-1';

Harnesse _harness(String id) => Harnesse(
      id: id,
      name: id,
      cliId: id,
      acpTransport: HarnesseAcpTransport.stdio,
    );

HarnessAuthStatus _status(String harnessId, String status) => HarnessAuthStatus(
      harness: harnessId,
      provider: _providerId,
      accountId: 'acct-1',
      accountName: 'acct',
      visibility: harnessAccountVisibilityPersonal,
      credentialMode: 'account',
      status: status,
    );

void main() {
  test(
      'closing the cubit while a harness status refresh is in flight does '
      'not throw when that refresh later resolves', () async {
    final providerRepository = _MockProviderRepository();
    final authRepository = _MockAuthRepository();
    final statusCompleter = Completer<HarnessAuthStatus>();

    when(() => providerRepository.watchHarnesses())
        .thenAnswer((_) => Stream.value([_harness('harness-1')]));
    when(() => providerRepository.watchHarnessProviders())
        .thenAnswer((_) => Stream.value([
              const HarnessProvider(
                id: 'edge-1',
                harness: 'harness-1',
                provider: _providerId,
                supportsOauth: true,
              ),
            ]));
    when(() => authRepository.status(
          harnessId: 'harness-1',
          provider: any(named: 'provider'),
        )).thenAnswer((_) => statusCompleter.future);

    final cubit = HarnessAuthCubit(
      providerRepository: providerRepository,
      authRepository: authRepository,
    );

    cubit.watchData();
    // Let the harnesses stream deliver its value and _refreshStatuses()
    // reach its (uncompleted) await on authRepository.status().
    await pumpEventQueue();

    // Simulate the widget disposing the cubit before the status call
    // resolves -- this must not throw on its own.
    await cubit.close();

    // Resolve the in-flight status call after close(). Before the fix,
    // the resumed continuation's emit() call threw synchronously inside
    // an unawaited Future, which flutter_test's zone captures as a test
    // failure if it isn't guarded.
    statusCompleter.complete(_status('harness-1', 'connected'));
    await pumpEventQueue();
  });
}
