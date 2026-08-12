// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'permission_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PermissionState {
  String? get chatId;
  SessionState get sessionState;
  UiFlowStatus get status;
  Object? get error;
  PermissionOperation? get lastOperation;

  /// Create a copy of PermissionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PermissionStateCopyWith<PermissionState> get copyWith =>
      _$PermissionStateCopyWithImpl<PermissionState>(
          this as PermissionState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PermissionState &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.sessionState, sessionState) ||
                other.sessionState == sessionState) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            (identical(other.lastOperation, lastOperation) ||
                other.lastOperation == lastOperation));
  }

  @override
  int get hashCode => Object.hash(runtimeType, chatId, sessionState, status,
      const DeepCollectionEquality().hash(error), lastOperation);

  @override
  String toString() {
    return 'PermissionState(chatId: $chatId, sessionState: $sessionState, status: $status, error: $error, lastOperation: $lastOperation)';
  }
}

/// @nodoc
abstract mixin class $PermissionStateCopyWith<$Res> {
  factory $PermissionStateCopyWith(
          PermissionState value, $Res Function(PermissionState) _then) =
      _$PermissionStateCopyWithImpl;
  @useResult
  $Res call(
      {String? chatId,
      SessionState sessionState,
      UiFlowStatus status,
      Object? error,
      PermissionOperation? lastOperation});

  $SessionStateCopyWith<$Res> get sessionState;
}

/// @nodoc
class _$PermissionStateCopyWithImpl<$Res>
    implements $PermissionStateCopyWith<$Res> {
  _$PermissionStateCopyWithImpl(this._self, this._then);

  final PermissionState _self;
  final $Res Function(PermissionState) _then;

  /// Create a copy of PermissionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chatId = freezed,
    Object? sessionState = null,
    Object? status = null,
    Object? error = freezed,
    Object? lastOperation = freezed,
  }) {
    return _then(_self.copyWith(
      chatId: freezed == chatId
          ? _self.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      sessionState: null == sessionState
          ? _self.sessionState
          : sessionState // ignore: cast_nullable_to_non_nullable
              as SessionState,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
      lastOperation: freezed == lastOperation
          ? _self.lastOperation
          : lastOperation // ignore: cast_nullable_to_non_nullable
              as PermissionOperation?,
    ));
  }

  /// Create a copy of PermissionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SessionStateCopyWith<$Res> get sessionState {
    return $SessionStateCopyWith<$Res>(_self.sessionState, (value) {
      return _then(_self.copyWith(sessionState: value));
    });
  }
}

/// Adds pattern-matching-related methods to [PermissionState].
extension PermissionStatePatterns on PermissionState {
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
    TResult Function(_PermissionState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PermissionState() when $default != null:
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
    TResult Function(_PermissionState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionState():
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
    TResult? Function(_PermissionState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionState() when $default != null:
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
            String? chatId,
            SessionState sessionState,
            UiFlowStatus status,
            Object? error,
            PermissionOperation? lastOperation)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PermissionState() when $default != null:
        return $default(_that.chatId, _that.sessionState, _that.status,
            _that.error, _that.lastOperation);
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
            String? chatId,
            SessionState sessionState,
            UiFlowStatus status,
            Object? error,
            PermissionOperation? lastOperation)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionState():
        return $default(_that.chatId, _that.sessionState, _that.status,
            _that.error, _that.lastOperation);
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
            String? chatId,
            SessionState sessionState,
            UiFlowStatus status,
            Object? error,
            PermissionOperation? lastOperation)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionState() when $default != null:
        return $default(_that.chatId, _that.sessionState, _that.status,
            _that.error, _that.lastOperation);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PermissionState extends PermissionState {
  const _PermissionState(
      {this.chatId,
      this.sessionState = SessionState.empty,
      this.status = UiFlowStatus.idle,
      this.error,
      this.lastOperation})
      : super._();

  @override
  final String? chatId;
  @override
  @JsonKey()
  final SessionState sessionState;
  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final Object? error;
  @override
  final PermissionOperation? lastOperation;

  /// Create a copy of PermissionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PermissionStateCopyWith<_PermissionState> get copyWith =>
      __$PermissionStateCopyWithImpl<_PermissionState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PermissionState &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.sessionState, sessionState) ||
                other.sessionState == sessionState) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            (identical(other.lastOperation, lastOperation) ||
                other.lastOperation == lastOperation));
  }

  @override
  int get hashCode => Object.hash(runtimeType, chatId, sessionState, status,
      const DeepCollectionEquality().hash(error), lastOperation);

  @override
  String toString() {
    return 'PermissionState(chatId: $chatId, sessionState: $sessionState, status: $status, error: $error, lastOperation: $lastOperation)';
  }
}

/// @nodoc
abstract mixin class _$PermissionStateCopyWith<$Res>
    implements $PermissionStateCopyWith<$Res> {
  factory _$PermissionStateCopyWith(
          _PermissionState value, $Res Function(_PermissionState) _then) =
      __$PermissionStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? chatId,
      SessionState sessionState,
      UiFlowStatus status,
      Object? error,
      PermissionOperation? lastOperation});

  @override
  $SessionStateCopyWith<$Res> get sessionState;
}

/// @nodoc
class __$PermissionStateCopyWithImpl<$Res>
    implements _$PermissionStateCopyWith<$Res> {
  __$PermissionStateCopyWithImpl(this._self, this._then);

  final _PermissionState _self;
  final $Res Function(_PermissionState) _then;

  /// Create a copy of PermissionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? chatId = freezed,
    Object? sessionState = null,
    Object? status = null,
    Object? error = freezed,
    Object? lastOperation = freezed,
  }) {
    return _then(_PermissionState(
      chatId: freezed == chatId
          ? _self.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      sessionState: null == sessionState
          ? _self.sessionState
          : sessionState // ignore: cast_nullable_to_non_nullable
              as SessionState,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
      lastOperation: freezed == lastOperation
          ? _self.lastOperation
          : lastOperation // ignore: cast_nullable_to_non_nullable
              as PermissionOperation?,
    ));
  }

  /// Create a copy of PermissionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SessionStateCopyWith<$Res> get sessionState {
    return $SessionStateCopyWith<$Res>(_self.sessionState, (value) {
      return _then(_self.copyWith(sessionState: value));
    });
  }
}

// dart format on
