// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatState {
  String? get chatId;
  Conversation get conversation;
  UiFlowStatus get status;
  Object? get error;
  AgentChatOperation? get lastOperation;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChatStateCopyWith<ChatState> get copyWith =>
      _$ChatStateCopyWithImpl<ChatState>(this as ChatState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChatState &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.conversation, conversation) ||
                other.conversation == conversation) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            (identical(other.lastOperation, lastOperation) ||
                other.lastOperation == lastOperation));
  }

  @override
  int get hashCode => Object.hash(runtimeType, chatId, conversation, status,
      const DeepCollectionEquality().hash(error), lastOperation);

  @override
  String toString() {
    return 'ChatState(chatId: $chatId, conversation: $conversation, status: $status, error: $error, lastOperation: $lastOperation)';
  }
}

/// @nodoc
abstract mixin class $ChatStateCopyWith<$Res> {
  factory $ChatStateCopyWith(ChatState value, $Res Function(ChatState) _then) =
      _$ChatStateCopyWithImpl;
  @useResult
  $Res call(
      {String? chatId,
      Conversation conversation,
      UiFlowStatus status,
      Object? error,
      AgentChatOperation? lastOperation});

  $ConversationCopyWith<$Res> get conversation;
}

/// @nodoc
class _$ChatStateCopyWithImpl<$Res> implements $ChatStateCopyWith<$Res> {
  _$ChatStateCopyWithImpl(this._self, this._then);

  final ChatState _self;
  final $Res Function(ChatState) _then;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chatId = freezed,
    Object? conversation = null,
    Object? status = null,
    Object? error = freezed,
    Object? lastOperation = freezed,
  }) {
    return _then(_self.copyWith(
      chatId: freezed == chatId
          ? _self.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      conversation: null == conversation
          ? _self.conversation
          : conversation // ignore: cast_nullable_to_non_nullable
              as Conversation,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
      lastOperation: freezed == lastOperation
          ? _self.lastOperation
          : lastOperation // ignore: cast_nullable_to_non_nullable
              as AgentChatOperation?,
    ));
  }

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ConversationCopyWith<$Res> get conversation {
    return $ConversationCopyWith<$Res>(_self.conversation, (value) {
      return _then(_self.copyWith(conversation: value));
    });
  }
}

/// Adds pattern-matching-related methods to [ChatState].
extension ChatStatePatterns on ChatState {
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
    TResult Function(_ChatState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatState() when $default != null:
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
    TResult Function(_ChatState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatState():
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
    TResult? Function(_ChatState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatState() when $default != null:
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
            Conversation conversation,
            UiFlowStatus status,
            Object? error,
            AgentChatOperation? lastOperation)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatState() when $default != null:
        return $default(_that.chatId, _that.conversation, _that.status,
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
            Conversation conversation,
            UiFlowStatus status,
            Object? error,
            AgentChatOperation? lastOperation)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatState():
        return $default(_that.chatId, _that.conversation, _that.status,
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
            Conversation conversation,
            UiFlowStatus status,
            Object? error,
            AgentChatOperation? lastOperation)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatState() when $default != null:
        return $default(_that.chatId, _that.conversation, _that.status,
            _that.error, _that.lastOperation);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ChatState extends ChatState {
  const _ChatState(
      {this.chatId,
      this.conversation = Conversation.empty,
      this.status = UiFlowStatus.idle,
      this.error,
      this.lastOperation})
      : super._();

  @override
  final String? chatId;
  @override
  @JsonKey()
  final Conversation conversation;
  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final Object? error;
  @override
  final AgentChatOperation? lastOperation;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChatStateCopyWith<_ChatState> get copyWith =>
      __$ChatStateCopyWithImpl<_ChatState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChatState &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.conversation, conversation) ||
                other.conversation == conversation) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            (identical(other.lastOperation, lastOperation) ||
                other.lastOperation == lastOperation));
  }

  @override
  int get hashCode => Object.hash(runtimeType, chatId, conversation, status,
      const DeepCollectionEquality().hash(error), lastOperation);

  @override
  String toString() {
    return 'ChatState(chatId: $chatId, conversation: $conversation, status: $status, error: $error, lastOperation: $lastOperation)';
  }
}

/// @nodoc
abstract mixin class _$ChatStateCopyWith<$Res>
    implements $ChatStateCopyWith<$Res> {
  factory _$ChatStateCopyWith(
          _ChatState value, $Res Function(_ChatState) _then) =
      __$ChatStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String? chatId,
      Conversation conversation,
      UiFlowStatus status,
      Object? error,
      AgentChatOperation? lastOperation});

  @override
  $ConversationCopyWith<$Res> get conversation;
}

/// @nodoc
class __$ChatStateCopyWithImpl<$Res> implements _$ChatStateCopyWith<$Res> {
  __$ChatStateCopyWithImpl(this._self, this._then);

  final _ChatState _self;
  final $Res Function(_ChatState) _then;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? chatId = freezed,
    Object? conversation = null,
    Object? status = null,
    Object? error = freezed,
    Object? lastOperation = freezed,
  }) {
    return _then(_ChatState(
      chatId: freezed == chatId
          ? _self.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String?,
      conversation: null == conversation
          ? _self.conversation
          : conversation // ignore: cast_nullable_to_non_nullable
              as Conversation,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
      lastOperation: freezed == lastOperation
          ? _self.lastOperation
          : lastOperation // ignore: cast_nullable_to_non_nullable
              as AgentChatOperation?,
    ));
  }

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ConversationCopyWith<$Res> get conversation {
    return $ConversationCopyWith<$Res>(_self.conversation, (value) {
      return _then(_self.copyWith(conversation: value));
    });
  }
}

// dart format on
