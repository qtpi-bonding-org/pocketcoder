// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'file_browser_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FileBrowserState {
  UiFlowStatus get status;
  String get path;
  List<FileEntry> get entries;
  Object? get error;

  /// Create a copy of FileBrowserState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FileBrowserStateCopyWith<FileBrowserState> get copyWith =>
      _$FileBrowserStateCopyWithImpl<FileBrowserState>(
          this as FileBrowserState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FileBrowserState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.path, path) || other.path == path) &&
            const DeepCollectionEquality().equals(other.entries, entries) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      path,
      const DeepCollectionEquality().hash(entries),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'FileBrowserState(status: $status, path: $path, entries: $entries, error: $error)';
  }
}

/// @nodoc
abstract mixin class $FileBrowserStateCopyWith<$Res> {
  factory $FileBrowserStateCopyWith(
          FileBrowserState value, $Res Function(FileBrowserState) _then) =
      _$FileBrowserStateCopyWithImpl;
  @useResult
  $Res call(
      {UiFlowStatus status,
      String path,
      List<FileEntry> entries,
      Object? error});
}

/// @nodoc
class _$FileBrowserStateCopyWithImpl<$Res>
    implements $FileBrowserStateCopyWith<$Res> {
  _$FileBrowserStateCopyWithImpl(this._self, this._then);

  final FileBrowserState _self;
  final $Res Function(FileBrowserState) _then;

  /// Create a copy of FileBrowserState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? path = null,
    Object? entries = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      path: null == path
          ? _self.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
      entries: null == entries
          ? _self.entries
          : entries // ignore: cast_nullable_to_non_nullable
              as List<FileEntry>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [FileBrowserState].
extension FileBrowserStatePatterns on FileBrowserState {
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
    TResult Function(_FileBrowserState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FileBrowserState() when $default != null:
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
    TResult Function(_FileBrowserState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileBrowserState():
        return $default(_that);
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
    TResult? Function(_FileBrowserState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileBrowserState() when $default != null:
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
    TResult Function(UiFlowStatus status, String path, List<FileEntry> entries,
            Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FileBrowserState() when $default != null:
        return $default(_that.status, _that.path, _that.entries, _that.error);
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
    TResult Function(UiFlowStatus status, String path, List<FileEntry> entries,
            Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileBrowserState():
        return $default(_that.status, _that.path, _that.entries, _that.error);
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
    TResult? Function(UiFlowStatus status, String path, List<FileEntry> entries,
            Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileBrowserState() when $default != null:
        return $default(_that.status, _that.path, _that.entries, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _FileBrowserState extends FileBrowserState {
  const _FileBrowserState(
      {this.status = UiFlowStatus.idle,
      this.path = '',
      final List<FileEntry> entries = const [],
      this.error})
      : _entries = entries,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  @JsonKey()
  final String path;
  final List<FileEntry> _entries;
  @override
  @JsonKey()
  List<FileEntry> get entries {
    if (_entries is EqualUnmodifiableListView) return _entries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_entries);
  }

  @override
  final Object? error;

  /// Create a copy of FileBrowserState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FileBrowserStateCopyWith<_FileBrowserState> get copyWith =>
      __$FileBrowserStateCopyWithImpl<_FileBrowserState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FileBrowserState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.path, path) || other.path == path) &&
            const DeepCollectionEquality().equals(other._entries, _entries) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      path,
      const DeepCollectionEquality().hash(_entries),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'FileBrowserState(status: $status, path: $path, entries: $entries, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$FileBrowserStateCopyWith<$Res>
    implements $FileBrowserStateCopyWith<$Res> {
  factory _$FileBrowserStateCopyWith(
          _FileBrowserState value, $Res Function(_FileBrowserState) _then) =
      __$FileBrowserStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {UiFlowStatus status,
      String path,
      List<FileEntry> entries,
      Object? error});
}

/// @nodoc
class __$FileBrowserStateCopyWithImpl<$Res>
    implements _$FileBrowserStateCopyWith<$Res> {
  __$FileBrowserStateCopyWithImpl(this._self, this._then);

  final _FileBrowserState _self;
  final $Res Function(_FileBrowserState) _then;

  /// Create a copy of FileBrowserState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? path = null,
    Object? entries = null,
    Object? error = freezed,
  }) {
    return _then(_FileBrowserState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      path: null == path
          ? _self.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
      entries: null == entries
          ? _self._entries
          : entries // ignore: cast_nullable_to_non_nullable
              as List<FileEntry>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
