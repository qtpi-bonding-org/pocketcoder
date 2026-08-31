// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_tree_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FileTreeEntry _$FileTreeEntryFromJson(Map<String, dynamic> json) =>
    _FileTreeEntry(
      name: json['name'] as String,
      isDir: json['isDir'] as bool,
      size: (json['size'] as num?)?.toInt(),
      modTime: json['modTime'] as String?,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => FileTreeEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$FileTreeEntryToJson(_FileTreeEntry instance) =>
    <String, dynamic>{
      'name': instance.name,
      'isDir': instance.isDir,
      'size': instance.size,
      'modTime': instance.modTime,
      'children': instance.children,
    };
