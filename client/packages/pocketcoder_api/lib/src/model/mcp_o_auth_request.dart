//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'mcp_o_auth_request.g.dart';

/// McpOAuthRequest
///
/// Properties:
/// * [serverName]
/// * [accessToken]
/// * [refreshToken]
@BuiltValue()
abstract class McpOAuthRequest implements Built<McpOAuthRequest, McpOAuthRequestBuilder> {
  @BuiltValueField(wireName: r'server_name')
  String get serverName;

  @BuiltValueField(wireName: r'access_token')
  String get accessToken;

  @BuiltValueField(wireName: r'refresh_token')
  String? get refreshToken;

  McpOAuthRequest._();

  factory McpOAuthRequest([void updates(McpOAuthRequestBuilder b)]) = _$McpOAuthRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(McpOAuthRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<McpOAuthRequest> get serializer => _$McpOAuthRequestSerializer();
}

class _$McpOAuthRequestSerializer implements PrimitiveSerializer<McpOAuthRequest> {
  @override
  final Iterable<Type> types = const [McpOAuthRequest, _$McpOAuthRequest];

  @override
  final String wireName = r'McpOAuthRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    McpOAuthRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'server_name';
    yield serializers.serialize(
      object.serverName,
      specifiedType: const FullType(String),
    );
    yield r'access_token';
    yield serializers.serialize(
      object.accessToken,
      specifiedType: const FullType(String),
    );
    if (object.refreshToken != null) {
      yield r'refresh_token';
      yield serializers.serialize(
        object.refreshToken,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    McpOAuthRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required McpOAuthRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'server_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.serverName = valueDes;
          break;
        case r'access_token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.accessToken = valueDes;
          break;
        case r'refresh_token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.refreshToken = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  McpOAuthRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = McpOAuthRequestBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}
