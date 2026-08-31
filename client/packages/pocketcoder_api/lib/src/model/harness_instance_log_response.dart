//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'harness_instance_log_response.g.dart';

/// HarnessInstanceLogResponse
///
/// Properties:
/// * [lines]
/// * [truncated]
@BuiltValue()
abstract class HarnessInstanceLogResponse implements Built<HarnessInstanceLogResponse, HarnessInstanceLogResponseBuilder> {
  @BuiltValueField(wireName: r'lines')
  BuiltList<String> get lines;

  @BuiltValueField(wireName: r'truncated')
  bool get truncated;

  HarnessInstanceLogResponse._();

  factory HarnessInstanceLogResponse([void updates(HarnessInstanceLogResponseBuilder b)]) = _$HarnessInstanceLogResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(HarnessInstanceLogResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<HarnessInstanceLogResponse> get serializer => _$HarnessInstanceLogResponseSerializer();
}

class _$HarnessInstanceLogResponseSerializer implements PrimitiveSerializer<HarnessInstanceLogResponse> {
  @override
  final Iterable<Type> types = const [HarnessInstanceLogResponse, _$HarnessInstanceLogResponse];

  @override
  final String wireName = r'HarnessInstanceLogResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    HarnessInstanceLogResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'lines';
    yield serializers.serialize(
      object.lines,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
    yield r'truncated';
    yield serializers.serialize(
      object.truncated,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    HarnessInstanceLogResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required HarnessInstanceLogResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'lines':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.lines.replace(valueDes);
          break;
        case r'truncated':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.truncated = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  HarnessInstanceLogResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = HarnessInstanceLogResponseBuilder();
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
