//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'config_option_request.g.dart';

/// ConfigOptionRequest
///
/// Properties:
/// * [configId] 
/// * [value] 
@BuiltValue()
abstract class ConfigOptionRequest implements Built<ConfigOptionRequest, ConfigOptionRequestBuilder> {
  @BuiltValueField(wireName: r'configId')
  String get configId;

  @BuiltValueField(wireName: r'value')
  String get value;

  ConfigOptionRequest._();

  factory ConfigOptionRequest([void updates(ConfigOptionRequestBuilder b)]) = _$ConfigOptionRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ConfigOptionRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ConfigOptionRequest> get serializer => _$ConfigOptionRequestSerializer();
}

class _$ConfigOptionRequestSerializer implements PrimitiveSerializer<ConfigOptionRequest> {
  @override
  final Iterable<Type> types = const [ConfigOptionRequest, _$ConfigOptionRequest];

  @override
  final String wireName = r'ConfigOptionRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ConfigOptionRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'configId';
    yield serializers.serialize(
      object.configId,
      specifiedType: const FullType(String),
    );
    yield r'value';
    yield serializers.serialize(
      object.value,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ConfigOptionRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ConfigOptionRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'configId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.configId = valueDes;
          break;
        case r'value':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.value = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ConfigOptionRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ConfigOptionRequestBuilder();
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

