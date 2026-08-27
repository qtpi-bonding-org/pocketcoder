//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'release_status_response_current.g.dart';

/// ReleaseStatusResponseCurrent
///
/// Properties:
/// * [releaseDigest]
/// * [sourceCommit]
/// * [serverVersion]
/// * [dataVersion]
/// * [deploymentContractVersion]
/// * [compatibility]
@BuiltValue()
abstract class ReleaseStatusResponseCurrent implements Built<ReleaseStatusResponseCurrent, ReleaseStatusResponseCurrentBuilder> {
  @BuiltValueField(wireName: r'releaseDigest')
  String? get releaseDigest;

  @BuiltValueField(wireName: r'sourceCommit')
  String? get sourceCommit;

  @BuiltValueField(wireName: r'serverVersion')
  String? get serverVersion;

  @BuiltValueField(wireName: r'dataVersion')
  int? get dataVersion;

  @BuiltValueField(wireName: r'deploymentContractVersion')
  int? get deploymentContractVersion;

  @BuiltValueField(wireName: r'compatibility')
  BuiltMap<String, JsonObject?>? get compatibility;

  ReleaseStatusResponseCurrent._();

  factory ReleaseStatusResponseCurrent([void updates(ReleaseStatusResponseCurrentBuilder b)]) = _$ReleaseStatusResponseCurrent;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ReleaseStatusResponseCurrentBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ReleaseStatusResponseCurrent> get serializer => _$ReleaseStatusResponseCurrentSerializer();
}

class _$ReleaseStatusResponseCurrentSerializer implements PrimitiveSerializer<ReleaseStatusResponseCurrent> {
  @override
  final Iterable<Type> types = const [ReleaseStatusResponseCurrent, _$ReleaseStatusResponseCurrent];

  @override
  final String wireName = r'ReleaseStatusResponseCurrent';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ReleaseStatusResponseCurrent object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.releaseDigest != null) {
      yield r'releaseDigest';
      yield serializers.serialize(
        object.releaseDigest,
        specifiedType: const FullType(String),
      );
    }
    if (object.sourceCommit != null) {
      yield r'sourceCommit';
      yield serializers.serialize(
        object.sourceCommit,
        specifiedType: const FullType(String),
      );
    }
    if (object.serverVersion != null) {
      yield r'serverVersion';
      yield serializers.serialize(
        object.serverVersion,
        specifiedType: const FullType(String),
      );
    }
    if (object.dataVersion != null) {
      yield r'dataVersion';
      yield serializers.serialize(
        object.dataVersion,
        specifiedType: const FullType(int),
      );
    }
    if (object.deploymentContractVersion != null) {
      yield r'deploymentContractVersion';
      yield serializers.serialize(
        object.deploymentContractVersion,
        specifiedType: const FullType(int),
      );
    }
    if (object.compatibility != null) {
      yield r'compatibility';
      yield serializers.serialize(
        object.compatibility,
        specifiedType: const FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ReleaseStatusResponseCurrent object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ReleaseStatusResponseCurrentBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'releaseDigest':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.releaseDigest = valueDes;
          break;
        case r'sourceCommit':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.sourceCommit = valueDes;
          break;
        case r'serverVersion':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.serverVersion = valueDes;
          break;
        case r'dataVersion':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.dataVersion = valueDes;
          break;
        case r'deploymentContractVersion':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.deploymentContractVersion = valueDes;
          break;
        case r'compatibility':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltMap, [FullType(String), FullType.nullable(JsonObject)]),
          ) as BuiltMap<String, JsonObject?>?;
          if (valueDes == null) continue;
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
  ReleaseStatusResponseCurrent deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ReleaseStatusResponseCurrentBuilder();
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
