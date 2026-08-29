// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_monitoring_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatMonitoringState {
  String? get chatId;
  bool get monitored;
  UiFlowStatus get status;
  Object? get error;
  ChatMonitoringOperation? get lastOperation;

  /// Create a copy of ChatMonitoringState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChatMonitoringStateCopyWith<ChatMonitoringState> get copyWith =>
      _$ChatMonitoringStateCopyWithImpl<ChatMonitoringState>(
          this as ChatMonitoringState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChatMonitoringState &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.monitored, monitored) ||
                other.monitored == monitored) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            (identical(other.lastOperation, lastOperation) ||
                other.lastOperation == lastOperation));
  }

  @override
  int get hashCode => Object.hash(runtimeType, chatId, monitored, status,
      const DeepCollectionEquality().hash(error), lastOperation);

  @override
  String toString() {
    return 'ChatMonitoringState(chatId: $chatId, monitored: $monitored, status: $status, error: $error, lastOperation: $lastOperation)';
  }
}

/// @nodoc
abstract mixin class $ChatMonitoringStateCopyWith<$Res> {
  factory $ChatMonitoringStateCopyWith(
          ChatMonitoringState value, $Res Function(ChatMonitoringState) _then) =
      _$ChatMonitoringStateCopyWithImpl;
  @useResult
  $Res call(
      {String? chatId,
      bool monitored,
      UiFlowStatus status,
      Object? error,
      ChatMonitoringOperation? lastOperation});
}

/// @nodoc
class _$ChatMonitoringStateCopyWithImpl<$Res>
    implements $ChatMonitoringStateCopyWith<$Res> {
  _$ChatMonitoringStateCopyWithImpl(this._self, this._then);

  final ChatMonitoringState _self;
  final $Res Function(ChatMonitoringState) _then;

  /// Create a copy of ChatMonitoringState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chatId = freezed,
    Object? monitored = null,
    Object? status = null,
    Object? error = freezed,
    Object? lastOperation = freezed,
  }) {
    return _then(_self.copyWith(
      chatId: freezed == chatId
          ? _self.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      monitored: null == monitored
          ? _self.monitored
          : monitored // ignore: cast_nullable_to_non_nullable
              as bool,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
      lastOperation: freezed == lastOperation
          ? _self.lastOperation
          : lastOperation // ignore: cast_nullable_to_non_nullable
              as ChatMonitoringOperation?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ChatMonitoringState].
extension ChatMonitoringStatePatterns on ChatMonitoringState {
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
    TResult Function(_ChatMonitoringState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatMonitoringState() when $default != null:
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
    TResult Function(_ChatMonitoringState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatMonitoringState():
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
    TResult? Function(_ChatMonitoringState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatMonitoringState() when $default != null:
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
    TResult Function(String? chatId, bool monitored, UiFlowStatus status,
            Object? error, ChatMonitoringOperation? lastOperation)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatMonitoringState() when $default != null:
        return $default(_that.chatId, _that.monitored, _that.status,
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
    TResult Function(String? chatId, bool monitored, UiFlowStatus status,
            Object? error, ChatMonitoringOperation? lastOperation)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatMonitoringState():
        return $default(_that.chatId, _that.monitored, _that.status,
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
    TResult? Function(String? chatId, bool monitored, UiFlowStatus status,
            Object? error, ChatMonitoringOperation? lastOperation)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatMonitoringState() when $default != null:
        return $default(_that.chatId, _that.monitored, _that.status,
            _that.error, _that.lastOperation);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ChatMonitoringState extends ChatMonitoringState {
  const _ChatMonitoringState(
      {this.chatId,
      this.monitored = false,
      this.status = UiFlowStatus.idle,
      this.error,
      this.lastOperation})
      : super._();

  @override
  final String? chatId;
  @override
  @JsonKey()
  final bool monitored;
  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final Object? error;
  @override
  final ChatMonitoringOperation? lastOperation;

  /// Create a copy of ChatMonitoringState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChatMonitoringStateCopyWith<_ChatMonitoringState> get copyWith =>
      __$ChatMonitoringStateCopyWithImpl<_ChatMonitoringState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChatMonitoringState &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.monitored, monitored) ||
                other.monitored == monitored) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            (identical(other.lastOperation, lastOperation) ||
                other.lastOperation == lastOperation));
  }

  @override
  int get hashCode => Object.hash(runtimeType, chatId, monitored, status,
      const DeepCollectionEquality().hash(error), lastOperation);

  @override
  String toString() {
    return 'ChatMonitoringState(chatId: $chatId, monitored: $monitored, status: $status, error: $error, lastOperation: $lastOperation)';
  }
}

/// @nodoc
abstract mixin class _$ChatMonitoringStateCopyWith<$Res>
    implements $ChatMonitoringStateCopyWith<$Res> {
  factory _$ChatMonitoringStateCopyWith(_ChatMonitoringState value,
          $Res Function(_ChatMonitoringState) _then) =
      __$ChatMonitoringStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? chatId,
      bool monitored,
      UiFlowStatus status,
      Object? error,
      ChatMonitoringOperation? lastOperation});
}

/// @nodoc
class __$ChatMonitoringStateCopyWithImpl<$Res>
    implements _$ChatMonitoringStateCopyWith<$Res> {
  __$ChatMonitoringStateCopyWithImpl(this._self, this._then);

  final _ChatMonitoringState _self;
  final $Res Function(_ChatMonitoringState) _then;

  /// Create a copy of ChatMonitoringState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? chatId = freezed,
    Object? monitored = null,
    Object? status = null,
    Object? error = freezed,
    Object? lastOperation = freezed,
  }) {
    return _then(_ChatMonitoringState(
      chatId: freezed == chatId
          ? _self.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      monitored: null == monitored
          ? _self.monitored
          : monitored // ignore: cast_nullable_to_non_nullable
              as bool,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
      lastOperation: freezed == lastOperation
          ? _self.lastOperation
          : lastOperation // ignore: cast_nullable_to_non_nullable
              as ChatMonitoringOperation?,
    ));
  }
}

// dart format on
