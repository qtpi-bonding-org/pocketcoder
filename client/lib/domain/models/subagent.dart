class Subagent {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final List<String> tools;
  final String authorId;
  final DateTime created;
  final DateTime updated;

  Subagent({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.tools,
    required this.authorId,
    required this.created,
    required this.updated,
  });

  factory Subagent.fromPocketBase(Map<String, dynamic> json) {
    return Subagent(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      systemPrompt: json['system_prompt'] as String,
      tools: List<String>.from(json['tools'] as List),
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
      'system_prompt': systemPrompt,
      'tools': tools,
      'author_id': authorId,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }
}