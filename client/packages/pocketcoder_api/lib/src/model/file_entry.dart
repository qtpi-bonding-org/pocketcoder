//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'file_entry.g.dart';

/// FileEntry
///
/// Properties:
/// * [name]
/// * [isDir]
/// * [size]
/// * [modTime]
@BuiltValue()
abstract class FileEntry implements Built<FileEntry, FileEntryBuilder> {
  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'isDir')
  bool get isDir;

  @BuiltValueField(wireName: r'size')
  int get size;

  @BuiltValueField(wireName: r'modTime')
  String get modTime;

  FileEntry._();

  factory FileEntry([void updates(FileEntryBuilder b)]) = _$FileEntry;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FileEntryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FileEntry> get serializer => _$FileEntrySerializer();
}

class _$FileEntrySerializer implements PrimitiveSerializer<FileEntry> {
  @override
  final Iterable<Type> types = const [FileEntry, _$FileEntry];

  @override
  final String wireName = r'FileEntry';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FileEntry object, {
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
    yield r'size';
    yield serializers.serialize(
      object.size,
      specifiedType: const FullType(int),
    );
    yield r'modTime';
    yield serializers.serialize(
      object.modTime,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FileEntry object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FileEntryBuilder result,
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
            specifiedType: const FullType(int),
          ) as int;
          result.size = valueDes;
          break;
        case r'modTime':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.modTime = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FileEntry deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FileEntryBuilder();
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
