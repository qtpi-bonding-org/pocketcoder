//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'release_compatibility_response.g.dart';

/// ReleaseCompatibilityResponse
///
/// Properties:
/// * [schemaVersion]
/// * [dataVersion]
/// * [compatibility]
@BuiltValue()
abstract class ReleaseCompatibilityResponse implements Built<ReleaseCompatibilityResponse, ReleaseCompatibilityResponseBuilder> {
  @BuiltValueField(wireName: r'schemaVersion')
  int get schemaVersion;

  @BuiltValueField(wireName: r'dataVersion')
  int get dataVersion;

  @BuiltValueField(wireName: r'compatibility')
  BuiltMap<String, JsonObject?> get compatibility;

  ReleaseCompatibilityResponse._();

  factory ReleaseCompatibilityResponse([void updates(ReleaseCompatibilityResponseBuilder b)]) = _$ReleaseCompatibilityResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ReleaseCompatibilityResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ReleaseCompatibilityResponse> get serializer => _$ReleaseCompatibilityResponseSerializer();
}

class _$ReleaseCompatibilityResponseSerializer implements PrimitiveSerializer<ReleaseCompatibilityResponse> {
  @override
  final Iterable<Type> types = const [ReleaseCompatibilityResponse, _$ReleaseCompatibilityResponse];

  @override
  final String wireName = r'ReleaseCompatibilityResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ReleaseCompatibilityResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'schemaVersion';
    yield serializers.serialize(
      object.schemaVersion,
      specifiedType: const FullType(int),
    );
    yield r'dataVersion';
    yield serializers.serialize(
      object.dataVersion,
      specifiedType: const FullType(int),
    );
    yield r'compatibility';
    yield serializers.serialize(
      object.compatibility,
      specifiedType: const FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ReleaseCompatibilityResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ReleaseCompatibilityResponseBuilder result,
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
        case r'dataVersion':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.dataVersion = valueDes;
          break;
        case r'compatibility':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)]),
          ) as BuiltMap<String, JsonObject?>;
          result.compatibility.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ReleaseCompatibilityResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ReleaseCompatibilityResponseBuilder();
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
