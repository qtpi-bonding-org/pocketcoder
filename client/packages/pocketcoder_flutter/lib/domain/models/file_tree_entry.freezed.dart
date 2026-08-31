// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'file_tree_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FileTreeEntry {
  String get name;
  @JsonKey(name: 'isDir')
  bool get isDir;
  int? get size;
  @JsonKey(name: 'modTime')
  String? get modTime;
  List<FileTreeEntry> get children;

  /// Create a copy of FileTreeEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FileTreeEntryCopyWith<FileTreeEntry> get copyWith =>
      _$FileTreeEntryCopyWithImpl<FileTreeEntry>(
          this as FileTreeEntry, _$identity);

  /// Serializes this FileTreeEntry to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FileTreeEntry &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.isDir, isDir) || other.isDir == isDir) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.modTime, modTime) || other.modTime == modTime) &&
            const DeepCollectionEquality().equals(other.children, children));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, isDir, size, modTime,
      const DeepCollectionEquality().hash(children));

  @override
  String toString() {
    return 'FileTreeEntry(name: $name, isDir: $isDir, size: $size, modTime: $modTime, children: $children)';
  }
}

/// @nodoc
abstract mixin class $FileTreeEntryCopyWith<$Res> {
  factory $FileTreeEntryCopyWith(
          FileTreeEntry value, $Res Function(FileTreeEntry) _then) =
      _$FileTreeEntryCopyWithImpl;
  @useResult
  $Res call(
      {String name,
      @JsonKey(name: 'isDir') bool isDir,
      int? size,
      @JsonKey(name: 'modTime') String? modTime,
      List<FileTreeEntry> children});
}

/// @nodoc
class _$FileTreeEntryCopyWithImpl<$Res>
    implements $FileTreeEntryCopyWith<$Res> {
  _$FileTreeEntryCopyWithImpl(this._self, this._then);

  final FileTreeEntry _self;
  final $Res Function(FileTreeEntry) _then;

  /// Create a copy of FileTreeEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? isDir = null,
    Object? size = freezed,
    Object? modTime = freezed,
    Object? children = null,
  }) {
    return _then(_self.copyWith(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      isDir: null == isDir
          ? _self.isDir
          : isDir // ignore: cast_nullable_to_non_nullable
              as bool,
      size: freezed == size
          ? _self.size
          : size // ignore: cast_nullable_to_non_nullable
              as int?,
      modTime: freezed == modTime
          ? _self.modTime
          : modTime // ignore: cast_nullable_to_non_nullable
              as String?,
      children: null == children
          ? _self.children
          : children // ignore: cast_nullable_to_non_nullable
              as List<FileTreeEntry>,
    ));
  }
}

/// Adds pattern-matching-related methods to [FileTreeEntry].
extension FileTreeEntryPatterns on FileTreeEntry {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_FileTreeEntry value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FileTreeEntry() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_FileTreeEntry value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileTreeEntry():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_FileTreeEntry value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileTreeEntry() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String name,
            @JsonKey(name: 'isDir') bool isDir,
            int? size,
            @JsonKey(name: 'modTime') String? modTime,
            List<FileTreeEntry> children)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FileTreeEntry() when $default != null:
        return $default(
            _that.name, _that.isDir, _that.size, _that.modTime, _that.children);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String name,
            @JsonKey(name: 'isDir') bool isDir,
            int? size,
            @JsonKey(name: 'modTime') String? modTime,
            List<FileTreeEntry> children)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileTreeEntry():
        return $default(
            _that.name, _that.isDir, _that.size, _that.modTime, _that.children);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String name,
            @JsonKey(name: 'isDir') bool isDir,
            int? size,
            @JsonKey(name: 'modTime') String? modTime,
            List<FileTreeEntry> children)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileTreeEntry() when $default != null:
        return $default(
            _that.name, _that.isDir, _that.size, _that.modTime, _that.children);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _FileTreeEntry implements FileTreeEntry {
  const _FileTreeEntry(
      {required this.name,
      @JsonKey(name: 'isDir') required this.isDir,
      this.size,
      @JsonKey(name: 'modTime') this.modTime,
      final List<FileTreeEntry> children = const []})
      : _children = children;
  factory _FileTreeEntry.fromJson(Map<String, dynamic> json) =>
      _$FileTreeEntryFromJson(json);

  @override
  final String name;
  @override
  @JsonKey(name: 'isDir')
  final bool isDir;
  @override
  final int? size;
  @override
  @JsonKey(name: 'modTime')
  final String? modTime;
  final List<FileTreeEntry> _children;
  @override
  @JsonKey()
  List<FileTreeEntry> get children {
    if (_children is EqualUnmodifiableListView) return _children;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_children);
  }

  /// Create a copy of FileTreeEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FileTreeEntryCopyWith<_FileTreeEntry> get copyWith =>
      __$FileTreeEntryCopyWithImpl<_FileTreeEntry>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FileTreeEntryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FileTreeEntry &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.isDir, isDir) || other.isDir == isDir) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.modTime, modTime) || other.modTime == modTime) &&
            const DeepCollectionEquality().equals(other._children, _children));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, isDir, size, modTime,
      const DeepCollectionEquality().hash(_children));

  @override
  String toString() {
    return 'FileTreeEntry(name: $name, isDir: $isDir, size: $size, modTime: $modTime, children: $children)';
  }
}

/// @nodoc
abstract mixin class _$FileTreeEntryCopyWith<$Res>
    implements $FileTreeEntryCopyWith<$Res> {
  factory _$FileTreeEntryCopyWith(
          _FileTreeEntry value, $Res Function(_FileTreeEntry) _then) =
      __$FileTreeEntryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String name,
      @JsonKey(name: 'isDir') bool isDir,
      int? size,
      @JsonKey(name: 'modTime') String? modTime,
      List<FileTreeEntry> children});
}

/// @nodoc
class __$FileTreeEntryCopyWithImpl<$Res>
    implements _$FileTreeEntryCopyWith<$Res> {
  __$FileTreeEntryCopyWithImpl(this._self, this._then);

  final _FileTreeEntry _self;
  final $Res Function(_FileTreeEntry) _then;

  /// Create a copy of FileTreeEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? name = null,
    Object? isDir = null,
    Object? size = freezed,
    Object? modTime = freezed,
    Object? children = null,
  }) {
    return _then(_FileTreeEntry(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      isDir: null == isDir
          ? _self.isDir
          : isDir // ignore: cast_nullable_to_non_nullable
              as bool,
      size: freezed == size
          ? _self.size
          : size // ignore: cast_nullable_to_non_nullable
              as int?,
      modTime: freezed == modTime
          ? _self.modTime
          : modTime // ignore: cast_nullable_to_non_nullable
              as String?,
      children: null == children
          ? _self._children
          : children // ignore: cast_nullable_to_non_nullable
              as List<FileTreeEntry>,
    ));
  }
}

// dart format on
