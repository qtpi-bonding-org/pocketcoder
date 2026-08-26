//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:pocketcoder_api/src/date_serializer.dart';
import 'package:pocketcoder_api/src/model/date.dart';

import 'package:pocketcoder_api/src/model/accepted_response.dart';
import 'package:pocketcoder_api/src/model/config_option_request.dart';
import 'package:pocketcoder_api/src/model/container_list_response.dart';
import 'package:pocketcoder_api/src/model/container_summary.dart';
import 'package:pocketcoder_api/src/model/content_block.dart';
import 'package:pocketcoder_api/src/model/error_response.dart';
import 'package:pocketcoder_api/src/model/file_entry.dart';
import 'package:pocketcoder_api/src/model/file_list_response.dart';
import 'package:pocketcoder_api/src/model/mode_request.dart';
import 'package:pocketcoder_api/src/model/model_request.dart';
import 'package:pocketcoder_api/src/model/prompt_request.dart';
import 'package:pocketcoder_api/src/model/schedule_run_accepted_response.dart';

part 'serializers.g.dart';

@SerializersFor([
  AcceptedResponse,
  ConfigOptionRequest,
  ContainerListResponse,
  ContainerSummary,
  ContentBlock,
  ErrorResponse,
  FileEntry,
  FileListResponse,
  ModeRequest,
  ModelRequest,
  PromptRequest,
  ScheduleRunAcceptedResponse,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(FileEntry)]),
        () => ListBuilder<FileEntry>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(ContainerSummary)]),
        () => ListBuilder<ContainerSummary>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)]),
        () => MapBuilder<String, JsonObject?>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(ContentBlock)]),
        () => ListBuilder<ContentBlock>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltMap, [FullType(String), FullType(JsonObject)]),
        () => MapBuilder<String, JsonObject>(),
      )
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer())
    ).build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
