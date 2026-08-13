import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef DioTestResponder = ResponseBody Function(
  RequestOptions options,
  List<int> requestBody,
);

class CapturingDioAdapter implements HttpClientAdapter {
  CapturingDioAdapter(this.responder);

  DioTestResponder responder;
  RequestOptions? lastRequest;
  List<int> lastRequestBody = const [];

  Map<String, dynamic> get lastJsonBody {
    if (lastRequestBody.isEmpty) return const {};
    return jsonDecode(utf8.decode(lastRequestBody)) as Map<String, dynamic>;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = requestStream == null
        ? <int>[]
        : await requestStream.expand((chunk) => chunk).toList();
    lastRequest = options;
    lastRequestBody = body;
    return responder(options, body);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  Object? body, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

ResponseBody byteResponse(
  List<int> body, {
  int statusCode = 200,
}) {
  return ResponseBody.fromBytes(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/octet-stream'],
    },
  );
}
