import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/sop/sop.dart';
import '../../domain/proposal/proposal.dart';

part 'sop_state.freezed.dart';

@freezed
class SopState with _$SopState {
  const factory SopState({
    @Default([]) List<Sop> sops,
    @Default([]) List<Proposal> proposals,
    @Default(false) bool isLoading,
    String? error,
  }) = _SopState;
}
