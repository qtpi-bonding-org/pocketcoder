import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/credential_selection.dart';
import 'package:pocketcoder_flutter/domain/models/harness_oauth_account.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/harness_auth/harness_account_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/harness_auth/harness_auth_repository.dart';

class MockPocketCoderApiClient extends Mock implements PocketCoderApiClient {}

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockHarnessOAuthAccountDao extends Mock
    implements HarnessOAuthAccountDao {}

class MockCredentialSelectionDao extends Mock
    implements CredentialSelectionDao {}

HarnessOauthAccount _oauthAccount(HarnessOauthAccountStatus status) =>
    HarnessOauthAccount(
      id: 'account-1',
      harness: 'goose',
      provider: 'google',
      owner: 'user-1',
      name: 'Account',
      visibility: HarnessOauthAccountVisibility.personal,
      status: status,
    );

CredentialSelection _credentialSelection(
        {required CredentialSelectionMode mode}) =>
    CredentialSelection(
      id: 'selection-1',
      user: 'user-1',
      harness: 'goose',
      provider: 'google',
      mode: mode,
    );

void main() {
  late HarnessAuthRepository repository;
  late MockHarnessOAuthAccountDao oauthAccountDao;
  late MockCredentialSelectionDao credentialSelectionDao;

  setUp(() {
    oauthAccountDao = MockHarnessOAuthAccountDao();
    credentialSelectionDao = MockCredentialSelectionDao();
    repository = HarnessAuthRepository(
      MockPocketCoderApiClient(),
      MockAuthRepository(),
      oauthAccountDao,
      credentialSelectionDao,
    );
  });

  test('maps structured device-code challenge fields without losing semantics',
      () {
    final challenge = generated.HarnessAuthChallenge((b) {
      b.type = 'device';
      b.text = 'Use the browser to continue';
      b.kind = generated.HarnessAuthChallengeKindEnum.deviceCode;
      b.verificationUri = 'https://example.test/device';
      b.userCode = 'ABCD-1234';
      b.codeDestination =
          generated.HarnessAuthChallengeCodeDestinationEnum.browser;
      b.pollIntervalSeconds = 4;
    });

    final domain = HarnessAuthChallenge.fromGenerated(challenge);

    expect(domain.kind, 'device_code');
    expect(domain.verificationUri, Uri.parse('https://example.test/device'));
    expect(domain.userCode, 'ABCD-1234');
    expect(domain.codeDestination, HarnessAuthCodeDestination.browser);
    expect(domain.pollIntervalSeconds, 4);
  });

  test('legacy-only challenge does not infer structured fields from prose', () {
    final challenge = generated.HarnessAuthChallenge((b) {
      b.type = 'input';
      b.text = 'Enter this one-time code ABCD-1234 in your browser';
      b.target = 'code';
      b.details = 'legacy challenge';
    });

    final domain = HarnessAuthChallenge.fromGenerated(challenge);

    expect(domain.kind, isNull);
    expect(domain.verificationUri, isNull);
    expect(domain.userCode, isNull);
    expect(domain.codeDestination, HarnessAuthCodeDestination.unknown);
    expect(domain.pollIntervalSeconds, isNull);
    // ignore: deprecated_member_use
    expect(domain.legacyText, challenge.text);
  });

  test('true for an OAuth-connected account', () async {
    when(() => oauthAccountDao.getFullList(
            requestPolicy: RequestPolicy.networkOnly))
        .thenAnswer(
            (_) async => [_oauthAccount(HarnessOauthAccountStatus.connected)]);
    when(() => credentialSelectionDao.getFullList(
        requestPolicy: RequestPolicy.networkOnly)).thenAnswer((_) async => []);
    expect(await repository.hasEffectiveHarnessConnection(), isTrue);
  });

  test('true for a mode:none credential selection with no OAuth account at all',
      () async {
    when(() => oauthAccountDao.getFullList(
        requestPolicy: RequestPolicy.networkOnly)).thenAnswer((_) async => []);
    when(() => credentialSelectionDao.getFullList(
            requestPolicy: RequestPolicy.networkOnly))
        .thenAnswer((_) async =>
            [_credentialSelection(mode: CredentialSelectionMode.none)]);
    expect(await repository.hasEffectiveHarnessConnection(), isTrue);
  });

  test(
      'a credential selection with mode oauth/apiKey/unknown does not count on its own',
      () async {
    when(() => oauthAccountDao.getFullList(
        requestPolicy: RequestPolicy.networkOnly)).thenAnswer((_) async => []);
    when(() => credentialSelectionDao.getFullList(
            requestPolicy: RequestPolicy.networkOnly))
        .thenAnswer((_) async =>
            [_credentialSelection(mode: CredentialSelectionMode.apiKey)]);
    expect(await repository.hasEffectiveHarnessConnection(), isFalse);
  });

  test('retries an empty/failed result up to 8 times before returning false',
      () async {
    var calls = 0;
    when(() => oauthAccountDao.getFullList(
        requestPolicy: RequestPolicy.networkOnly)).thenAnswer((_) async {
      calls++;
      return [];
    });
    when(() => credentialSelectionDao.getFullList(
        requestPolicy: RequestPolicy.networkOnly)).thenAnswer((_) async => []);
    expect(await repository.hasEffectiveHarnessConnection(), isFalse);
    expect(calls, 8);
  });
}
