import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_pro/domain/deployment/walkthrough.dart';

import 'walkthrough_state.dart';

/// Owns reader-controlled walkthrough state independently of deployment.
///
/// Call [loadContent] once the immutable source commit is available. Calling it
/// again for that same commit/backend is intentionally a no-op, so deployment
/// status updates and widget rebuilds never rewind the walkthrough.
class WalkthroughCubit extends Cubit<WalkthroughState> {
  WalkthroughCubit() : super(const WalkthroughState.initial());

  void loadContent(WalkthroughContent content) {
    final currentContent = state.content;
    if (currentContent != null && currentContent.hasSameIdentityAs(content)) {
      return;
    }
    emit(WalkthroughState.loaded(content));
  }

  void setCodeExpanded(bool expanded) {
    if (!state.hasContent || state.isSkipped) return;
    emit(state.copyWith(isCodeExpanded: expanded));
  }

  void selectBriefForPresentation(String briefId) {
    if (!state.hasContent || state.isSkipped) return;
    emit(state.copyWith(selectedBriefId: briefId));
  }

  void setBriefExpanded(String briefId, bool expanded) {
    if (!state.hasContent || state.isSkipped) return;
    final expandedBriefs = {...state.expandedBriefIds};
    if (expanded) {
      expandedBriefs.add(briefId);
    } else {
      expandedBriefs.remove(briefId);
    }
    emit(state.copyWith(expandedBriefIds: expandedBriefs));
  }

  void addFaqTurn(String walkthroughId, WalkthroughFaqTurn turn) {
    if (!state.hasContent || state.isSkipped) return;
    final history = <String, List<WalkthroughFaqTurn>>{
      ...state.faqHistory,
      walkthroughId: [
        ...(state.faqHistory[walkthroughId] ?? const []),
        turn,
      ],
    };
    emit(state.copyWith(faqHistory: history));
  }

  void nextBrief() {
    final currentContent = state.content;
    final currentWalkthrough = state.currentWalkthrough;
    final briefId = state.currentBriefId;
    if (currentContent == null ||
        currentWalkthrough == null ||
        briefId == null ||
        state.isSkipped ||
        state.isComplete) {
      return;
    }

    final completed = {...state.completedBriefIds, briefId};
    if (state.briefIndex + 1 < currentWalkthrough.briefs.length) {
      emit(state.copyWith(
        briefIndex: state.briefIndex + 1,
        isCodeExpanded: false,
        completedBriefIds: completed,
      ));
      return;
    }
    if (state.walkthroughIndex + 1 < currentContent.walkthroughs.length) {
      emit(state.copyWith(
        walkthroughIndex: state.walkthroughIndex + 1,
        briefIndex: 0,
        isCodeExpanded: false,
        completedBriefIds: completed,
      ));
      return;
    }
    emit(state.copyWith(
      isCodeExpanded: false,
      isComplete: true,
      completedBriefIds: completed,
    ));
  }

  void selectBrief(String briefId) {
    final currentContent = state.content;
    if (currentContent == null || state.isSkipped) return;

    for (var walkthroughIndex = 0;
        walkthroughIndex < currentContent.walkthroughs.length;
        walkthroughIndex += 1) {
      final briefs = currentContent.walkthroughs[walkthroughIndex].briefs;
      final briefIndex = briefs.indexWhere((brief) => brief.id == briefId);
      if (briefIndex < 0) continue;
      emit(state.copyWith(
        walkthroughIndex: walkthroughIndex,
        briefIndex: briefIndex,
        isCodeExpanded: false,
        isComplete: false,
      ));
      return;
    }
  }

  void previousBrief() {
    final currentContent = state.content;
    if (currentContent == null || state.isSkipped) return;
    if (state.briefIndex > 0) {
      emit(state.copyWith(
        briefIndex: state.briefIndex - 1,
        isCodeExpanded: false,
      ));
      return;
    }
    if (state.walkthroughIndex == 0) return;
    final previousWalkthroughIndex = state.walkthroughIndex - 1;
    final previousWalkthrough =
        currentContent.walkthroughs[previousWalkthroughIndex];
    emit(state.copyWith(
      walkthroughIndex: previousWalkthroughIndex,
      briefIndex: previousWalkthrough.briefs.length - 1,
      isCodeExpanded: false,
    ));
  }

  void skip() {
    if (!state.hasContent || state.isComplete) return;
    emit(state.copyWith(isSkipped: true, isCodeExpanded: false));
  }

  void resume() {
    if (!state.hasContent || !state.isSkipped) return;
    emit(state.copyWith(isSkipped: false));
  }

  void reset() => emit(const WalkthroughState.initial());
}
