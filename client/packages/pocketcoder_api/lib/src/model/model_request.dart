//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'model_request.g.dart';

/// ModelRequest
///
/// Properties:
/// * [model]
@BuiltValue()
abstract class ModelRequest implements Built<ModelRequest, ModelRequestBuilder> {
  @BuiltValueField(wireName: r'model')
  String get model;

  ModelRequest._();

  factory ModelRequest([void updates(ModelRequestBuilder b)]) = _$ModelRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ModelRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ModelRequest> get serializer => _$ModelRequestSerializer();
}

class _$ModelRequestSerializer implements PrimitiveSerializer<ModelRequest> {
  @override
  final Iterable<Type> types = const [ModelRequest, _$ModelRequest];

  @override
  final String wireName = r'ModelRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ModelRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'model';
    yield serializers.serialize(
      object.model,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ModelRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ModelRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'model':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.model = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ModelRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ModelRequestBuilder();
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
