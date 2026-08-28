//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'set_live_activity_token_request.g.dart';

/// SetLiveActivityTokenRequest
///
/// Properties:
/// * [activityPushToken]
@BuiltValue()
abstract class SetLiveActivityTokenRequest implements Built<SetLiveActivityTokenRequest, SetLiveActivityTokenRequestBuilder> {
  @BuiltValueField(wireName: r'activity_push_token')
  String get activityPushToken;

  SetLiveActivityTokenRequest._();

  factory SetLiveActivityTokenRequest([void updates(SetLiveActivityTokenRequestBuilder b)]) = _$SetLiveActivityTokenRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SetLiveActivityTokenRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SetLiveActivityTokenRequest> get serializer => _$SetLiveActivityTokenRequestSerializer();
}

class _$SetLiveActivityTokenRequestSerializer implements PrimitiveSerializer<SetLiveActivityTokenRequest> {
  @override
  final Iterable<Type> types = const [SetLiveActivityTokenRequest, _$SetLiveActivityTokenRequest];

  @override
  final String wireName = r'SetLiveActivityTokenRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SetLiveActivityTokenRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'activity_push_token';
    yield serializers.serialize(
      object.activityPushToken,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SetLiveActivityTokenRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SetLiveActivityTokenRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'activity_push_token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.activityPushToken = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SetLiveActivityTokenRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SetLiveActivityTokenRequestBuilder();
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
