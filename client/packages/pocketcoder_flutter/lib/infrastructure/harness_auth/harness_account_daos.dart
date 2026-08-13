import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/domain/models/harness_account.dart';
import 'package:pocketcoder_flutter/domain/models/harness_account_selection.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';

@lazySingleton
class HarnessAccountDao extends BaseDao<HarnessAccount> {
  HarnessAccountDao(PocketBase pb)
      : super(pb, Collections.harnessAccounts, HarnessAccount.fromJson);
}

@lazySingleton
class HarnessAccountSelectionDao extends BaseDao<HarnessAccountSelection> {
  HarnessAccountSelectionDao(PocketBase pb)
      : super(
          pb,
          Collections.harnessAccountSelections,
          HarnessAccountSelection.fromJson,
        );
}
