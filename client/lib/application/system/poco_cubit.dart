import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../presentation/core/widgets/ascii_art.dart';

part 'poco_cubit.freezed.dart';

@freezed
class PocoState with _$PocoState {
  const factory PocoState({
    required String message,
    required List<(String, int)> sequence,
    @Default([]) List<String> history,
  }) = _PocoState;

  factory PocoState.initial() => const PocoState(
        message: "Awaiting instructions...",
        sequence: [
          (PocoExpression.awake, 2000),
          (PocoExpression.sleepy, 150),
        ],
      );
}

@lazySingleton
class PocoCubit extends Cubit<PocoState> {
  PocoCubit() : super(PocoState.initial());

  void updateMessage(String newMessage,
      {List<(String, int)>? sequence, bool addToHistory = true}) {
    final history =
        addToHistory ? [...state.history, state.message] : state.history;
    emit(state.copyWith(
      message: newMessage,
      sequence: sequence ?? state.sequence,
      history: history,
    ));
  }

  void setExpression(List<(String, int)> sequence) {
    emit(state.copyWith(sequence: sequence));
  }

  void reset(String initialMessage) {
    emit(PocoState.initial().copyWith(
      message: initialMessage,
      history: [],
    ));
  }

  void clearHistory() {
    emit(state.copyWith(history: []));
  }
}

class PocoExpressions {
  static const scanning = [
    (PocoExpression.lookLeft, 2000),
    (PocoExpression.sleepy, 150),
    (PocoExpression.lookRight, 2000),
    (PocoExpression.sleepy, 150),
    (PocoExpression.surprised, 1500),
  ];

  static const happy = [(PocoExpression.happy, 5000)];
  static const thinking = [(PocoExpression.thinking, 3000)];
  static const nervous = [(PocoExpression.nervous, 1000)];
}
