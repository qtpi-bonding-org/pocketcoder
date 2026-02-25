import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/evolution/i_evolution_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'sop_state.dart';

@injectable
class SopCubit extends Cubit<SopState> {
  final IEvolutionRepository _repository;
  StreamSubscription? _sopsSub;
  StreamSubscription? _proposalsSub;

  SopCubit(this._repository) : super(const SopState());

  @override
  Future<void> close() {
    _sopsSub?.cancel();
    _proposalsSub?.cancel();
    return super.close();
  }

  void initialize() {
    emit(state.copyWith(isLoading: true));

    _sopsSub?.cancel();
    _sopsSub = _repository.watchSops().listen(
          (sops) => emit(state.copyWith(sops: sops, isLoading: false)),
          onError: (e) =>
              emit(state.copyWith(error: e.toString(), isLoading: false)),
        );

    _proposalsSub?.cancel();
    _proposalsSub = _repository.watchProposals().listen(
          (proposals) => emit(state.copyWith(proposals: proposals)),
          onError: (e) => emit(state.copyWith(error: e.toString())),
        );
  }

  Future<void> approveProposal(String id) async {
    try {
      await _repository.approveProposal(id);
    } catch (e) {
      logError('SOP: Failed to approve proposal', e);
      emit(state.copyWith(error: e.toString()));
    }
  }
}
