//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'harness_auth_challenge.g.dart';

/// HarnessAuthChallenge
///
/// Properties:
/// * [type]
/// * [text]
/// * [target]
/// * [details]
/// * [kind]
/// * [verificationUri]
/// * [userCode]
/// * [codeDestination]
/// * [expiresAt]
/// * [pollIntervalSeconds]
@BuiltValue()
abstract class HarnessAuthChallenge implements Built<HarnessAuthChallenge, HarnessAuthChallengeBuilder> {
  @BuiltValueField(wireName: r'type')
  String get type;

  @Deprecated('text has been deprecated')
  @BuiltValueField(wireName: r'text')
  String? get text;

  @Deprecated('target has been deprecated')
  @BuiltValueField(wireName: r'target')
  String? get target;

  @Deprecated('details has been deprecated')
  @BuiltValueField(wireName: r'details')
  String? get details;

  @BuiltValueField(wireName: r'kind')
  HarnessAuthChallengeKindEnum? get kind;
  // enum kindEnum {  device_code,  browser_code,  };

  @BuiltValueField(wireName: r'verificationUri')
  String? get verificationUri;

  @BuiltValueField(wireName: r'userCode')
  String? get userCode;

  @BuiltValueField(wireName: r'codeDestination')
  HarnessAuthChallengeCodeDestinationEnum? get codeDestination;
  // enum codeDestinationEnum {  browser,  app,  none,  };

  @BuiltValueField(wireName: r'expiresAt')
  DateTime? get expiresAt;

  @BuiltValueField(wireName: r'pollIntervalSeconds')
  int? get pollIntervalSeconds;

  HarnessAuthChallenge._();

  factory HarnessAuthChallenge([void updates(HarnessAuthChallengeBuilder b)]) = _$HarnessAuthChallenge;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(HarnessAuthChallengeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<HarnessAuthChallenge> get serializer => _$HarnessAuthChallengeSerializer();
}

class _$HarnessAuthChallengeSerializer implements PrimitiveSerializer<HarnessAuthChallenge> {
  @override
  final Iterable<Type> types = const [HarnessAuthChallenge, _$HarnessAuthChallenge];

  @override
  final String wireName = r'HarnessAuthChallenge';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    HarnessAuthChallenge object, {
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
    if (object.target != null) {
      yield r'target';
      yield serializers.serialize(
        object.target,
        specifiedType: const FullType(String),
      );
    }
    if (object.details != null) {
      yield r'details';
      yield serializers.serialize(
        object.details,
        specifiedType: const FullType(String),
      );
    }
    if (object.kind != null) {
      yield r'kind';
      yield serializers.serialize(
        object.kind,
        specifiedType: const FullType(HarnessAuthChallengeKindEnum),
      );
    }
    if (object.verificationUri != null) {
      yield r'verificationUri';
      yield serializers.serialize(
        object.verificationUri,
        specifiedType: const FullType(String),
      );
    }
    if (object.userCode != null) {
      yield r'userCode';
      yield serializers.serialize(
        object.userCode,
        specifiedType: const FullType(String),
      );
    }
    if (object.codeDestination != null) {
      yield r'codeDestination';
      yield serializers.serialize(
        object.codeDestination,
        specifiedType: const FullType(HarnessAuthChallengeCodeDestinationEnum),
      );
    }
    if (object.expiresAt != null) {
      yield r'expiresAt';
      yield serializers.serialize(
        object.expiresAt,
        specifiedType: const FullType(DateTime),
      );
    }
    if (object.pollIntervalSeconds != null) {
      yield r'pollIntervalSeconds';
      yield serializers.serialize(
        object.pollIntervalSeconds,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    HarnessAuthChallenge object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required HarnessAuthChallengeBuilder result,
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
        case r'target':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.target = valueDes;
          break;
        case r'details':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.details = valueDes;
          break;
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(HarnessAuthChallengeKindEnum),
          ) as HarnessAuthChallengeKindEnum?;
          if (valueDes == null) continue;
          result.kind = valueDes;
          break;
        case r'verificationUri':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.verificationUri = valueDes;
          break;
        case r'userCode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.userCode = valueDes;
          break;
        case r'codeDestination':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(HarnessAuthChallengeCodeDestinationEnum),
          ) as HarnessAuthChallengeCodeDestinationEnum?;
          if (valueDes == null) continue;
          result.codeDestination = valueDes;
          break;
        case r'expiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.expiresAt = valueDes;
          break;
        case r'pollIntervalSeconds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.pollIntervalSeconds = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  HarnessAuthChallenge deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = HarnessAuthChallengeBuilder();
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

class HarnessAuthChallengeKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'device_code')
  static const HarnessAuthChallengeKindEnum deviceCode = _$harnessAuthChallengeKindEnum_deviceCode;
  @BuiltValueEnumConst(wireName: r'browser_code')
  static const HarnessAuthChallengeKindEnum browserCode = _$harnessAuthChallengeKindEnum_browserCode;
  @BuiltValueEnumConst(wireName: r'unknown_default_open_api', fallback: true)
  static const HarnessAuthChallengeKindEnum unknownDefaultOpenApi = _$harnessAuthChallengeKindEnum_unknownDefaultOpenApi;

  static Serializer<HarnessAuthChallengeKindEnum> get serializer => _$harnessAuthChallengeKindEnumSerializer;

  const HarnessAuthChallengeKindEnum._(String name): super(name);

  static BuiltSet<HarnessAuthChallengeKindEnum> get values => _$harnessAuthChallengeKindEnumValues;
  static HarnessAuthChallengeKindEnum valueOf(String name) => _$harnessAuthChallengeKindEnumValueOf(name);
}

class HarnessAuthChallengeCodeDestinationEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'browser')
  static const HarnessAuthChallengeCodeDestinationEnum browser = _$harnessAuthChallengeCodeDestinationEnum_browser;
  @BuiltValueEnumConst(wireName: r'app')
  static const HarnessAuthChallengeCodeDestinationEnum app = _$harnessAuthChallengeCodeDestinationEnum_app;
  @BuiltValueEnumConst(wireName: r'none')
  static const HarnessAuthChallengeCodeDestinationEnum none = _$harnessAuthChallengeCodeDestinationEnum_none;
  @BuiltValueEnumConst(wireName: r'unknown_default_open_api', fallback: true)
  static const HarnessAuthChallengeCodeDestinationEnum unknownDefaultOpenApi = _$harnessAuthChallengeCodeDestinationEnum_unknownDefaultOpenApi;

  static Serializer<HarnessAuthChallengeCodeDestinationEnum> get serializer => _$harnessAuthChallengeCodeDestinationEnumSerializer;

  const HarnessAuthChallengeCodeDestinationEnum._(String name): super(name);

  static BuiltSet<HarnessAuthChallengeCodeDestinationEnum> get values => _$harnessAuthChallengeCodeDestinationEnumValues;
  static HarnessAuthChallengeCodeDestinationEnum valueOf(String name) => _$harnessAuthChallengeCodeDestinationEnumValueOf(name);
}
