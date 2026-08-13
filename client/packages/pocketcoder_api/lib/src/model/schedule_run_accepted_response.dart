//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'schedule_run_accepted_response.g.dart';

/// ScheduleRunAcceptedResponse
///
/// Properties:
/// * [status]
@BuiltValue()
abstract class ScheduleRunAcceptedResponse implements Built<ScheduleRunAcceptedResponse, ScheduleRunAcceptedResponseBuilder> {
  @BuiltValueField(wireName: r'status')
  ScheduleRunAcceptedResponseStatusEnum get status;
  // enum statusEnum {  started,  };

  ScheduleRunAcceptedResponse._();

  factory ScheduleRunAcceptedResponse([void updates(ScheduleRunAcceptedResponseBuilder b)]) = _$ScheduleRunAcceptedResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ScheduleRunAcceptedResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ScheduleRunAcceptedResponse> get serializer => _$ScheduleRunAcceptedResponseSerializer();
}

class _$ScheduleRunAcceptedResponseSerializer implements PrimitiveSerializer<ScheduleRunAcceptedResponse> {
  @override
  final Iterable<Type> types = const [ScheduleRunAcceptedResponse, _$ScheduleRunAcceptedResponse];

  @override
  final String wireName = r'ScheduleRunAcceptedResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ScheduleRunAcceptedResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(ScheduleRunAcceptedResponseStatusEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ScheduleRunAcceptedResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ScheduleRunAcceptedResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ScheduleRunAcceptedResponseStatusEnum),
          ) as ScheduleRunAcceptedResponseStatusEnum;
          result.status = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ScheduleRunAcceptedResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ScheduleRunAcceptedResponseBuilder();
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

class ScheduleRunAcceptedResponseStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'started')
  static const ScheduleRunAcceptedResponseStatusEnum started = _$scheduleRunAcceptedResponseStatusEnum_started;
  @BuiltValueEnumConst(wireName: r'unknown_default_open_api', fallback: true)
  static const ScheduleRunAcceptedResponseStatusEnum unknownDefaultOpenApi = _$scheduleRunAcceptedResponseStatusEnum_unknownDefaultOpenApi;

  static Serializer<ScheduleRunAcceptedResponseStatusEnum> get serializer => _$scheduleRunAcceptedResponseStatusEnumSerializer;

  const ScheduleRunAcceptedResponseStatusEnum._(String name): super(name);

  static BuiltSet<ScheduleRunAcceptedResponseStatusEnum> get values => _$scheduleRunAcceptedResponseStatusEnumValues;
  static ScheduleRunAcceptedResponseStatusEnum valueOf(String name) => _$scheduleRunAcceptedResponseStatusEnumValueOf(name);
}
