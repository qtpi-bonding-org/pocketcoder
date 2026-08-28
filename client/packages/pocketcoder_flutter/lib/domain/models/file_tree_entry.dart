import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_tree_entry.freezed.dart';
part 'file_tree_entry.g.dart';

/// One node of a full recursive workspace directory tree. This is not
/// PocketBase-backed; it is built from the files-tree response in
/// server/pocketbase/internal/filesystem/filesystem.go. Size/modTime are
/// only meaningful for files; children is only populated for directories.
@freezed
abstract class FileTreeEntry with _$FileTreeEntry {
  const factory FileTreeEntry({
    required String name,
    @JsonKey(name: 'isDir') required bool isDir,
    int? size,
    @JsonKey(name: 'modTime') String? modTime,
    @Default([]) List<FileTreeEntry> children,
  }) = _FileTreeEntry;

  factory FileTreeEntry.fromJson(Map<String, dynamic> json) =>
      _$FileTreeEntryFromJson(json);
}
