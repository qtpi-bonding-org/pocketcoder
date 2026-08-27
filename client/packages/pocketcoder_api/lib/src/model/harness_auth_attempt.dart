//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'harness_auth_attempt.g.dart';

/// HarnessAuthAttempt
///
/// Properties:
/// * [id]
/// * [status]
/// * [lastError]
@BuiltValue()
abstract class HarnessAuthAttempt implements Built<HarnessAuthAttempt, HarnessAuthAttemptBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'status')
  String get status;

  @BuiltValueField(wireName: r'lastError')
  String? get lastError;

  HarnessAuthAttempt._();

  factory HarnessAuthAttempt([void updates(HarnessAuthAttemptBuilder b)]) = _$HarnessAuthAttempt;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(HarnessAuthAttemptBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<HarnessAuthAttempt> get serializer => _$HarnessAuthAttemptSerializer();
}

class _$HarnessAuthAttemptSerializer implements PrimitiveSerializer<HarnessAuthAttempt> {
  @override
  final Iterable<Type> types = const [HarnessAuthAttempt, _$HarnessAuthAttempt];

  @override
  final String wireName = r'HarnessAuthAttempt';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    HarnessAuthAttempt object, {
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
    if (object.lastError != null) {
      yield r'lastError';
      yield serializers.serialize(
        object.lastError,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    HarnessAuthAttempt object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required HarnessAuthAttemptBuilder result,
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
        case r'lastError':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.lastError = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  HarnessAuthAttempt deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = HarnessAuthAttemptBuilder();
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
