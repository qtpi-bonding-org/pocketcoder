import 'package:flutter/foundation.dart';
import 'package:pocketcoder_pro/domain/deployment/walkthrough.dart';

@immutable
class WalkthroughState {
  const WalkthroughState._({
    required this.content,
    required this.walkthroughIndex,
    required this.briefIndex,
    required this.isCodeExpanded,
    required this.isSkipped,
    required this.isComplete,
    required this.completedBriefIds,
    required this.selectedBriefId,
    required this.expandedBriefIds,
    required this.faqHistory,
  });

  const WalkthroughState.initial()
      : content = null,
        walkthroughIndex = 0,
        briefIndex = 0,
        isCodeExpanded = false,
        isSkipped = false,
        isComplete = false,
        completedBriefIds = const {},
        selectedBriefId = null,
        expandedBriefIds = const {},
        faqHistory = const {};

  factory WalkthroughState.loaded(WalkthroughContent content) =>
      WalkthroughState._(
        content: content,
        walkthroughIndex: 0,
        briefIndex: 0,
        isCodeExpanded: false,
        isSkipped: false,
        isComplete: false,
        completedBriefIds: const {},
        selectedBriefId: null,
        expandedBriefIds: const {},
        faqHistory: const {},
      );

  final WalkthroughContent? content;
  final int walkthroughIndex;
  final int briefIndex;
  final bool isCodeExpanded;
  final bool isSkipped;
  final bool isComplete;
  final Set<String> completedBriefIds;
  final String? selectedBriefId;
  final Set<String> expandedBriefIds;
  final Map<String, List<WalkthroughFaqTurn>> faqHistory;

  bool get hasContent => content != null;

  int get walkthroughCount => content?.walkthroughs.length ?? 0;

  int get currentWalkthroughNumber => hasContent ? walkthroughIndex + 1 : 0;

  bool get isAtWalkthroughStart => hasContent && briefIndex == 0;

  Walkthrough? get currentWalkthrough {
    final currentContent = content;
    if (currentContent == null ||
        walkthroughIndex < 0 ||
        walkthroughIndex >= currentContent.walkthroughs.length) {
      return null;
    }
    return currentContent.walkthroughs[walkthroughIndex];
  }

  WalkthroughBrief? get currentBrief {
    final walkthrough = currentWalkthrough;
    if (walkthrough == null ||
        briefIndex < 0 ||
        briefIndex >= walkthrough.briefs.length) {
      return null;
    }
    return walkthrough.briefs[briefIndex];
  }

  String? get currentBriefId {
    final walkthrough = currentWalkthrough;
    final brief = currentBrief;
    if (walkthrough == null || brief == null) return null;
    return '${walkthrough.id}/${brief.id}';
  }

  WalkthroughState copyWith({
    int? walkthroughIndex,
    int? briefIndex,
    bool? isCodeExpanded,
    bool? isSkipped,
    bool? isComplete,
    Set<String>? completedBriefIds,
    String? selectedBriefId,
    Set<String>? expandedBriefIds,
    Map<String, List<WalkthroughFaqTurn>>? faqHistory,
  }) =>
      WalkthroughState._(
        content: content,
        walkthroughIndex: walkthroughIndex ?? this.walkthroughIndex,
        briefIndex: briefIndex ?? this.briefIndex,
        isCodeExpanded: isCodeExpanded ?? this.isCodeExpanded,
        isSkipped: isSkipped ?? this.isSkipped,
        isComplete: isComplete ?? this.isComplete,
        completedBriefIds: Set.unmodifiable(
          completedBriefIds ?? this.completedBriefIds,
        ),
        selectedBriefId: selectedBriefId ?? this.selectedBriefId,
        expandedBriefIds: Set.unmodifiable(
          expandedBriefIds ?? this.expandedBriefIds,
        ),
        faqHistory: Map.unmodifiable(
          faqHistory ?? this.faqHistory,
        ),
      );
}
