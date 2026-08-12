// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatListState {
  UiFlowStatus get status;
  List<Chat> get chats;
  String? get lastCreatedChatId;
  Object? get error;

  /// Create a copy of ChatListState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChatListStateCopyWith<ChatListState> get copyWith =>
      _$ChatListStateCopyWithImpl<ChatListState>(
          this as ChatListState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChatListState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.chats, chats) &&
            (identical(other.lastCreatedChatId, lastCreatedChatId) ||
                other.lastCreatedChatId == lastCreatedChatId) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(chats),
      lastCreatedChatId,
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'ChatListState(status: $status, chats: $chats, lastCreatedChatId: $lastCreatedChatId, error: $error)';
  }
}

/// @nodoc
abstract mixin class $ChatListStateCopyWith<$Res> {
  factory $ChatListStateCopyWith(
          ChatListState value, $Res Function(ChatListState) _then) =
      _$ChatListStateCopyWithImpl;
  @useResult
  $Res call(
      {UiFlowStatus status,
      List<Chat> chats,
      String? lastCreatedChatId,
      Object? error});
}

/// @nodoc
class _$ChatListStateCopyWithImpl<$Res>
    implements $ChatListStateCopyWith<$Res> {
  _$ChatListStateCopyWithImpl(this._self, this._then);

  final ChatListState _self;
  final $Res Function(ChatListState) _then;

  /// Create a copy of ChatListState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? chats = null,
    Object? lastCreatedChatId = freezed,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      chats: null == chats
          ? _self.chats
          : chats // ignore: cast_nullable_to_non_nullable
              as List<Chat>,
      lastCreatedChatId: freezed == lastCreatedChatId
          ? _self.lastCreatedChatId
          : lastCreatedChatId // ignore: cast_nullable_to_non_nullable
              as String?,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [ChatListState].
extension ChatListStatePatterns on ChatListState {
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
    TResult Function(_ChatListState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatListState() when $default != null:
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
    TResult Function(_ChatListState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatListState():
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
    TResult? Function(_ChatListState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatListState() when $default != null:
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
    TResult Function(UiFlowStatus status, List<Chat> chats,
            String? lastCreatedChatId, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatListState() when $default != null:
        return $default(
            _that.status, _that.chats, _that.lastCreatedChatId, _that.error);
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
    TResult Function(UiFlowStatus status, List<Chat> chats,
            String? lastCreatedChatId, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatListState():
        return $default(
            _that.status, _that.chats, _that.lastCreatedChatId, _that.error);
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
    TResult? Function(UiFlowStatus status, List<Chat> chats,
            String? lastCreatedChatId, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatListState() when $default != null:
        return $default(
            _that.status, _that.chats, _that.lastCreatedChatId, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ChatListState extends ChatListState {
  const _ChatListState(
      {this.status = UiFlowStatus.idle,
      final List<Chat> chats = const [],
      this.lastCreatedChatId,
      this.error})
      : _chats = chats,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  final List<Chat> _chats;
  @override
  @JsonKey()
  List<Chat> get chats {
    if (_chats is EqualUnmodifiableListView) return _chats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chats);
  }

  @override
  final String? lastCreatedChatId;
  @override
  final Object? error;

  /// Create a copy of ChatListState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChatListStateCopyWith<_ChatListState> get copyWith =>
      __$ChatListStateCopyWithImpl<_ChatListState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChatListState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._chats, _chats) &&
            (identical(other.lastCreatedChatId, lastCreatedChatId) ||
                other.lastCreatedChatId == lastCreatedChatId) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_chats),
      lastCreatedChatId,
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'ChatListState(status: $status, chats: $chats, lastCreatedChatId: $lastCreatedChatId, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$ChatListStateCopyWith<$Res>
    implements $ChatListStateCopyWith<$Res> {
  factory _$ChatListStateCopyWith(
          _ChatListState value, $Res Function(_ChatListState) _then) =
      __$ChatListStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {UiFlowStatus status,
      List<Chat> chats,
      String? lastCreatedChatId,
      Object? error});
}

/// @nodoc
class __$ChatListStateCopyWithImpl<$Res>
    implements _$ChatListStateCopyWith<$Res> {
  __$ChatListStateCopyWithImpl(this._self, this._then);

  final _ChatListState _self;
  final $Res Function(_ChatListState) _then;

  /// Create a copy of ChatListState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? chats = null,
    Object? lastCreatedChatId = freezed,
    Object? error = freezed,
  }) {
    return _then(_ChatListState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      chats: null == chats
          ? _self._chats
          : chats // ignore: cast_nullable_to_non_nullable
              as List<Chat>,
      lastCreatedChatId: freezed == lastCreatedChatId
          ? _self.lastCreatedChatId
          : lastCreatedChatId // ignore: cast_nullable_to_non_nullable
              as String?,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
