//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'store_mcp_o_auth_token_response.g.dart';

/// StoreMcpOAuthTokenResponse
///
/// Properties:
/// * [stored]
@BuiltValue()
abstract class StoreMcpOAuthTokenResponse implements Built<StoreMcpOAuthTokenResponse, StoreMcpOAuthTokenResponseBuilder> {
  @BuiltValueField(wireName: r'stored')
  bool get stored;

  StoreMcpOAuthTokenResponse._();

  factory StoreMcpOAuthTokenResponse([void updates(StoreMcpOAuthTokenResponseBuilder b)]) = _$StoreMcpOAuthTokenResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(StoreMcpOAuthTokenResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<StoreMcpOAuthTokenResponse> get serializer => _$StoreMcpOAuthTokenResponseSerializer();
}

class _$StoreMcpOAuthTokenResponseSerializer implements PrimitiveSerializer<StoreMcpOAuthTokenResponse> {
  @override
  final Iterable<Type> types = const [StoreMcpOAuthTokenResponse, _$StoreMcpOAuthTokenResponse];

  @override
  final String wireName = r'StoreMcpOAuthTokenResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    StoreMcpOAuthTokenResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'stored';
    yield serializers.serialize(
      object.stored,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    StoreMcpOAuthTokenResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required StoreMcpOAuthTokenResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'stored':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.stored = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  StoreMcpOAuthTokenResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = StoreMcpOAuthTokenResponseBuilder();
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
