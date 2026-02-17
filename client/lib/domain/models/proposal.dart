class Proposal {
  final String id;
  final String title;
  final String description;
  final String? parentId;
  final String status;
  final String authorId;
  final DateTime created;
  final DateTime updated;

  Proposal({
    required this.id,
    required this.title,
    required this.description,
    this.parentId,
    required this.status,
    required this.authorId,
    required this.created,
    required this.updated,
  });

  factory Proposal.fromPocketBase(Map<String, dynamic> json) {
    return Proposal(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      parentId: json['parent_id'] as String?,
      status: json['status'] as String,
      authorId: json['author_id'] as String,
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'parent_id': parentId,
      'status': status,
      'author_id': authorId,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }
}