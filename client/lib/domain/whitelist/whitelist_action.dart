import 'whitelist_target.dart';

class WhitelistAction {
  final String id;
  final String command;
  final String? targetId;
  final WhitelistTarget? target;
  final bool isActive;
  final DateTime created;
  final DateTime updated;

  WhitelistAction({
    required this.id,
    required this.command,
    this.targetId,
    this.target,
    required this.isActive,
    required this.created,
    required this.updated,
  });

  factory WhitelistAction.fromJson(Map<String, dynamic> json) {
    return WhitelistAction(
      id: json['id'] as String,
      command: json['command'] as String,
      targetId: json['target'] as String?,
      target: json['expand'] != null && json['expand']['target'] != null
          ? WhitelistTarget.fromJson(json['expand']['target'])
          : null,
      isActive: json['is_active'] as bool? ?? true,
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'command': command,
      'target': targetId,
      'is_active': isActive,
    };
  }
}
