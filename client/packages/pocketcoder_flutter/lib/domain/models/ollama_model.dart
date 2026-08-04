/// A model tag reported by PocketCoder's private Ollama runtime.
///
/// This is intentionally not a PocketBase collection model: tags are live
/// runtime state, and may disappear when an administrator removes a model.
class OllamaModel {
  const OllamaModel({required this.name, required this.size});

  final String name;
  final int size;

  factory OllamaModel.fromJson(Map<String, dynamic> json) => OllamaModel(
        name: json['name'] as String,
        size: (json['size'] as num?)?.toInt() ?? 0,
      );
}
