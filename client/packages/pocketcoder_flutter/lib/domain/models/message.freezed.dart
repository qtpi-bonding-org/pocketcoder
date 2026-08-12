// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Message {
  String get id;
  String get chat;
  @JsonKey(unknownEnumValue: MessageRole.unknown)
  MessageRole get role;
  @JsonKey(unknownEnumValue: MessageEngineMessageStatus.unknown)
  MessageEngineMessageStatus? get engineMessageStatus;
  @JsonKey(unknownEnumValue: MessageUserMessageStatus.unknown)
  MessageUserMessageStatus? get userMessageStatus;
  String? get aiEngineMessageId;
  String? get parentId;
  dynamic get parts;
  @JsonKey(unknownEnumValue: MessageErrorDomain.unknown)
  MessageErrorDomain? get errorDomain;
  dynamic get errorPayload;
  DateTime? get created;
  DateTime? get updated;
  dynamic get content;
  @JsonKey(unknownEnumValue: MessageAcpStatus.unknown)
  MessageAcpStatus? get acpStatus;
  dynamic get usage;
  dynamic get cost;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessageCopyWith<Message> get copyWith =>
      _$MessageCopyWithImpl<Message>(this as Message, _$identity);

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Message &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.chat, chat) || other.chat == chat) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.engineMessageStatus, engineMessageStatus) ||
                other.engineMessageStatus == engineMessageStatus) &&
            (identical(other.userMessageStatus, userMessageStatus) ||
                other.userMessageStatus == userMessageStatus) &&
            (identical(other.aiEngineMessageId, aiEngineMessageId) ||
                other.aiEngineMessageId == aiEngineMessageId) &&
            (identical(other.parentId, parentId) ||
                other.parentId == parentId) &&
            const DeepCollectionEquality().equals(other.parts, parts) &&
            (identical(other.errorDomain, errorDomain) ||
                other.errorDomain == errorDomain) &&
            const DeepCollectionEquality()
                .equals(other.errorPayload, errorPayload) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            const DeepCollectionEquality().equals(other.content, content) &&
            (identical(other.acpStatus, acpStatus) ||
                other.acpStatus == acpStatus) &&
            const DeepCollectionEquality().equals(other.usage, usage) &&
            const DeepCollectionEquality().equals(other.cost, cost));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      chat,
      role,
      engineMessageStatus,
      userMessageStatus,
      aiEngineMessageId,
      parentId,
      const DeepCollectionEquality().hash(parts),
      errorDomain,
      const DeepCollectionEquality().hash(errorPayload),
      created,
      updated,
      const DeepCollectionEquality().hash(content),
      acpStatus,
      const DeepCollectionEquality().hash(usage),
      const DeepCollectionEquality().hash(cost));

  @override
  String toString() {
    return 'Message(id: $id, chat: $chat, role: $role, engineMessageStatus: $engineMessageStatus, userMessageStatus: $userMessageStatus, aiEngineMessageId: $aiEngineMessageId, parentId: $parentId, parts: $parts, errorDomain: $errorDomain, errorPayload: $errorPayload, created: $created, updated: $updated, content: $content, acpStatus: $acpStatus, usage: $usage, cost: $cost)';
  }
}

/// @nodoc
abstract mixin class $MessageCopyWith<$Res> {
  factory $MessageCopyWith(Message value, $Res Function(Message) _then) =
      _$MessageCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String chat,
      @JsonKey(unknownEnumValue: MessageRole.unknown) MessageRole role,
      @JsonKey(unknownEnumValue: MessageEngineMessageStatus.unknown)
      MessageEngineMessageStatus? engineMessageStatus,
      @JsonKey(unknownEnumValue: MessageUserMessageStatus.unknown)
      MessageUserMessageStatus? userMessageStatus,
      String? aiEngineMessageId,
      String? parentId,
      dynamic parts,
      @JsonKey(unknownEnumValue: MessageErrorDomain.unknown)
      MessageErrorDomain? errorDomain,
      dynamic errorPayload,
      DateTime? created,
      DateTime? updated,
      dynamic content,
      @JsonKey(unknownEnumValue: MessageAcpStatus.unknown)
      MessageAcpStatus? acpStatus,
      dynamic usage,
      dynamic cost});
}

