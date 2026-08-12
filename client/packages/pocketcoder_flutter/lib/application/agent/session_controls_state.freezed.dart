// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_controls_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionControlsState {
  String? get chatId;
  SessionState get sessionState;
  UiFlowStatus get status;
  Object? get error;
  SessionControlsOperation? get lastOperation;

  /// Create a copy of SessionControlsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SessionControlsStateCopyWith<SessionControlsState> get copyWith =>
      _$SessionControlsStateCopyWithImpl<SessionControlsState>(
          this as SessionControlsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SessionControlsState &&
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
    return 'SessionControlsState(chatId: $chatId, sessionState: $sessionState, status: $status, error: $error, lastOperation: $lastOperation)';
  }
}

/// @nodoc
abstract mixin class $SessionControlsStateCopyWith<$Res> {
  factory $SessionControlsStateCopyWith(SessionControlsState value,
          $Res Function(SessionControlsState) _then) =
      _$SessionControlsStateCopyWithImpl;
  @useResult
  $Res call(
      {String? chatId,
      SessionState sessionState,
      UiFlowStatus status,
      Object? error,
      SessionControlsOperation? lastOperation});

  $SessionStateCopyWith<$Res> get sessionState;
}

/// @nodoc
class _$SessionControlsStateCopyWithImpl<$Res>
    implements $SessionControlsStateCopyWith<$Res> {
  _$SessionControlsStateCopyWithImpl(this._self, this._then);

  final SessionControlsState _self;
  final $Res Function(SessionControlsState) _then;

  /// Create a copy of SessionControlsState
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
              as SessionControlsOperation?,
    ));
  }

  /// Create a copy of SessionControlsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SessionStateCopyWith<$Res> get sessionState {
    return $SessionStateCopyWith<$Res>(_self.sessionState, (value) {
      return _then(_self.copyWith(sessionState: value));
    });
  }
}

/// Adds pattern-matching-related methods to [SessionControlsState].
extension SessionControlsStatePatterns on SessionControlsState {
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
    TResult Function(_SessionControlsState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SessionControlsState() when $default != null:
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
    TResult Function(_SessionControlsState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionControlsState():
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
    TResult? Function(_SessionControlsState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionControlsState() when $default != null:
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
            SessionControlsOperation? lastOperation)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SessionControlsState() when $default != null:
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
            SessionControlsOperation? lastOperation)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionControlsState():
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
            SessionControlsOperation? lastOperation)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SessionControlsState() when $default != null:
        return $default(_that.chatId, _that.sessionState, _that.status,
            _that.error, _that.lastOperation);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SessionControlsState extends SessionControlsState {
  const _SessionControlsState(
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
  final SessionControlsOperation? lastOperation;

  /// Create a copy of SessionControlsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SessionControlsStateCopyWith<_SessionControlsState> get copyWith =>
      __$SessionControlsStateCopyWithImpl<_SessionControlsState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SessionControlsState &&
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
    return 'SessionControlsState(chatId: $chatId, sessionState: $sessionState, status: $status, error: $error, lastOperation: $lastOperation)';
  }
}

/// @nodoc
abstract mixin class _$SessionControlsStateCopyWith<$Res>
    implements $SessionControlsStateCopyWith<$Res> {
  factory _$SessionControlsStateCopyWith(_SessionControlsState value,
          $Res Function(_SessionControlsState) _then) =
      __$SessionControlsStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? chatId,
      SessionState sessionState,
      UiFlowStatus status,
      Object? error,
      SessionControlsOperation? lastOperation});

  @override
  $SessionStateCopyWith<$Res> get sessionState;
}

/// @nodoc
class __$SessionControlsStateCopyWithImpl<$Res>
    implements _$SessionControlsStateCopyWith<$Res> {
  __$SessionControlsStateCopyWithImpl(this._self, this._then);

  final _SessionControlsState _self;
  final $Res Function(_SessionControlsState) _then;

  /// Create a copy of SessionControlsState
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
    return _then(_SessionControlsState(
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
              as SessionControlsOperation?,
    ));
  }

  /// Create a copy of SessionControlsState
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
