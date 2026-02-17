class SOP {
  final String id;
  final String name;
  final String description;
  final String content;
  final String authorId;
  final DateTime created;
  final DateTime updated;

  SOP({
    required this.id,
    required this.name,
    required this.description,
    required this.content,
    required this.authorId,
    required this.created,
    required this.updated,
  });

  factory SOP.fromPocketBase(Map<String, dynamic> json) {
    return SOP(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      content: json['content'] as String,
      authorId: json['author_id'] as String,
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'content': content,
      'author_id': authorId,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }
}