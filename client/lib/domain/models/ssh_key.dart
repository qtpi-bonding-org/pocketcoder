class SSHKey {
  final String id;
  final String name;
  final String publicKey;
  final bool isActive;
  final DateTime created;
  final DateTime updated;

  SSHKey({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.isActive,
    required this.created,
    required this.updated,
  });

  factory SSHKey.fromPocketBase(Map<String, dynamic> json) {
    return SSHKey(
      id: json['id'] as String,
      name: json['name'] as String,
      publicKey: json['public_key'] as String,
      isActive: json['is_active'] as bool? ?? true,
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'public_key': publicKey,
      'is_active': isActive,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }
}