/// @nodoc
class _$MessageCopyWithImpl<$Res> implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._self, this._then);

  final Message _self;
  final $Res Function(Message) _then;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? chat = null,
    Object? role = null,
    Object? engineMessageStatus = freezed,
    Object? userMessageStatus = freezed,
    Object? aiEngineMessageId = freezed,
    Object? parentId = freezed,
    Object? parts = freezed,
    Object? errorDomain = freezed,
    Object? errorPayload = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? content = freezed,
    Object? acpStatus = freezed,
    Object? usage = freezed,
    Object? cost = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      chat: null == chat
          ? _self.chat
          : chat // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as MessageRole,
      engineMessageStatus: freezed == engineMessageStatus
          ? _self.engineMessageStatus
          : engineMessageStatus // ignore: cast_nullable_to_non_nullable
              as MessageEngineMessageStatus?,
      userMessageStatus: freezed == userMessageStatus
          ? _self.userMessageStatus
          : userMessageStatus // ignore: cast_nullable_to_non_nullable
              as MessageUserMessageStatus?,
      aiEngineMessageId: freezed == aiEngineMessageId
          ? _self.aiEngineMessageId
          : aiEngineMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      parentId: freezed == parentId
          ? _self.parentId
          : parentId // ignore: cast_nullable_to_non_nullable
              as String?,
      parts: freezed == parts
          ? _self.parts
          : parts // ignore: cast_nullable_to_non_nullable
              as dynamic,
      errorDomain: freezed == errorDomain
          ? _self.errorDomain
          : errorDomain // ignore: cast_nullable_to_non_nullable
              as MessageErrorDomain?,
      errorPayload: freezed == errorPayload
          ? _self.errorPayload
          : errorPayload // ignore: cast_nullable_to_non_nullable
              as dynamic,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      content: freezed == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as dynamic,
      acpStatus: freezed == acpStatus
          ? _self.acpStatus
          : acpStatus // ignore: cast_nullable_to_non_nullable
              as MessageAcpStatus?,
      usage: freezed == usage
          ? _self.usage
          : usage // ignore: cast_nullable_to_non_nullable
              as dynamic,
      cost: freezed == cost
          ? _self.cost
          : cost // ignore: cast_nullable_to_non_nullable
              as dynamic,
    ));
  }
}

