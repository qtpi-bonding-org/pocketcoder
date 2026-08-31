//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:pocketcoder_api/src/model/container_summary.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'container_list_response.g.dart';

/// ContainerListResponse
///
/// Properties:
/// * [containers]
@BuiltValue()
abstract class ContainerListResponse implements Built<ContainerListResponse, ContainerListResponseBuilder> {
  @BuiltValueField(wireName: r'containers')
  BuiltList<ContainerSummary> get containers;

  ContainerListResponse._();

  factory ContainerListResponse([void updates(ContainerListResponseBuilder b)]) = _$ContainerListResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContainerListResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContainerListResponse> get serializer => _$ContainerListResponseSerializer();
}

class _$ContainerListResponseSerializer implements PrimitiveSerializer<ContainerListResponse> {
  @override
  final Iterable<Type> types = const [ContainerListResponse, _$ContainerListResponse];

  @override
  final String wireName = r'ContainerListResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContainerListResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'containers';
    yield serializers.serialize(
      object.containers,
      specifiedType: const FullType(BuiltList, [FullType(ContainerSummary)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ContainerListResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContainerListResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'containers':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ContainerSummary)]),
          ) as BuiltList<ContainerSummary>;
          result.containers.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ContainerListResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContainerListResponseBuilder();
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
