import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_entry.freezed.dart';
part 'file_entry.g.dart';

/// One immediate child of a listed workspace directory. This is not
/// PocketBase-backed; it is built from the workspace file-list response in
/// server/pocketbase/internal/filesystem/filesystem.go.
@freezed
abstract class FileEntry with _$FileEntry {
  const factory FileEntry({
    required String name,
    @JsonKey(name: 'isDir') required bool isDir,
    required int size,
    @JsonKey(name: 'modTime') required String modTime,
  }) = _FileEntry;

  factory FileEntry.fromJson(Map<String, dynamic> json) =>
      _$FileEntryFromJson(json);
}
