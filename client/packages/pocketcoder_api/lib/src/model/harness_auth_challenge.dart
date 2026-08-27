//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'harness_auth_challenge.g.dart';

/// HarnessAuthChallenge
///
/// Properties:
/// * [type]
/// * [text]
/// * [target]
/// * [details]
@BuiltValue()
abstract class HarnessAuthChallenge implements Built<HarnessAuthChallenge, HarnessAuthChallengeBuilder> {
  @BuiltValueField(wireName: r'type')
  String get type;

  @BuiltValueField(wireName: r'text')
  String get text;

  @BuiltValueField(wireName: r'target')
  String? get target;

  @BuiltValueField(wireName: r'details')
  String? get details;

  HarnessAuthChallenge._();

  factory HarnessAuthChallenge([void updates(HarnessAuthChallengeBuilder b)]) = _$HarnessAuthChallenge;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(HarnessAuthChallengeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<HarnessAuthChallenge> get serializer => _$HarnessAuthChallengeSerializer();
}

class _$HarnessAuthChallengeSerializer implements PrimitiveSerializer<HarnessAuthChallenge> {
  @override
  final Iterable<Type> types = const [HarnessAuthChallenge, _$HarnessAuthChallenge];

  @override
  final String wireName = r'HarnessAuthChallenge';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    HarnessAuthChallenge object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'type';
    yield serializers.serialize(
      object.type,
      specifiedType: const FullType(String),
    );
    yield r'text';
    yield serializers.serialize(
      object.text,
      specifiedType: const FullType(String),
    );
    if (object.target != null) {
      yield r'target';
      yield serializers.serialize(
        object.target,
        specifiedType: const FullType(String),
      );
    }
    if (object.details != null) {
      yield r'details';
      yield serializers.serialize(
        object.details,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    HarnessAuthChallenge object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required HarnessAuthChallengeBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'type':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.type = valueDes;
          break;
        case r'text':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.text = valueDes;
          break;
        case r'target':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.target = valueDes;
          break;
        case r'details':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.details = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  HarnessAuthChallenge deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = HarnessAuthChallengeBuilder();
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
