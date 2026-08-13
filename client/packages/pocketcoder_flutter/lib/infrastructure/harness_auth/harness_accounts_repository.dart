import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_accounts_repository.dart';
import 'package:pocketcoder_flutter/domain/models/harness_account.dart';
import 'package:pocketcoder_flutter/domain/models/harness_account_selection.dart';
import 'package:pocketcoder_flutter/infrastructure/harness_auth/harness_account_daos.dart';

@LazySingleton(as: IHarnessAccountsRepository)
class HarnessAccountsRepository implements IHarnessAccountsRepository {
  HarnessAccountsRepository(this._accounts, this._selections);

  final HarnessAccountDao _accounts;
  final HarnessAccountSelectionDao _selections;

  @override
  Future<List<HarnessAccount>> listAccounts(String harnessId) {
    _requireRecordId(harnessId, 'harnessId');
    return _accounts.getFullList(
      filter: 'harness = "$harnessId"',
      sort: 'name',
    );
  }

  @override
  Future<HarnessAccount> createAccount({
    required String harnessId,
    required String name,
    required HarnessAccountVisibility visibility,
    required HarnessAccountCredentialMode credentialMode,
  }) =>
      _accounts.save(null, {
        'harness': harnessId,
        'name': name,
        'visibility': _visibilityValue(visibility),
        'credential_mode': _credentialModeValue(credentialMode),
      });

  @override
  Future<HarnessAccount> updateAccount({
    required String id,
    String? name,
    HarnessAccountVisibility? visibility,
    HarnessAccountCredentialMode? credentialMode,
  }) =>
      _accounts.save(id, {
        if (name != null) 'name': name,
        if (visibility != null) 'visibility': _visibilityValue(visibility),
        if (credentialMode != null)
          'credential_mode': _credentialModeValue(credentialMode),
      });

  @override
  Future<void> deleteAccount(String id) => _accounts.delete(id);

  @override
  Future<HarnessAccountSelection?> selectedAccount(String harnessId) async {
    _requireRecordId(harnessId, 'harnessId');
    final rows = await _selections.getFullList(
      filter: 'harness = "$harnessId"',
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<HarnessAccountSelection> selectAccount({
    required String harnessId,
    required String accountId,
  }) async {
    final current = await selectedAccount(harnessId);
    return _selections.save(current?.id, {
      if (current == null) 'harness': harnessId,
      'account': accountId,
    });
  }

  String _visibilityValue(HarnessAccountVisibility value) => switch (value) {
        HarnessAccountVisibility.personal => 'personal',
        HarnessAccountVisibility.deployment => 'deployment',
        HarnessAccountVisibility.unknown =>
          throw ArgumentError.value(value, 'visibility'),
      };

  String _credentialModeValue(HarnessAccountCredentialMode value) =>
      switch (value) {
        HarnessAccountCredentialMode.account => 'account',
        HarnessAccountCredentialMode.apiKey => 'api_key',
        HarnessAccountCredentialMode.none => 'none',
        HarnessAccountCredentialMode.unknown =>
          throw ArgumentError.value(value, 'credentialMode'),
      };

  void _requireRecordId(String value, String name) {
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(value)) {
      throw ArgumentError.value(value, name, 'must be a PocketBase record id');
    }
  }
}
