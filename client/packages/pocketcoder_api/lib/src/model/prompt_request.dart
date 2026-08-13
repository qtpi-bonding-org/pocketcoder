//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:pocketcoder_api/src/model/content_block.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'prompt_request.g.dart';

/// PromptRequest
///
/// Properties:
/// * [prompt]
@BuiltValue()
abstract class PromptRequest implements Built<PromptRequest, PromptRequestBuilder> {
  @BuiltValueField(wireName: r'prompt')
  BuiltList<ContentBlock> get prompt;

  PromptRequest._();

  factory PromptRequest([void updates(PromptRequestBuilder b)]) = _$PromptRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PromptRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PromptRequest> get serializer => _$PromptRequestSerializer();
}

class _$PromptRequestSerializer implements PrimitiveSerializer<PromptRequest> {
  @override
  final Iterable<Type> types = const [PromptRequest, _$PromptRequest];

  @override
  final String wireName = r'PromptRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PromptRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'prompt';
    yield serializers.serialize(
      object.prompt,
      specifiedType: const FullType(BuiltList, [FullType(ContentBlock)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PromptRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PromptRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'prompt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ContentBlock)]),
          ) as BuiltList<ContentBlock>;
          result.prompt.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PromptRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PromptRequestBuilder();
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
