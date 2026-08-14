// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'file_viewer_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FileViewerState {
  UiFlowStatus get status;
  Uint8List? get bytes;
  Object? get error;

  /// Create a copy of FileViewerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FileViewerStateCopyWith<FileViewerState> get copyWith =>
      _$FileViewerStateCopyWithImpl<FileViewerState>(
          this as FileViewerState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FileViewerState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.bytes, bytes) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(bytes),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'FileViewerState(status: $status, bytes: $bytes, error: $error)';
  }
}

/// @nodoc
abstract mixin class $FileViewerStateCopyWith<$Res> {
  factory $FileViewerStateCopyWith(
          FileViewerState value, $Res Function(FileViewerState) _then) =
      _$FileViewerStateCopyWithImpl;
  @useResult
  $Res call({UiFlowStatus status, Uint8List? bytes, Object? error});
}

/// @nodoc
class _$FileViewerStateCopyWithImpl<$Res>
    implements $FileViewerStateCopyWith<$Res> {
  _$FileViewerStateCopyWithImpl(this._self, this._then);

  final FileViewerState _self;
  final $Res Function(FileViewerState) _then;

  /// Create a copy of FileViewerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? bytes = freezed,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      bytes: freezed == bytes
          ? _self.bytes
          : bytes // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [FileViewerState].
extension FileViewerStatePatterns on FileViewerState {
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
    TResult Function(_FileViewerState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FileViewerState() when $default != null:
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
    TResult Function(_FileViewerState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileViewerState():
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
    TResult? Function(_FileViewerState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileViewerState() when $default != null:
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
    TResult Function(UiFlowStatus status, Uint8List? bytes, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FileViewerState() when $default != null:
        return $default(_that.status, _that.bytes, _that.error);
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
    TResult Function(UiFlowStatus status, Uint8List? bytes, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileViewerState():
        return $default(_that.status, _that.bytes, _that.error);
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
    TResult? Function(UiFlowStatus status, Uint8List? bytes, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FileViewerState() when $default != null:
        return $default(_that.status, _that.bytes, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _FileViewerState extends FileViewerState {
  const _FileViewerState(
      {this.status = UiFlowStatus.idle, this.bytes, this.error})
      : super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final Uint8List? bytes;
  @override
  final Object? error;

  /// Create a copy of FileViewerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FileViewerStateCopyWith<_FileViewerState> get copyWith =>
      __$FileViewerStateCopyWithImpl<_FileViewerState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FileViewerState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.bytes, bytes) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(bytes),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'FileViewerState(status: $status, bytes: $bytes, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$FileViewerStateCopyWith<$Res>
    implements $FileViewerStateCopyWith<$Res> {
  factory _$FileViewerStateCopyWith(
          _FileViewerState value, $Res Function(_FileViewerState) _then) =
      __$FileViewerStateCopyWithImpl;
  @override
  @useResult
  $Res call({UiFlowStatus status, Uint8List? bytes, Object? error});
}

/// @nodoc
class __$FileViewerStateCopyWithImpl<$Res>
    implements _$FileViewerStateCopyWith<$Res> {
  __$FileViewerStateCopyWithImpl(this._self, this._then);

  final _FileViewerState _self;
  final $Res Function(_FileViewerState) _then;

  /// Create a copy of FileViewerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? bytes = freezed,
    Object? error = freezed,
  }) {
    return _then(_FileViewerState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      bytes: freezed == bytes
          ? _self.bytes
          : bytes // ignore: cast_nullable_to_non_nullable
              as Uint8List?,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
