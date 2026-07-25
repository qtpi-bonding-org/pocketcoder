import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_entry.freezed.dart';
part 'file_entry.g.dart';

/// One immediate child of a listed workspace directory. NOT PocketBase-backed
/// — built from JSON returned by GET /api/pocketcoder/files-list/{path}
/// (services/pocketbase/internal/filesystem/filesystem.go), the same category
/// of hand-written, non-collection model as [Skill].
@freezed
abstract class FileEntry with _$FileEntry {
  const factory FileEntry({
    required String name,
    required bool isDir,
    required int size,
    required String modTime,
  }) = _FileEntry;

  factory FileEntry.fromJson(Map<String, dynamic> json) =>
      _$FileEntryFromJson(json);
}
