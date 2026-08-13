import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'harness_account_selection.freezed.dart';
part 'harness_account_selection.g.dart';

@freezed
abstract class HarnessAccountSelection with _$HarnessAccountSelection {
  const factory HarnessAccountSelection({
    required String id,
    required String user,
    required String harness,
    required String account,
    DateTime? created,
    DateTime? updated,
  }) = _HarnessAccountSelection;

  factory HarnessAccountSelection.fromRecord(RecordModel record) =>
      HarnessAccountSelection.fromJson(record.toJson());

  factory HarnessAccountSelection.fromJson(Map<String, dynamic> json) =>
      _$HarnessAccountSelectionFromJson(json);
}
