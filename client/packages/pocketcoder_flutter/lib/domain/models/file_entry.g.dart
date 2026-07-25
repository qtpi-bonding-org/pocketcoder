// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FileEntry _$FileEntryFromJson(Map<String, dynamic> json) => _FileEntry(
      name: json['name'] as String,
      isDir: json['is_dir'] as bool,
      size: (json['size'] as num).toInt(),
      modTime: json['mod_time'] as String,
    );

Map<String, dynamic> _$FileEntryToJson(_FileEntry instance) =>
    <String, dynamic>{
      'name': instance.name,
      'is_dir': instance.isDir,
      'size': instance.size,
      'mod_time': instance.modTime,
    };