/// Adds pattern-matching-related methods to [Message].
extension MessagePatterns on Message {
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
    TResult Function(_Message value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Message() when $default != null:
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
    TResult Function(_Message value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Message():
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
    TResult? Function(_Message value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Message() when $default != null:
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
            String id,
            String chat,
            @JsonKey(unknownEnumValue: MessageRole.unknown) MessageRole role,
            @JsonKey(unknownEnumValue: MessageEngineMessageStatus.unknown)
            MessageEngineMessageStatus? engineMessageStatus,
            @JsonKey(unknownEnumValue: MessageUserMessageStatus.unknown)
            MessageUserMessageStatus? userMessageStatus,
            String? aiEngineMessageId,
            String? parentId,
            dynamic parts,
            @JsonKey(unknownEnumValue: MessageErrorDomain.unknown)
            MessageErrorDomain? errorDomain,
            dynamic errorPayload,
            DateTime? created,
            DateTime? updated,
            dynamic content,
            @JsonKey(unknownEnumValue: MessageAcpStatus.unknown)
            MessageAcpStatus? acpStatus,
            dynamic usage,
            dynamic cost)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Message() when $default != null:
        return $default(
            _that.id,
            _that.chat,
            _that.role,
            _that.engineMessageStatus,
            _that.userMessageStatus,
            _that.aiEngineMessageId,
            _that.parentId,
            _that.parts,
            _that.errorDomain,
            _that.errorPayload,
            _that.created,
            _that.updated,
            _that.content,
            _that.acpStatus,
            _that.usage,
            _that.cost);
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
            String id,
            String chat,
            @JsonKey(unknownEnumValue: MessageRole.unknown) MessageRole role,
            @JsonKey(unknownEnumValue: MessageEngineMessageStatus.unknown)
            MessageEngineMessageStatus? engineMessageStatus,
            @JsonKey(unknownEnumValue: MessageUserMessageStatus.unknown)
            MessageUserMessageStatus? userMessageStatus,
            String? aiEngineMessageId,
            String? parentId,
            dynamic parts,
            @JsonKey(unknownEnumValue: MessageErrorDomain.unknown)
            MessageErrorDomain? errorDomain,
            dynamic errorPayload,
            DateTime? created,
            DateTime? updated,
            dynamic content,
            @JsonKey(unknownEnumValue: MessageAcpStatus.unknown)
            MessageAcpStatus? acpStatus,
            dynamic usage,
            dynamic cost)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Message():
        return $default(
            _that.id,
            _that.chat,
            _that.role,
            _that.engineMessageStatus,
            _that.userMessageStatus,
            _that.aiEngineMessageId,
            _that.parentId,
            _that.parts,
            _that.errorDomain,
            _that.errorPayload,
            _that.created,
            _that.updated,
            _that.content,
            _that.acpStatus,
            _that.usage,
            _that.cost);
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
            String id,
            String chat,
            @JsonKey(unknownEnumValue: MessageRole.unknown) MessageRole role,
            @JsonKey(unknownEnumValue: MessageEngineMessageStatus.unknown)
            MessageEngineMessageStatus? engineMessageStatus,
            @JsonKey(unknownEnumValue: MessageUserMessageStatus.unknown)
            MessageUserMessageStatus? userMessageStatus,
            String? aiEngineMessageId,
            String? parentId,
            dynamic parts,
            @JsonKey(unknownEnumValue: MessageErrorDomain.unknown)
            MessageErrorDomain? errorDomain,
            dynamic errorPayload,
            DateTime? created,
            DateTime? updated,
            dynamic content,
            @JsonKey(unknownEnumValue: MessageAcpStatus.unknown)
            MessageAcpStatus? acpStatus,
            dynamic usage,
            dynamic cost)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Message() when $default != null:
        return $default(
            _that.id,
            _that.chat,
            _that.role,
            _that.engineMessageStatus,
            _that.userMessageStatus,
            _that.aiEngineMessageId,
            _that.parentId,
            _that.parts,
            _that.errorDomain,
            _that.errorPayload,
            _that.created,
            _that.updated,
            _that.content,
            _that.acpStatus,
            _that.usage,
            _that.cost);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Message implements Message {
  const _Message(
      {required this.id,
      required this.chat,
      @JsonKey(unknownEnumValue: MessageRole.unknown) required this.role,
      @JsonKey(unknownEnumValue: MessageEngineMessageStatus.unknown)
      this.engineMessageStatus,
      @JsonKey(unknownEnumValue: MessageUserMessageStatus.unknown)
      this.userMessageStatus,
      this.aiEngineMessageId,
      this.parentId,
      this.parts,
      @JsonKey(unknownEnumValue: MessageErrorDomain.unknown) this.errorDomain,
      this.errorPayload,
      this.created,
      this.updated,
      this.content,
      @JsonKey(unknownEnumValue: MessageAcpStatus.unknown) this.acpStatus,
      this.usage,
      this.cost});
  factory _Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  @override
  final String id;
  @override
  final String chat;
  @override
  @JsonKey(unknownEnumValue: MessageRole.unknown)
  final MessageRole role;
  @override
  @JsonKey(unknownEnumValue: MessageEngineMessageStatus.unknown)
  final MessageEngineMessageStatus? engineMessageStatus;
  @override
  @JsonKey(unknownEnumValue: MessageUserMessageStatus.unknown)
  final MessageUserMessageStatus? userMessageStatus;
  @override
  final String? aiEngineMessageId;
  @override
  final String? parentId;
  @override
  final dynamic parts;
  @override
  @JsonKey(unknownEnumValue: MessageErrorDomain.unknown)
  final MessageErrorDomain? errorDomain;
  @override
  final dynamic errorPayload;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;
  @override
  final dynamic content;
  @override
  @JsonKey(unknownEnumValue: MessageAcpStatus.unknown)
  final MessageAcpStatus? acpStatus;
  @override
  final dynamic usage;
  @override
  final dynamic cost;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MessageCopyWith<_Message> get copyWith =>
      __$MessageCopyWithImpl<_Message>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MessageToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Message &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.chat, chat) || other.chat == chat) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.engineMessageStatus, engineMessageStatus) ||
                other.engineMessageStatus == engineMessageStatus) &&
            (identical(other.userMessageStatus, userMessageStatus) ||
                other.userMessageStatus == userMessageStatus) &&
            (identical(other.aiEngineMessageId, aiEngineMessageId) ||
                other.aiEngineMessageId == aiEngineMessageId) &&
            (identical(other.parentId, parentId) ||
                other.parentId == parentId) &&
            const DeepCollectionEquality().equals(other.parts, parts) &&
            (identical(other.errorDomain, errorDomain) ||
                other.errorDomain == errorDomain) &&
            const DeepCollectionEquality()
                .equals(other.errorPayload, errorPayload) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            const DeepCollectionEquality().equals(other.content, content) &&
            (identical(other.acpStatus, acpStatus) ||
                other.acpStatus == acpStatus) &&
            const DeepCollectionEquality().equals(other.usage, usage) &&
            const DeepCollectionEquality().equals(other.cost, cost));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      chat,
      role,
      engineMessageStatus,
      userMessageStatus,
      aiEngineMessageId,
      parentId,
      const DeepCollectionEquality().hash(parts),
      errorDomain,
      const DeepCollectionEquality().hash(errorPayload),
      created,
      updated,
      const DeepCollectionEquality().hash(content),
      acpStatus,
      const DeepCollectionEquality().hash(usage),
      const DeepCollectionEquality().hash(cost));

  @override
  String toString() {
    return 'Message(id: $id, chat: $chat, role: $role, engineMessageStatus: $engineMessageStatus, userMessageStatus: $userMessageStatus, aiEngineMessageId: $aiEngineMessageId, parentId: $parentId, parts: $parts, errorDomain: $errorDomain, errorPayload: $errorPayload, created: $created, updated: $updated, content: $content, acpStatus: $acpStatus, usage: $usage, cost: $cost)';
  }
}

