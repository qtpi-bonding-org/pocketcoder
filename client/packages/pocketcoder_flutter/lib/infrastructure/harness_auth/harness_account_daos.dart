import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/domain/models/harness_oauth_account.dart';
import 'package:pocketcoder_flutter/domain/models/credential_selection.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';

@lazySingleton
class HarnessOAuthAccountDao extends BaseDao<HarnessOauthAccount> {
  HarnessOAuthAccountDao(PocketBase pb)
      : super(
            pb, Collections.harnessOauthAccounts, HarnessOauthAccount.fromJson);
}

@lazySingleton
class CredentialSelectionDao extends BaseDao<CredentialSelection> {
  CredentialSelectionDao(PocketBase pb)
      : super(
            pb, Collections.credentialSelections, CredentialSelection.fromJson);
}
