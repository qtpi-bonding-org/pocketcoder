//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:pocketcoder_api/src/model/release_status_response_current.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'release_status_response.g.dart';

/// ReleaseStatusResponse
///
/// Properties:
/// * [schemaVersion]
/// * [current]
/// * [metadataStatus]
@BuiltValue()
abstract class ReleaseStatusResponse implements Built<ReleaseStatusResponse, ReleaseStatusResponseBuilder> {
  @BuiltValueField(wireName: r'schemaVersion')
  int get schemaVersion;

  @BuiltValueField(wireName: r'current')
  ReleaseStatusResponseCurrent get current;

  @BuiltValueField(wireName: r'metadataStatus')
  BuiltMap<String, JsonObject?> get metadataStatus;

  ReleaseStatusResponse._();

  factory ReleaseStatusResponse([void updates(ReleaseStatusResponseBuilder b)]) = _$ReleaseStatusResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ReleaseStatusResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ReleaseStatusResponse> get serializer => _$ReleaseStatusResponseSerializer();
}

class _$ReleaseStatusResponseSerializer implements PrimitiveSerializer<ReleaseStatusResponse> {
  @override
  final Iterable<Type> types = const [ReleaseStatusResponse, _$ReleaseStatusResponse];

  @override
  final String wireName = r'ReleaseStatusResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ReleaseStatusResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'schemaVersion';
    yield serializers.serialize(
      object.schemaVersion,
      specifiedType: const FullType(int),
    );
    yield r'current';
    yield serializers.serialize(
      object.current,
      specifiedType: const FullType(ReleaseStatusResponseCurrent),
    );
    yield r'metadataStatus';
    yield serializers.serialize(
      object.metadataStatus,
      specifiedType: const FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ReleaseStatusResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ReleaseStatusResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'schemaVersion':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.schemaVersion = valueDes;
          break;
        case r'current':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ReleaseStatusResponseCurrent),
          ) as ReleaseStatusResponseCurrent;
          result.current.replace(valueDes);
          break;
        case r'metadataStatus':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)]),
          ) as BuiltMap<String, JsonObject?>;
          result.metadataStatus.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ReleaseStatusResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ReleaseStatusResponseBuilder();
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
