// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'elicitation_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ElicitationState {
  String? get chatId;
  SessionState get sessionState;
  UiFlowStatus get status;
  Object? get error;
  ElicitationOperation? get lastOperation;

  /// Create a copy of ElicitationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ElicitationStateCopyWith<ElicitationState> get copyWith =>
      _$ElicitationStateCopyWithImpl<ElicitationState>(
          this as ElicitationState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ElicitationState &&
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
    return 'ElicitationState(chatId: $chatId, sessionState: $sessionState, status: $status, error: $error, lastOperation: $lastOperation)';
  }
}

/// @nodoc
abstract mixin class $ElicitationStateCopyWith<$Res> {
  factory $ElicitationStateCopyWith(
          ElicitationState value, $Res Function(ElicitationState) _then) =
      _$ElicitationStateCopyWithImpl;
  @useResult
  $Res call(
      {String? chatId,
      SessionState sessionState,
      UiFlowStatus status,
      Object? error,
      ElicitationOperation? lastOperation});

  $SessionStateCopyWith<$Res> get sessionState;
}

/// @nodoc
class _$ElicitationStateCopyWithImpl<$Res>
    implements $ElicitationStateCopyWith<$Res> {
  _$ElicitationStateCopyWithImpl(this._self, this._then);

  final ElicitationState _self;
  final $Res Function(ElicitationState) _then;

  /// Create a copy of ElicitationState
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
              as ElicitationOperation?,
    ));
  }

  /// Create a copy of ElicitationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SessionStateCopyWith<$Res> get sessionState {
    return $SessionStateCopyWith<$Res>(_self.sessionState, (value) {
      return _then(_self.copyWith(sessionState: value));
    });
  }
}

/// Adds pattern-matching-related methods to [ElicitationState].
extension ElicitationStatePatterns on ElicitationState {
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
    TResult Function(_ElicitationState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ElicitationState() when $default != null:
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
    TResult Function(_ElicitationState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ElicitationState():
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
    TResult? Function(_ElicitationState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ElicitationState() when $default != null:
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
            ElicitationOperation? lastOperation)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ElicitationState() when $default != null:
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
            ElicitationOperation? lastOperation)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ElicitationState():
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
            ElicitationOperation? lastOperation)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ElicitationState() when $default != null:
        return $default(_that.chatId, _that.sessionState, _that.status,
            _that.error, _that.lastOperation);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ElicitationState extends ElicitationState {
  const _ElicitationState(
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
  final ElicitationOperation? lastOperation;

  /// Create a copy of ElicitationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ElicitationStateCopyWith<_ElicitationState> get copyWith =>
      __$ElicitationStateCopyWithImpl<_ElicitationState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ElicitationState &&
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
    return 'ElicitationState(chatId: $chatId, sessionState: $sessionState, status: $status, error: $error, lastOperation: $lastOperation)';
  }
}

/// @nodoc
abstract mixin class _$ElicitationStateCopyWith<$Res>
    implements $ElicitationStateCopyWith<$Res> {
  factory _$ElicitationStateCopyWith(
          _ElicitationState value, $Res Function(_ElicitationState) _then) =
      __$ElicitationStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? chatId,
      SessionState sessionState,
      UiFlowStatus status,
      Object? error,
      ElicitationOperation? lastOperation});

  @override
  $SessionStateCopyWith<$Res> get sessionState;
}

/// @nodoc
class __$ElicitationStateCopyWithImpl<$Res>
    implements _$ElicitationStateCopyWith<$Res> {
  __$ElicitationStateCopyWithImpl(this._self, this._then);

  final _ElicitationState _self;
  final $Res Function(_ElicitationState) _then;

  /// Create a copy of ElicitationState
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
    return _then(_ElicitationState(
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
              as ElicitationOperation?,
    ));
  }

  /// Create a copy of ElicitationState
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
