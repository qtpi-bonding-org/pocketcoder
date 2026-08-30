import 'package:freezed_annotation/freezed_annotation.dart';

part 'i_pocketbase_inspector_repository.freezed.dart';
part 'i_pocketbase_inspector_repository.g.dart';

abstract class IPocketbaseInspectorRepository {
  Future<PocketbaseInspectorStats> fetchStats();
}

@freezed
sealed class PocketbaseInspectorStats with _$PocketbaseInspectorStats {
  const factory PocketbaseInspectorStats({
    @Default(0) int users,
    @Default(0) int chats,
    @Default(0) int agentProfiles,
    @Default(0) int harnesses,
    @Default(0) int mcpServers,
    @Default(0) int skills,
    @Default([]) List<PocketbaseChatSummary> recentChats,
  }) = _PocketbaseInspectorStats;

  factory PocketbaseInspectorStats.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] as Map<String, dynamic>? ?? {};
    final recentChatsJson = json['recent_chats'] as List? ?? [];

    return PocketbaseInspectorStats(
      users: counts['users'] as int? ?? 0,
      chats: counts['chats'] as int? ?? 0,
      agentProfiles: counts['agentProfiles'] as int? ?? 0,
      harnesses: counts['harnesses'] as int? ?? 0,
      mcpServers: counts['mcpServers'] as int? ?? 0,
      skills: counts['skills'] as int? ?? 0,
      recentChats: recentChatsJson
          .map((e) => PocketbaseChatSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

@freezed
sealed class PocketbaseChatSummary with _$PocketbaseChatSummary {
  const factory PocketbaseChatSummary({
    required String id,
    required String title,
    required String turn,
    @Default(false) bool archived,
    required String createdAt,
    required String lastActive,
  }) = _PocketbaseChatSummary;

  factory PocketbaseChatSummary.fromJson(Map<String, dynamic> json) =>
      PocketbaseChatSummary(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        turn: json['turn'] as String? ?? '',
        archived: (json['archived'] as num? ?? 0) != 0,
        createdAt: json['createdAt'] as String? ?? '',
        lastActive: json['lastActive'] as String? ?? '',
      );
}
