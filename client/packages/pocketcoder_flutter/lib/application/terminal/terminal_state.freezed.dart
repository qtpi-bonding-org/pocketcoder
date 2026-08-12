// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'terminal_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SshTerminalState {
  UiFlowStatus get status;
  Object? get error;
  String? get sessionId;
  bool get isSyncingKeys;
  bool get isUploading;
  String? get uploadFileName;

  /// Create a copy of SshTerminalState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SshTerminalStateCopyWith<SshTerminalState> get copyWith =>
      _$SshTerminalStateCopyWithImpl<SshTerminalState>(
          this as SshTerminalState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SshTerminalState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.isSyncingKeys, isSyncingKeys) ||
                other.isSyncingKeys == isSyncingKeys) &&
            (identical(other.isUploading, isUploading) ||
                other.isUploading == isUploading) &&
            (identical(other.uploadFileName, uploadFileName) ||
                other.uploadFileName == uploadFileName));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(error),
      sessionId,
      isSyncingKeys,
      isUploading,
      uploadFileName);

  @override
  String toString() {
    return 'SshTerminalState(status: $status, error: $error, sessionId: $sessionId, isSyncingKeys: $isSyncingKeys, isUploading: $isUploading, uploadFileName: $uploadFileName)';
  }
}

/// @nodoc
abstract mixin class $SshTerminalStateCopyWith<$Res> {
  factory $SshTerminalStateCopyWith(
          SshTerminalState value, $Res Function(SshTerminalState) _then) =
      _$SshTerminalStateCopyWithImpl;
  @useResult
  $Res call(
      {UiFlowStatus status,
      Object? error,
      String? sessionId,
      bool isSyncingKeys,
      bool isUploading,
      String? uploadFileName});
}

/// @nodoc
class _$SshTerminalStateCopyWithImpl<$Res>
    implements $SshTerminalStateCopyWith<$Res> {
  _$SshTerminalStateCopyWithImpl(this._self, this._then);

  final SshTerminalState _self;
  final $Res Function(SshTerminalState) _then;

  /// Create a copy of SshTerminalState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? error = freezed,
    Object? sessionId = freezed,
    Object? isSyncingKeys = null,
    Object? isUploading = null,
    Object? uploadFileName = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
      sessionId: freezed == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      isSyncingKeys: null == isSyncingKeys
          ? _self.isSyncingKeys
          : isSyncingKeys // ignore: cast_nullable_to_non_nullable
              as bool,
      isUploading: null == isUploading
          ? _self.isUploading
          : isUploading // ignore: cast_nullable_to_non_nullable
              as bool,
      uploadFileName: freezed == uploadFileName
          ? _self.uploadFileName
          : uploadFileName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SshTerminalState].
extension SshTerminalStatePatterns on SshTerminalState {
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
    TResult Function(_SshTerminalState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SshTerminalState() when $default != null:
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
    TResult Function(_SshTerminalState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SshTerminalState():
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
    TResult? Function(_SshTerminalState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SshTerminalState() when $default != null:
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
    TResult Function(UiFlowStatus status, Object? error, String? sessionId,
            bool isSyncingKeys, bool isUploading, String? uploadFileName)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SshTerminalState() when $default != null:
        return $default(_that.status, _that.error, _that.sessionId,
            _that.isSyncingKeys, _that.isUploading, _that.uploadFileName);
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
    TResult Function(UiFlowStatus status, Object? error, String? sessionId,
            bool isSyncingKeys, bool isUploading, String? uploadFileName)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SshTerminalState():
        return $default(_that.status, _that.error, _that.sessionId,
            _that.isSyncingKeys, _that.isUploading, _that.uploadFileName);
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
    TResult? Function(UiFlowStatus status, Object? error, String? sessionId,
            bool isSyncingKeys, bool isUploading, String? uploadFileName)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SshTerminalState() when $default != null:
        return $default(_that.status, _that.error, _that.sessionId,
            _that.isSyncingKeys, _that.isUploading, _that.uploadFileName);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SshTerminalState extends SshTerminalState {
  const _SshTerminalState(
      {this.status = UiFlowStatus.idle,
      this.error,
      this.sessionId,
      this.isSyncingKeys = false,
      this.isUploading = false,
      this.uploadFileName})
      : super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final Object? error;
  @override
  final String? sessionId;
  @override
  @JsonKey()
  final bool isSyncingKeys;
  @override
  @JsonKey()
  final bool isUploading;
  @override
  final String? uploadFileName;

  /// Create a copy of SshTerminalState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SshTerminalStateCopyWith<_SshTerminalState> get copyWith =>
      __$SshTerminalStateCopyWithImpl<_SshTerminalState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SshTerminalState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.isSyncingKeys, isSyncingKeys) ||
                other.isSyncingKeys == isSyncingKeys) &&
            (identical(other.isUploading, isUploading) ||
                other.isUploading == isUploading) &&
            (identical(other.uploadFileName, uploadFileName) ||
                other.uploadFileName == uploadFileName));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(error),
      sessionId,
      isSyncingKeys,
      isUploading,
      uploadFileName);

  @override
  String toString() {
    return 'SshTerminalState(status: $status, error: $error, sessionId: $sessionId, isSyncingKeys: $isSyncingKeys, isUploading: $isUploading, uploadFileName: $uploadFileName)';
  }
}

/// @nodoc
abstract mixin class _$SshTerminalStateCopyWith<$Res>
    implements $SshTerminalStateCopyWith<$Res> {
  factory _$SshTerminalStateCopyWith(
          _SshTerminalState value, $Res Function(_SshTerminalState) _then) =
      __$SshTerminalStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {UiFlowStatus status,
      Object? error,
      String? sessionId,
      bool isSyncingKeys,
      bool isUploading,
      String? uploadFileName});
}

/// @nodoc
class __$SshTerminalStateCopyWithImpl<$Res>
    implements _$SshTerminalStateCopyWith<$Res> {
  __$SshTerminalStateCopyWithImpl(this._self, this._then);

  final _SshTerminalState _self;
  final $Res Function(_SshTerminalState) _then;

  /// Create a copy of SshTerminalState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? error = freezed,
    Object? sessionId = freezed,
    Object? isSyncingKeys = null,
    Object? isUploading = null,
    Object? uploadFileName = freezed,
  }) {
    return _then(_SshTerminalState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
      sessionId: freezed == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      isSyncingKeys: null == isSyncingKeys
          ? _self.isSyncingKeys
          : isSyncingKeys // ignore: cast_nullable_to_non_nullable
              as bool,
      isUploading: null == isUploading
          ? _self.isUploading
          : isUploading // ignore: cast_nullable_to_non_nullable
              as bool,
      uploadFileName: freezed == uploadFileName
          ? _self.uploadFileName
          : uploadFileName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