/// @nodoc
abstract mixin class _$MessageCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$MessageCopyWith(_Message value, $Res Function(_Message) _then) =
      __$MessageCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String chat,
      @JsonKey(unknownEnumValue: MessageRole.unknown) MessageRole role,
      @JsonKey(unknownEnumValue: MessageEngineMessageStatus.unknown)
      MessageEngineMessageStatus? engineMessageStatus,
      @JsonKey(unknownEnumValue: MessageUserMessageStatus.unknown)
      MessageUserMessageStatus? userMessageStatus,
      String? aiEngineMessageId,
      String? parentId,
      dynamic parts,
      @JsonKey(unknownEnumValue: MessageErrorDomain.unknown)
      MessageErrorDomain? errorDomain,
      dynamic errorPayload,
      DateTime? created,
      DateTime? updated,
      dynamic content,
      @JsonKey(unknownEnumValue: MessageAcpStatus.unknown)
      MessageAcpStatus? acpStatus,
      dynamic usage,
      dynamic cost});
}

/// @nodoc
class __$MessageCopyWithImpl<$Res> implements _$MessageCopyWith<$Res> {
  __$MessageCopyWithImpl(this._self, this._then);

  final _Message _self;
  final $Res Function(_Message) _then;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? chat = null,
    Object? role = null,
    Object? engineMessageStatus = freezed,
    Object? userMessageStatus = freezed,
    Object? aiEngineMessageId = freezed,
    Object? parentId = freezed,
    Object? parts = freezed,
    Object? errorDomain = freezed,
    Object? errorPayload = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? content = freezed,
    Object? acpStatus = freezed,
    Object? usage = freezed,
    Object? cost = freezed,
  }) {
    return _then(_Message(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      chat: null == chat
          ? _self.chat
          : chat // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as MessageRole,
      engineMessageStatus: freezed == engineMessageStatus
          ? _self.engineMessageStatus
          : engineMessageStatus // ignore: cast_nullable_to_non_nullable
              as MessageEngineMessageStatus?,
      userMessageStatus: freezed == userMessageStatus
          ? _self.userMessageStatus
          : userMessageStatus // ignore: cast_nullable_to_non_nullable
              as MessageUserMessageStatus?,
      aiEngineMessageId: freezed == aiEngineMessageId
          ? _self.aiEngineMessageId
          : aiEngineMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      parentId: freezed == parentId
          ? _self.parentId
          : parentId // ignore: cast_nullable_to_non_nullable
              as String?,
      parts: freezed == parts
          ? _self.parts
          : parts // ignore: cast_nullable_to_non_nullable
              as dynamic,
      errorDomain: freezed == errorDomain
          ? _self.errorDomain
          : errorDomain // ignore: cast_nullable_to_non_nullable
              as MessageErrorDomain?,
      errorPayload: freezed == errorPayload
          ? _self.errorPayload
          : errorPayload // ignore: cast_nullable_to_non_nullable
              as dynamic,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      content: freezed == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as dynamic,
      acpStatus: freezed == acpStatus
          ? _self.acpStatus
          : acpStatus // ignore: cast_nullable_to_non_nullable
              as MessageAcpStatus?,
      usage: freezed == usage
          ? _self.usage
          : usage // ignore: cast_nullable_to_non_nullable
              as dynamic,
      cost: freezed == cost
          ? _self.cost
          : cost // ignore: cast_nullable_to_non_nullable
              as dynamic,
    ));
  }
}

// dart format on
