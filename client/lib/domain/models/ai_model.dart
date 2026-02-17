class AiModel {
  final String id;
  final String name;
  final String provider;
  final String modelId;
  final bool isAvailable;
  final DateTime created;
  final DateTime updated;

  AiModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.modelId,
    required this.isAvailable,
    required this.created,
    required this.updated,
  });

  factory AiModel.fromPocketBase(Map<String, dynamic> json) {
    return AiModel(
      id: json['id'] as String,
      name: json['name'] as String,
      provider: json['provider'] as String,
      modelId: json['model_id'] as String,
      isAvailable: json['is_available'] as bool? ?? true,
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'model_id': modelId,
      'is_available': isAvailable,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }
}