import 'package:freezed_annotation/freezed_annotation.dart';

part 'usage.freezed.dart';
part 'usage.g.dart';

@freezed
class Usage with _$Usage {
  const factory Usage({
    required String id,
    @JsonKey(name: 'message_id') String? messageId,
    @JsonKey(name: 'part_id') String? partId,
    String? model,
    @JsonKey(name: 'tokens_prompt') int? tokensPrompt,
    @JsonKey(name: 'tokens_completion') int? tokensCompletion,
    @JsonKey(name: 'tokens_reasoning') int? tokensReasoning,
    double? cost,
    UsageStatus? status,
    DateTime? created,
    DateTime? updated,
  }) = _Usage;

  factory Usage.fromJson(Map<String, dynamic> json) => _$UsageFromJson(json);
}

enum UsageStatus {
  @JsonValue('in-progress')
  inProgress,
  @JsonValue('completed')
  completed,
  @JsonValue('error')
  error,
}

/// Usage statistics for display
class UsageStats {
  final int totalTokens;
  final double totalCost;
  final int totalRequests;

  UsageStats({
    required this.totalTokens,
    required this.totalCost,
    required this.totalRequests,
  });
}