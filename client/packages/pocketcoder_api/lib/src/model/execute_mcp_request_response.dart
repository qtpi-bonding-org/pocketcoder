//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'execute_mcp_request_response.g.dart';

/// ExecuteMcpRequestResponse
///
/// Properties:
/// * [id]
/// * [status]
/// * [synced]
@BuiltValue()
abstract class ExecuteMcpRequestResponse implements Built<ExecuteMcpRequestResponse, ExecuteMcpRequestResponseBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'status')
  String get status;

  @BuiltValueField(wireName: r'synced')
  bool? get synced;

  ExecuteMcpRequestResponse._();

  factory ExecuteMcpRequestResponse([void updates(ExecuteMcpRequestResponseBuilder b)]) = _$ExecuteMcpRequestResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ExecuteMcpRequestResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ExecuteMcpRequestResponse> get serializer => _$ExecuteMcpRequestResponseSerializer();
}

class _$ExecuteMcpRequestResponseSerializer implements PrimitiveSerializer<ExecuteMcpRequestResponse> {
  @override
  final Iterable<Type> types = const [ExecuteMcpRequestResponse, _$ExecuteMcpRequestResponse];

  @override
  final String wireName = r'ExecuteMcpRequestResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ExecuteMcpRequestResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(String),
    );
    if (object.synced != null) {
      yield r'synced';
      yield serializers.serialize(
        object.synced,
        specifiedType: const FullType(bool),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ExecuteMcpRequestResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ExecuteMcpRequestResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.status = valueDes;
          break;
        case r'synced':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(bool),
          ) as bool?;
          if (valueDes == null) continue;
          result.synced = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ExecuteMcpRequestResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ExecuteMcpRequestResponseBuilder();
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
