import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/hitl/i_hitl_repository.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'question_state.dart';

@injectable
class QuestionCubit extends Cubit<QuestionState> {
  final IHitlRepository _repository;
  StreamSubscription? _subscription;

  QuestionCubit(this._repository) : super(const QuestionState.initial());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchChat(String chatId) {
    logInfo('❓ [QuestionCubit] Watching for questions on chat: $chatId');
    emit(const QuestionState.loading());
    _subscription?.cancel();
    _subscription = _repository.watchQuestions(chatId).listen(
      (questions) {
        if (questions.isNotEmpty) {
          logInfo(
              '❓ [QuestionCubit] Found ${questions.length} asked questions.');
        }
        emit(QuestionState.loaded(questions));
      },
      onError: (e) {
        logError('❓ [QuestionCubit] Error watching questions: $e');
        emit(QuestionState.error(e.toString()));
      },
    );
  }

  Future<void> answer(String questionId, String reply) async {
    logInfo('❓ [QuestionCubit] Answering question: $questionId');
    try {
      await _repository.answerQuestion(questionId, reply);
      logInfo('❓ [QuestionCubit] Question $questionId answered successfully.');
    } catch (e) {
      logError('❓ [QuestionCubit] Failed to answer $questionId: $e');
    }
  }

  Future<void> reject(String questionId) async {
    logInfo('❓ [QuestionCubit] Rejecting question: $questionId');
    try {
      await _repository.rejectQuestion(questionId);
      logInfo('❓ [QuestionCubit] Question $questionId rejected.');
    } catch (e) {
      logError('❓ [QuestionCubit] Failed to reject $questionId: $e');
    }
  }
}
