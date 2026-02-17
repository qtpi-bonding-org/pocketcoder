class User {
  final String id;
  final String email;
  final String? name;
  final String? avatar;
  final String? defaultModel;
  final DateTime created;
  final DateTime updated;

  User({
    required this.id,
    required this.email,
    this.name,
    this.avatar,
    this.defaultModel,
    required this.created,
    required this.updated,
  });

  factory User.fromPocketBase(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
      defaultModel: json['defaultModel'] as String?,
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar': avatar,
      'defaultModel': defaultModel,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }
}