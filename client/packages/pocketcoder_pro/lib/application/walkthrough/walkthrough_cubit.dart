import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_pro/domain/deployment/provisioning_walkthrough.dart';

import 'walkthrough_state.dart';

/// Owns reader-controlled walkthrough state independently of deployment.
///
/// Call [loadContent] once the immutable source commit is available. Calling it
/// again for that same commit/backend is intentionally a no-op, so deployment
/// status updates and widget rebuilds never rewind the walkthrough.
class WalkthroughCubit extends Cubit<WalkthroughState> {
  WalkthroughCubit() : super(const WalkthroughState.initial());

  void loadContent(ProvisioningWalkthroughContent content) {
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

  void nextBriefing() {
    final currentContent = state.content;
    final currentWalkthrough = state.currentWalkthrough;
    final briefingId = state.currentBriefingId;
    if (currentContent == null ||
        currentWalkthrough == null ||
        briefingId == null ||
        state.isSkipped ||
        state.isComplete) {
      return;
    }

    final completed = {...state.completedBriefingIds, briefingId};
    if (state.briefingIndex + 1 < currentWalkthrough.briefings.length) {
      emit(state.copyWith(
        briefingIndex: state.briefingIndex + 1,
        isCodeExpanded: false,
        completedBriefingIds: completed,
      ));
      return;
    }
    if (state.walkthroughIndex + 1 < currentContent.walkthroughs.length) {
      emit(state.copyWith(
        walkthroughIndex: state.walkthroughIndex + 1,
        briefingIndex: 0,
        isCodeExpanded: false,
        completedBriefingIds: completed,
      ));
      return;
    }
    emit(state.copyWith(
      isCodeExpanded: false,
      isComplete: true,
      completedBriefingIds: completed,
    ));
  }

  void previousBriefing() {
    final currentContent = state.content;
    if (currentContent == null || state.isSkipped) return;
    if (state.briefingIndex > 0) {
      emit(state.copyWith(
        briefingIndex: state.briefingIndex - 1,
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
      briefingIndex: previousWalkthrough.briefings.length - 1,
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
