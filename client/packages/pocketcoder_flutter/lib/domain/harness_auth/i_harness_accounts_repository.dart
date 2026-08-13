import 'package:pocketcoder_flutter/domain/models/harness_account.dart';
import 'package:pocketcoder_flutter/domain/models/harness_account_selection.dart';

abstract class IHarnessAccountsRepository {
  Future<List<HarnessAccount>> listAccounts(String harnessId);

  Future<HarnessAccount> createAccount({
    required String harnessId,
    required String name,
    required HarnessAccountVisibility visibility,
    required HarnessAccountCredentialMode credentialMode,
  });

  Future<HarnessAccount> updateAccount({
    required String id,
    String? name,
    HarnessAccountVisibility? visibility,
    HarnessAccountCredentialMode? credentialMode,
  });

  Future<void> deleteAccount(String id);

  Future<HarnessAccountSelection?> selectedAccount(String harnessId);

  Future<HarnessAccountSelection> selectAccount({
    required String harnessId,
    required String accountId,
  });
}
