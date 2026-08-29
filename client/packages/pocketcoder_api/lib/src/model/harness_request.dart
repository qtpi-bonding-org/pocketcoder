//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'harness_request.g.dart';

/// HarnessRequest
///
/// Properties:
/// * [harness]
/// * [provider] - PocketBase providers record id
/// * [accountId]
/// * [accountName]
/// * [visibility]
/// * [mode]
/// * [attemptId]
/// * [code]
@BuiltValue()
abstract class HarnessRequest implements Built<HarnessRequest, HarnessRequestBuilder> {
  @BuiltValueField(wireName: r'harness')
  String get harness;

  /// PocketBase providers record id
  @BuiltValueField(wireName: r'provider')
  String get provider;

  @BuiltValueField(wireName: r'accountId')
  String? get accountId;

  @BuiltValueField(wireName: r'accountName')
  String? get accountName;

  @BuiltValueField(wireName: r'visibility')
  String? get visibility;

  @BuiltValueField(wireName: r'mode')
  HarnessRequestModeEnum? get mode;
  // enum modeEnum {  oauth,  none,  };

  @BuiltValueField(wireName: r'attemptId')
  String? get attemptId;

  @BuiltValueField(wireName: r'code')
  String? get code;

  HarnessRequest._();

  factory HarnessRequest([void updates(HarnessRequestBuilder b)]) = _$HarnessRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(HarnessRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<HarnessRequest> get serializer => _$HarnessRequestSerializer();
}

class _$HarnessRequestSerializer implements PrimitiveSerializer<HarnessRequest> {
  @override
  final Iterable<Type> types = const [HarnessRequest, _$HarnessRequest];

  @override
  final String wireName = r'HarnessRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    HarnessRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'harness';
    yield serializers.serialize(
      object.harness,
      specifiedType: const FullType(String),
    );
    yield r'provider';
    yield serializers.serialize(
      object.provider,
      specifiedType: const FullType(String),
    );
    if (object.accountId != null) {
      yield r'accountId';
      yield serializers.serialize(
        object.accountId,
        specifiedType: const FullType(String),
      );
    }
    if (object.accountName != null) {
      yield r'accountName';
      yield serializers.serialize(
        object.accountName,
        specifiedType: const FullType(String),
      );
    }
    if (object.visibility != null) {
      yield r'visibility';
      yield serializers.serialize(
        object.visibility,
        specifiedType: const FullType(String),
      );
    }
    if (object.mode != null) {
      yield r'mode';
      yield serializers.serialize(
        object.mode,
        specifiedType: const FullType(HarnessRequestModeEnum),
      );
    }
    if (object.attemptId != null) {
      yield r'attemptId';
      yield serializers.serialize(
        object.attemptId,
        specifiedType: const FullType(String),
      );
    }
    if (object.code != null) {
      yield r'code';
      yield serializers.serialize(
        object.code,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    HarnessRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required HarnessRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'harness':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.harness = valueDes;
          break;
        case r'provider':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.provider = valueDes;
          break;
        case r'accountId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.accountId = valueDes;
          break;
        case r'accountName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.accountName = valueDes;
          break;
        case r'visibility':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.visibility = valueDes;
          break;
        case r'mode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(HarnessRequestModeEnum),
          ) as HarnessRequestModeEnum?;
          if (valueDes == null) continue;
          result.mode = valueDes;
          break;
        case r'attemptId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.attemptId = valueDes;
          break;
        case r'code':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.code = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  HarnessRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = HarnessRequestBuilder();
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

class HarnessRequestModeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'oauth')
  static const HarnessRequestModeEnum oauth = _$harnessRequestModeEnum_oauth;
  @BuiltValueEnumConst(wireName: r'none')
  static const HarnessRequestModeEnum none = _$harnessRequestModeEnum_none;
  @BuiltValueEnumConst(wireName: r'unknown_default_open_api', fallback: true)
  static const HarnessRequestModeEnum unknownDefaultOpenApi = _$harnessRequestModeEnum_unknownDefaultOpenApi;

  static Serializer<HarnessRequestModeEnum> get serializer => _$harnessRequestModeEnumSerializer;

  const HarnessRequestModeEnum._(String name): super(name);

  static BuiltSet<HarnessRequestModeEnum> get values => _$harnessRequestModeEnumValues;
  static HarnessRequestModeEnum valueOf(String name) => _$harnessRequestModeEnumValueOf(name);
}
