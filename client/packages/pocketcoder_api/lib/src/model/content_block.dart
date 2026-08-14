//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: duplicate_import, unused_import, unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'content_block.g.dart';

/// ContentBlock
///
/// Properties:
/// * [type]
/// * [text]
@BuiltValue()
abstract class ContentBlock implements Built<ContentBlock, ContentBlockBuilder> {
  @BuiltValueField(wireName: r'type')
  String get type;

  @BuiltValueField(wireName: r'text')
  String? get text;

  ContentBlock._();

  factory ContentBlock([void updates(ContentBlockBuilder b)]) = _$ContentBlock;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContentBlockBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContentBlock> get serializer => _$ContentBlockSerializer();
}

class _$ContentBlockSerializer implements PrimitiveSerializer<ContentBlock> {
  @override
  final Iterable<Type> types = const [ContentBlock, _$ContentBlock];

  @override
  final String wireName = r'ContentBlock';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContentBlock object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'type';
    yield serializers.serialize(
      object.type,
      specifiedType: const FullType(String),
    );
    if (object.text != null) {
      yield r'text';
      yield serializers.serialize(
        object.text,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ContentBlock object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContentBlockBuilder result,
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
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.text = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ContentBlock deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContentBlockBuilder();
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
