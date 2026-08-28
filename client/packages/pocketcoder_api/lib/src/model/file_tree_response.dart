//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:pocketcoder_api/src/model/file_tree_entry.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'file_tree_response.g.dart';

/// FileTreeResponse
///
/// Properties:
/// * [path]
/// * [entries]
@BuiltValue()
abstract class FileTreeResponse implements Built<FileTreeResponse, FileTreeResponseBuilder> {
  @BuiltValueField(wireName: r'path')
  String get path;

  @BuiltValueField(wireName: r'entries')
  BuiltList<FileTreeEntry> get entries;

  FileTreeResponse._();

  factory FileTreeResponse([void updates(FileTreeResponseBuilder b)]) = _$FileTreeResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FileTreeResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FileTreeResponse> get serializer => _$FileTreeResponseSerializer();
}

class _$FileTreeResponseSerializer implements PrimitiveSerializer<FileTreeResponse> {
  @override
  final Iterable<Type> types = const [FileTreeResponse, _$FileTreeResponse];

  @override
  final String wireName = r'FileTreeResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FileTreeResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'path';
    yield serializers.serialize(
      object.path,
      specifiedType: const FullType(String),
    );
    yield r'entries';
    yield serializers.serialize(
      object.entries,
      specifiedType: const FullType(BuiltList, [FullType(FileTreeEntry)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FileTreeResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FileTreeResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'path':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.path = valueDes;
          break;
        case r'entries':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(FileTreeEntry)]),
          ) as BuiltList<FileTreeEntry>;
          result.entries.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FileTreeResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FileTreeResponseBuilder();
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
