import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ErrorInboxState {
  const ErrorInboxState({this.errors = const [], this.isLoading = false});

  final List<ErrorBoxEntry> errors;
  final bool isLoading;

  ErrorInboxState copyWith({List<ErrorBoxEntry>? errors, bool? isLoading}) {
    return ErrorInboxState(
      errors: errors ?? this.errors,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ErrorInboxCubit extends Cubit<ErrorInboxState> {
  ErrorInboxCubit() : super(const ErrorInboxState());

  Future<void> loadErrors() async {
    emit(state.copyWith(isLoading: true));
    try {
      emit(ErrorInboxState(errors: await ErrorPrivserver.getUnsentErrors()));
    } finally {
      if (!isClosed) emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> deleteError(String id) async {
    final storage = ErrorPrivserverMixin.config?.storage;
    if (storage == null) return;
    await storage.deleteError(id);
    await loadErrors();
  }
}
