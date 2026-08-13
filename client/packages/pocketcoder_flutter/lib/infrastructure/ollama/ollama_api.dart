import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/ollama_model.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';

/// PocketBase proxy for the private Ollama control network. The app never
/// receives Ollama's hostname or a host-published port.
@lazySingleton
class OllamaApi {
  OllamaApi(this._pb, this._http, this._api);

  final PocketBase _pb;
  final http.Client _http;
  final PocketCoderApiClient _api;

  Future<List<OllamaModel>> listModels() async {
    final response = await _api.ollama.listOllamaModels();
    final json = PocketCoderApiClient.decodeJson(response.data);
    final models = (json['models'] as List<dynamic>? ?? const []);
    return models
        .map((item) => OllamaModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Streams native pull progress from PocketBase's authenticated proxy.
  Stream<String> pull(String model) async* {
    final request = http.Request(
      'POST',
      Uri.parse('${_pb.baseURL}${StreamingEndpoints.ollamaPull}'),
    )
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/x-ndjson'
      ..body = jsonEncode({'model': model});
    final token = _pb.authStore.token;
    if (token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';

    final response = await _http.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw StateError(body.isEmpty ? 'Unable to download $model' : body);
    }
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.isEmpty) continue;
      final json = jsonDecode(line) as Map<String, dynamic>;
      final error = json['error'] as String?;
      if (error != null && error.isNotEmpty) throw StateError(error);
      final status = json['status'] as String?;
      if (status != null && status.isNotEmpty) yield status;
    }
  }
}
