class WhitelistTarget {
  final String id;
  final String name;
  final String pattern;
  final String type; // domain, repo, path
  final DateTime created;
  final DateTime updated;

  WhitelistTarget({
    required this.id,
    required this.name,
    required this.pattern,
    required this.type,
    required this.created,
    required this.updated,
  });

  factory WhitelistTarget.fromJson(Map<String, dynamic> json) {
    return WhitelistTarget(
      id: json['id'] as String,
      name: json['name'] as String,
      pattern: json['pattern'] as String,
      type: json['type'] as String,
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'pattern': pattern,
      'type': type,
    };
  }
}
