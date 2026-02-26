import 'package:freezed_annotation/freezed_annotation.dart';

part 'i_observability_repository.freezed.dart';
part 'i_observability_repository.g.dart';

abstract class IObservabilityRepository {
  /// Stream of logs for a specific container.
  Stream<String> watchLogs(String containerName);

  /// Fetches the system stats from the SQLPage dashboard.
  Future<SystemStats> fetchSystemStats();
}

@freezed
class SystemStats with _$SystemStats {
  const factory SystemStats({
    @Default(0) int totalMessages,
    @Default('\$0.00') String cumulativeCost,
    @Default(0) int cumulativeTokens,
    @Default('unknown') String backendStatus,
    @Default([]) List<OperationalTask> tasks,
    @Default([]) List<TokenUsage> tokenUsage,
  }) = _SystemStats;

  factory SystemStats.fromJson(Map<String, dynamic> json) {
    final List<dynamic> stats = json['total_messages'] != null ? [json] : [];
    final Map<String, dynamic> data = stats.isNotEmpty ? stats.first : {};

    final List<dynamic> tasksJson = (json['operational_tasks'] as List? ?? []);
    final List<dynamic> usageJson =
        (json['token_usage_by_model'] as List? ?? []);

    return SystemStats(
      totalMessages: data['total_messages'] as int? ?? 0,
      cumulativeCost: data['cumulative_cost'] as String? ?? '\$0.00',
      cumulativeTokens: data['cumulative_tokens'] as int? ?? 0,
      backendStatus: data['backend_status'] as String? ?? 'unknown',
      tasks: tasksJson.map((e) => OperationalTask.fromJson(e)).toList(),
      tokenUsage: usageJson.map((e) => TokenUsage.fromJson(e)).toList(),
    );
  }
}

@freezed
class OperationalTask with _$OperationalTask {
  const factory OperationalTask({
    required String id,
    required String status,
    required String sender,
    required String receiver,
    required String summary,
    required String timestamp,
  }) = _OperationalTask;

  factory OperationalTask.fromJson(Map<String, dynamic> json) =>
      OperationalTask(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        sender: json['sender'] as String? ?? '',
        receiver: json['receiver'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        timestamp: json['timestamp'] as String? ?? '',
      );
}

@freezed
class TokenUsage with _$TokenUsage {
  const factory TokenUsage({
    required String model,
    required int tokens,
  }) = _TokenUsage;

  factory TokenUsage.fromJson(Map<String, dynamic> json) => TokenUsage(
        model: json['model'] as String? ?? 'unknown',
        tokens: json['tokens'] as int? ?? 0,
      );
}
