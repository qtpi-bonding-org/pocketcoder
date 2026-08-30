import 'package:freezed_annotation/freezed_annotation.dart';

part 'i_memory_repository.freezed.dart';
part 'i_memory_repository.g.dart';

abstract class IMemoryRepository {
  Future<MemoryStats> fetchStats();
}

@freezed
sealed class MemoryStats with _$MemoryStats {
  const factory MemoryStats({
    @Default(0) int observations,
    @Default(0) int interpretations,
    @Default(0) int links,
    @Default([]) List<MemoryAccountSummary> byAccount,
    @Default([]) List<MemoryObservation> recentObservations,
    @Default([]) List<MemoryInterpretation> recentInterpretations,
  }) = _MemoryStats;

  factory MemoryStats.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] as Map<String, dynamic>? ?? {};
    final byAccountJson = json['by_account'] as List? ?? [];
    final recentObservationsJson = json['recent_observations'] as List? ?? [];
    final recentInterpretationsJson =
        json['recent_interpretations'] as List? ?? [];

    return MemoryStats(
      observations: counts['observations'] as int? ?? 0,
      interpretations: counts['interpretations'] as int? ?? 0,
      links: counts['links'] as int? ?? 0,
      byAccount: byAccountJson
          .map((e) => MemoryAccountSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentObservations: recentObservationsJson
          .map((e) => MemoryObservation.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentInterpretations: recentInterpretationsJson
          .map((e) => MemoryInterpretation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

@freezed
sealed class MemoryAccountSummary with _$MemoryAccountSummary {
  const factory MemoryAccountSummary({
    required String accountId,
    required String agentProfileId,
    required String agentName,
    @Default(0) int observations,
    @Default(0) int interpretations,
  }) = _MemoryAccountSummary;

  factory MemoryAccountSummary.fromJson(Map<String, dynamic> json) =>
      MemoryAccountSummary(
        accountId: json['accountId'] as String? ?? '',
        agentProfileId: json['agentProfileId'] as String? ?? '',
        agentName: json['agentName'] as String? ?? '',
        observations: json['observations'] as int? ?? 0,
        interpretations: json['interpretations'] as int? ?? 0,
      );
}

@freezed
sealed class MemoryObservation with _$MemoryObservation {
  const factory MemoryObservation({
    required String id,
    required String accountId,
    required String author,
    required String body,
    required String createdAt,
    required String updatedAt,
    required String retrievedAt,
  }) = _MemoryObservation;

  factory MemoryObservation.fromJson(Map<String, dynamic> json) =>
      MemoryObservation(
        id: json['id'] as String? ?? '',
        accountId: json['accountId'] as String? ?? '',
        author: json['author'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
        retrievedAt: json['retrievedAt'] as String? ?? '',
      );
}

@freezed
sealed class MemoryInterpretation with _$MemoryInterpretation {
  const factory MemoryInterpretation({
    required String id,
    required String accountId,
    required String author,
    required String body,
    required String createdAt,
    required String updatedAt,
    required String retrievedAt,
    @Default([]) List<String> linkedObservations,
  }) = _MemoryInterpretation;

  factory MemoryInterpretation.fromJson(Map<String, dynamic> json) =>
      MemoryInterpretation(
        id: json['id'] as String? ?? '',
        accountId: json['accountId'] as String? ?? '',
        author: json['author'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
        retrievedAt: json['retrievedAt'] as String? ?? '',
        linkedObservations: (json['linkedObservations'] as List? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}
