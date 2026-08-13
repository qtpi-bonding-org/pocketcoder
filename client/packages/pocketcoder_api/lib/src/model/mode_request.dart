//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'mode_request.g.dart';

/// ModeRequest
///
/// Properties:
/// * [modeId]
@BuiltValue()
abstract class ModeRequest implements Built<ModeRequest, ModeRequestBuilder> {
  @BuiltValueField(wireName: r'modeId')
  String get modeId;

  ModeRequest._();

  factory ModeRequest([void updates(ModeRequestBuilder b)]) = _$ModeRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ModeRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ModeRequest> get serializer => _$ModeRequestSerializer();
}

class _$ModeRequestSerializer implements PrimitiveSerializer<ModeRequest> {
  @override
  final Iterable<Type> types = const [ModeRequest, _$ModeRequest];

  @override
  final String wireName = r'ModeRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ModeRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'modeId';
    yield serializers.serialize(
      object.modeId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ModeRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ModeRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'modeId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.modeId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ModeRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ModeRequestBuilder();
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
