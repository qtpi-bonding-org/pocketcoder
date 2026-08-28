//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'file_tree_entry.g.dart';

/// FileTreeEntry
///
/// Properties:
/// * [name]
/// * [isDir]
/// * [size]
/// * [modTime]
/// * [children]
@BuiltValue()
abstract class FileTreeEntry implements Built<FileTreeEntry, FileTreeEntryBuilder> {
  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'isDir')
  bool get isDir;

  @BuiltValueField(wireName: r'size')
  int? get size;

  @BuiltValueField(wireName: r'modTime')
  String? get modTime;

  @BuiltValueField(wireName: r'children')
  BuiltList<FileTreeEntry>? get children;

  FileTreeEntry._();

  factory FileTreeEntry([void updates(FileTreeEntryBuilder b)]) = _$FileTreeEntry;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FileTreeEntryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FileTreeEntry> get serializer => _$FileTreeEntrySerializer();
}

class _$FileTreeEntrySerializer implements PrimitiveSerializer<FileTreeEntry> {
  @override
  final Iterable<Type> types = const [FileTreeEntry, _$FileTreeEntry];

  @override
  final String wireName = r'FileTreeEntry';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FileTreeEntry object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'isDir';
    yield serializers.serialize(
      object.isDir,
      specifiedType: const FullType(bool),
    );
    if (object.size != null) {
      yield r'size';
      yield serializers.serialize(
        object.size,
        specifiedType: const FullType(int),
      );
    }
    if (object.modTime != null) {
      yield r'modTime';
      yield serializers.serialize(
        object.modTime,
        specifiedType: const FullType(String),
      );
    }
    if (object.children != null) {
      yield r'children';
      yield serializers.serialize(
        object.children,
        specifiedType: const FullType(BuiltList, [FullType(FileTreeEntry)]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    FileTreeEntry object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FileTreeEntryBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'isDir':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.isDir = valueDes;
          break;
        case r'size':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.size = valueDes;
          break;
        case r'modTime':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.modTime = valueDes;
          break;
        case r'children':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(FileTreeEntry)]),
          ) as BuiltList<FileTreeEntry>?;
          if (valueDes == null) continue;
          result.children.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FileTreeEntry deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FileTreeEntryBuilder();
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
