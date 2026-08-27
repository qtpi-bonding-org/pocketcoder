//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:pocketcoder_api/src/model/harness_auth_challenge.dart';
import 'package:pocketcoder_api/src/model/harness_auth_attempt.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'harness_auth_status.g.dart';

/// HarnessAuthStatus
///
/// Properties:
/// * [harness]
/// * [provider]
/// * [accountId]
/// * [accountName]
/// * [visibility]
/// * [mode]
/// * [status]
/// * [lastError]
/// * [attempt]
/// * [challenge]
@BuiltValue()
abstract class HarnessAuthStatus implements Built<HarnessAuthStatus, HarnessAuthStatusBuilder> {
  @BuiltValueField(wireName: r'harness')
  String get harness;

  @BuiltValueField(wireName: r'provider')
  String get provider;

  @BuiltValueField(wireName: r'accountId')
  String? get accountId;

  @BuiltValueField(wireName: r'accountName')
  String? get accountName;

  @BuiltValueField(wireName: r'visibility')
  String? get visibility;

  @BuiltValueField(wireName: r'mode')
  HarnessAuthStatusModeEnum get mode;
  // enum modeEnum {  oauth,  none,  };

  @BuiltValueField(wireName: r'status')
  String get status;

  @BuiltValueField(wireName: r'lastError')
  String? get lastError;

  @BuiltValueField(wireName: r'attempt')
  HarnessAuthAttempt? get attempt;

  @BuiltValueField(wireName: r'challenge')
  HarnessAuthChallenge? get challenge;

  HarnessAuthStatus._();

  factory HarnessAuthStatus([void updates(HarnessAuthStatusBuilder b)]) = _$HarnessAuthStatus;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(HarnessAuthStatusBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<HarnessAuthStatus> get serializer => _$HarnessAuthStatusSerializer();
}

class _$HarnessAuthStatusSerializer implements PrimitiveSerializer<HarnessAuthStatus> {
  @override
  final Iterable<Type> types = const [HarnessAuthStatus, _$HarnessAuthStatus];

  @override
  final String wireName = r'HarnessAuthStatus';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    HarnessAuthStatus object, {
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
    yield r'mode';
    yield serializers.serialize(
      object.mode,
      specifiedType: const FullType(HarnessAuthStatusModeEnum),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(String),
    );
    if (object.lastError != null) {
      yield r'lastError';
      yield serializers.serialize(
        object.lastError,
        specifiedType: const FullType(String),
      );
    }
    if (object.attempt != null) {
      yield r'attempt';
      yield serializers.serialize(
        object.attempt,
        specifiedType: const FullType(HarnessAuthAttempt),
      );
    }
    if (object.challenge != null) {
      yield r'challenge';
      yield serializers.serialize(
        object.challenge,
        specifiedType: const FullType(HarnessAuthChallenge),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    HarnessAuthStatus object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required HarnessAuthStatusBuilder result,
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
            specifiedType: const FullType(HarnessAuthStatusModeEnum),
          ) as HarnessAuthStatusModeEnum;
          result.mode = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.status = valueDes;
          break;
        case r'lastError':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.lastError = valueDes;
          break;
        case r'attempt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(HarnessAuthAttempt),
          ) as HarnessAuthAttempt?;
          if (valueDes == null) continue;
          result.attempt.replace(valueDes);
          break;
        case r'challenge':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(HarnessAuthChallenge),
          ) as HarnessAuthChallenge?;
          if (valueDes == null) continue;
          result.challenge.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  HarnessAuthStatus deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = HarnessAuthStatusBuilder();
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

class HarnessAuthStatusModeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'oauth')
  static const HarnessAuthStatusModeEnum oauth = _$harnessAuthStatusModeEnum_oauth;
  @BuiltValueEnumConst(wireName: r'none')
  static const HarnessAuthStatusModeEnum none = _$harnessAuthStatusModeEnum_none;
  @BuiltValueEnumConst(wireName: r'unknown_default_open_api', fallback: true)
  static const HarnessAuthStatusModeEnum unknownDefaultOpenApi = _$harnessAuthStatusModeEnum_unknownDefaultOpenApi;

  static Serializer<HarnessAuthStatusModeEnum> get serializer => _$harnessAuthStatusModeEnumSerializer;

  const HarnessAuthStatusModeEnum._(String name): super(name);

  static BuiltSet<HarnessAuthStatusModeEnum> get values => _$harnessAuthStatusModeEnumValues;
  static HarnessAuthStatusModeEnum valueOf(String name) => _$harnessAuthStatusModeEnumValueOf(name);
}
