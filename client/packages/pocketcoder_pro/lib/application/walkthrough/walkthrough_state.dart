import 'package:flutter/foundation.dart';
import 'package:pocketcoder_pro/domain/deployment/provisioning_walkthrough.dart';

@immutable
class WalkthroughState {
  const WalkthroughState._({
    required this.content,
    required this.walkthroughIndex,
    required this.briefingIndex,
    required this.isCodeExpanded,
    required this.isSkipped,
    required this.isComplete,
    required this.completedBriefingIds,
  });

  const WalkthroughState.initial()
      : content = null,
        walkthroughIndex = 0,
        briefingIndex = 0,
        isCodeExpanded = false,
        isSkipped = false,
        isComplete = false,
        completedBriefingIds = const {};

  factory WalkthroughState.loaded(ProvisioningWalkthroughContent content) =>
      WalkthroughState._(
        content: content,
        walkthroughIndex: 0,
        briefingIndex: 0,
        isCodeExpanded: false,
        isSkipped: false,
        isComplete: false,
        completedBriefingIds: const {},
      );

  final ProvisioningWalkthroughContent? content;
  final int walkthroughIndex;
  final int briefingIndex;
  final bool isCodeExpanded;
  final bool isSkipped;
  final bool isComplete;
  final Set<String> completedBriefingIds;

  bool get hasContent => content != null;

  ProvisioningWalkthrough? get currentWalkthrough {
    final currentContent = content;
    if (currentContent == null ||
        walkthroughIndex < 0 ||
        walkthroughIndex >= currentContent.walkthroughs.length) {
      return null;
    }
    return currentContent.walkthroughs[walkthroughIndex];
  }

  ProvisioningBriefing? get currentBriefing {
    final walkthrough = currentWalkthrough;
    if (walkthrough == null ||
        briefingIndex < 0 ||
        briefingIndex >= walkthrough.briefings.length) {
      return null;
    }
    return walkthrough.briefings[briefingIndex];
  }

  String? get currentBriefingId {
    final walkthrough = currentWalkthrough;
    final briefing = currentBriefing;
    if (walkthrough == null || briefing == null) return null;
    return '${walkthrough.id}/${briefing.id}';
  }

  WalkthroughState copyWith({
    int? walkthroughIndex,
    int? briefingIndex,
    bool? isCodeExpanded,
    bool? isSkipped,
    bool? isComplete,
    Set<String>? completedBriefingIds,
  }) =>
      WalkthroughState._(
        content: content,
        walkthroughIndex: walkthroughIndex ?? this.walkthroughIndex,
        briefingIndex: briefingIndex ?? this.briefingIndex,
        isCodeExpanded: isCodeExpanded ?? this.isCodeExpanded,
        isSkipped: isSkipped ?? this.isSkipped,
        isComplete: isComplete ?? this.isComplete,
        completedBriefingIds: Set.unmodifiable(
          completedBriefingIds ?? this.completedBriefingIds,
        ),
      );
}
