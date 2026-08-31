//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'ollama_models_response.g.dart';

/// OllamaModelsResponse
///
/// Properties:
/// * [models]
/// * [enabled]
@BuiltValue()
abstract class OllamaModelsResponse implements Built<OllamaModelsResponse, OllamaModelsResponseBuilder> {
  @BuiltValueField(wireName: r'models')
  BuiltList<BuiltMap<String, JsonObject?>> get models;

  @BuiltValueField(wireName: r'enabled')
  bool get enabled;

  OllamaModelsResponse._();

  factory OllamaModelsResponse([void updates(OllamaModelsResponseBuilder b)]) = _$OllamaModelsResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OllamaModelsResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<OllamaModelsResponse> get serializer => _$OllamaModelsResponseSerializer();
}

class _$OllamaModelsResponseSerializer implements PrimitiveSerializer<OllamaModelsResponse> {
  @override
  final Iterable<Type> types = const [OllamaModelsResponse, _$OllamaModelsResponse];

  @override
  final String wireName = r'OllamaModelsResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OllamaModelsResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'models';
    yield serializers.serialize(
      object.models,
      specifiedType: const FullType(BuiltList, [FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)])]),
    );
    yield r'enabled';
    yield serializers.serialize(
      object.enabled,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    OllamaModelsResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required OllamaModelsResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'models':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)])]),
          ) as BuiltList<BuiltMap<String, JsonObject?>>;
          result.models.replace(valueDes);
          break;
        case r'enabled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.enabled = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  OllamaModelsResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OllamaModelsResponseBuilder();
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
