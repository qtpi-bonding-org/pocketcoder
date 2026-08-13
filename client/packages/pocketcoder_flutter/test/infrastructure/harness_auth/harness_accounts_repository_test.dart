import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/models/harness_account.dart';
import 'package:pocketcoder_flutter/domain/models/harness_account_selection.dart';
import 'package:pocketcoder_flutter/infrastructure/harness_auth/harness_account_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/harness_auth/harness_accounts_repository.dart';

class MockHarnessAccountDao extends Mock implements HarnessAccountDao {}
class MockHarnessAccountSelectionDao extends Mock
    implements HarnessAccountSelectionDao {}

const account = HarnessAccount(
  id: 'account1',
  harness: 'harness1',
  owner: 'user1',
  name: 'Shared Codex',
  visibility: HarnessAccountVisibility.deployment,
  credentialMode: HarnessAccountCredentialMode.apiKey,
  status: HarnessAccountStatus.disconnected,
);

const selection = HarnessAccountSelection(
  id: 'selection1',
  user: 'user1',
  harness: 'harness1',
  account: 'account1',
);

void main() {
  late MockHarnessAccountDao accounts;
  late MockHarnessAccountSelectionDao selections;
  late HarnessAccountsRepository repository;

  setUp(() {
    accounts = MockHarnessAccountDao();
    selections = MockHarnessAccountSelectionDao();
    repository = HarnessAccountsRepository(accounts, selections);
  });

  test('writes PocketBase select values rather than Dart enum names', () async {
    when(() => accounts.save(any(), any())).thenAnswer((_) async => account);

    await repository.createAccount(
      harnessId: 'harness1',
      name: 'Shared Codex',
      visibility: HarnessAccountVisibility.deployment,
      credentialMode: HarnessAccountCredentialMode.apiKey,
    );

    verify(() => accounts.save(null, {
          'harness': 'harness1',
          'name': 'Shared Codex',
          'visibility': 'deployment',
          'credential_mode': 'api_key',
        })).called(1);
  });

  test('upserts the caller selection by its PocketBase record id', () async {
    when(() => selections.getFullList(filter: any(named: 'filter')))
        .thenAnswer((_) async => [selection]);
    when(() => selections.save(any(), any()))
        .thenAnswer((_) async => selection);

    expect(
      await repository.selectAccount(
        harnessId: 'harness1',
        accountId: 'account1',
      ),
      selection,
    );
    verify(() => selections.save('selection1', {'account': 'account1'}))
        .called(1);
  });
}
