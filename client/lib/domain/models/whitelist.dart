class WhitelistTarget {
  final String id;
  final String name;
  final String pattern;
  final bool active;
  final DateTime created;
  final DateTime updated;

  WhitelistTarget({
    required this.id,
    required this.name,
    required this.pattern,
    required this.active,
    required this.created,
    required this.updated,
  });

  factory WhitelistTarget.fromPocketBase(Map<String, dynamic> json) {
    return WhitelistTarget(
      id: json['id'] as String,
      name: json['name'] as String,
      pattern: json['pattern'] as String,
      active: json['active'] as bool? ?? true,
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pattern': pattern,
      'active': active,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }
}

class WhitelistAction {
  final String id;
  final String name;
  final String permission;
  final bool active;
  final DateTime created;
  final DateTime updated;

  WhitelistAction({
    required this.id,
    required this.name,
    required this.permission,
    required this.active,
    required this.created,
    required this.updated,
  });

  factory WhitelistAction.fromPocketBase(Map<String, dynamic> json) {
    return WhitelistAction(
      id: json['id'] as String,
      name: json['name'] as String,
      permission: json['permission'] as String,
      active: json['active'] as bool? ?? true,
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'permission': permission,
      'active': active,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }
}