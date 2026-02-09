import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import '../../domain/whitelist/i_whitelist_repository.dart';
import '../../domain/whitelist/whitelist_action.dart';
import '../../domain/whitelist/whitelist_target.dart';

part 'whitelist_state.dart';
part 'whitelist_cubit.freezed.dart';

@injectable
class WhitelistCubit extends Cubit<WhitelistState> {
  final IWhitelistRepository _repository;

  WhitelistCubit(this._repository) : super(const WhitelistState.initial());

  Future<void> load() async {
    emit(const WhitelistState.loading());
    try {
      final targets = await _repository.getTargets();
      final actions = await _repository.getActions();
      emit(WhitelistState.loaded(targets: targets, actions: actions));
    } catch (e) {
      emit(WhitelistState.error(e.toString()));
    }
  }

  Future<void> createTarget(String name, String pattern, String type) async {
    try {
      await _repository.createTarget(name, pattern, type);
      load(); // Refresh
    } catch (e) {
      emit(WhitelistState.error(e.toString()));
    }
  }

  Future<void> deleteTarget(String id) async {
    try {
      await _repository.deleteTarget(id);
      load();
    } catch (e) {
      emit(WhitelistState.error(e.toString()));
    }
  }

  Future<void> createAction(String command, String targetId) async {
    try {
      await _repository.createAction(command, targetId);
      load();
    } catch (e) {
      emit(WhitelistState.error(e.toString()));
    }
  }

  Future<void> deleteAction(String id) async {
    try {
      await _repository.deleteAction(id);
      load();
    } catch (e) {
      emit(WhitelistState.error(e.toString()));
    }
  }

  Future<void> toggleAction(String id, bool isActive) async {
    try {
      await _repository.toggleAction(id, isActive);
      load(); // Ideally optimistic update, but simple reload is safer for now
    } catch (e) {
      emit(WhitelistState.error(e.toString()));
    }
  }
}
