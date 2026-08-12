// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'permission.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Permission {
  String get id;
  String get aiEnginePermissionId;
  String get sessionId;
  String get permission;
  dynamic get patterns;
  dynamic get metadata;
  @JsonKey(unknownEnumValue: PermissionStatus.unknown)
  PermissionStatus get status;
  String? get message;
  String? get source;
  String? get messageId;
  String? get callId;
  String? get challenge;
  String? get chat;
  String? get approvedBy;
  DateTime? get approvedAt;
  DateTime? get created;
  DateTime? get updated;
  String? get acpRequestId;
  String? get acpSessionId;
  String? get toolName;
  dynamic get toolInput;
  String? get description;
  dynamic get permissionOptions;
  @JsonKey(unknownEnumValue: PermissionAcpStatus.unknown)
  PermissionAcpStatus? get acpStatus;
  String? get selectedOptionId;
  String? get acpMessageId;
  String? get toolCallId;

  /// Create a copy of Permission
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PermissionCopyWith<Permission> get copyWith =>
      _$PermissionCopyWithImpl<Permission>(this as Permission, _$identity);

  /// Serializes this Permission to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Permission &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.aiEnginePermissionId, aiEnginePermissionId) ||
                other.aiEnginePermissionId == aiEnginePermissionId) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.permission, permission) ||
                other.permission == permission) &&
            const DeepCollectionEquality().equals(other.patterns, patterns) &&
            const DeepCollectionEquality().equals(other.metadata, metadata) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.messageId, messageId) ||
                other.messageId == messageId) &&
            (identical(other.callId, callId) || other.callId == callId) &&
            (identical(other.challenge, challenge) ||
                other.challenge == challenge) &&
            (identical(other.chat, chat) || other.chat == chat) &&
            (identical(other.approvedBy, approvedBy) ||
                other.approvedBy == approvedBy) &&
            (identical(other.approvedAt, approvedAt) ||
                other.approvedAt == approvedAt) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.acpRequestId, acpRequestId) ||
                other.acpRequestId == acpRequestId) &&
            (identical(other.acpSessionId, acpSessionId) ||
                other.acpSessionId == acpSessionId) &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            const DeepCollectionEquality().equals(other.toolInput, toolInput) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality()
                .equals(other.permissionOptions, permissionOptions) &&
            (identical(other.acpStatus, acpStatus) ||
                other.acpStatus == acpStatus) &&
            (identical(other.selectedOptionId, selectedOptionId) ||
                other.selectedOptionId == selectedOptionId) &&
            (identical(other.acpMessageId, acpMessageId) ||
                other.acpMessageId == acpMessageId) &&
            (identical(other.toolCallId, toolCallId) ||
                other.toolCallId == toolCallId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        aiEnginePermissionId,
        sessionId,
        permission,
        const DeepCollectionEquality().hash(patterns),
        const DeepCollectionEquality().hash(metadata),
        status,
        message,
        source,
        messageId,
        callId,
        challenge,
        chat,
        approvedBy,
        approvedAt,
        created,
        updated,
        acpRequestId,
        acpSessionId,
        toolName,
        const DeepCollectionEquality().hash(toolInput),
        description,
        const DeepCollectionEquality().hash(permissionOptions),
        acpStatus,
        selectedOptionId,
        acpMessageId,
        toolCallId
      ]);

  @override
  String toString() {
    return 'Permission(id: $id, aiEnginePermissionId: $aiEnginePermissionId, sessionId: $sessionId, permission: $permission, patterns: $patterns, metadata: $metadata, status: $status, message: $message, source: $source, messageId: $messageId, callId: $callId, challenge: $challenge, chat: $chat, approvedBy: $approvedBy, approvedAt: $approvedAt, created: $created, updated: $updated, acpRequestId: $acpRequestId, acpSessionId: $acpSessionId, toolName: $toolName, toolInput: $toolInput, description: $description, permissionOptions: $permissionOptions, acpStatus: $acpStatus, selectedOptionId: $selectedOptionId, acpMessageId: $acpMessageId, toolCallId: $toolCallId)';
  }
}

/// @nodoc
abstract mixin class $PermissionCopyWith<$Res> {
  factory $PermissionCopyWith(
          Permission value, $Res Function(Permission) _then) =
      _$PermissionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String aiEnginePermissionId,
      String sessionId,
      String permission,
      dynamic patterns,
      dynamic metadata,
      @JsonKey(unknownEnumValue: PermissionStatus.unknown)
      PermissionStatus status,
      String? message,
      String? source,
      String? messageId,
      String? callId,
      String? challenge,
      String? chat,
      String? approvedBy,
      DateTime? approvedAt,
      DateTime? created,
      DateTime? updated,
      String? acpRequestId,
      String? acpSessionId,
      String? toolName,
      dynamic toolInput,
      String? description,
      dynamic permissionOptions,
      @JsonKey(unknownEnumValue: PermissionAcpStatus.unknown)
      PermissionAcpStatus? acpStatus,
      String? selectedOptionId,
      String? acpMessageId,
      String? toolCallId});
}

/// @nodoc
class _$PermissionCopyWithImpl<$Res> implements $PermissionCopyWith<$Res> {
  _$PermissionCopyWithImpl(this._self, this._then);

  final Permission _self;
  final $Res Function(Permission) _then;

  /// Create a copy of Permission
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? aiEnginePermissionId = null,
    Object? sessionId = null,
    Object? permission = null,
    Object? patterns = freezed,
    Object? metadata = freezed,
    Object? status = null,
    Object? message = freezed,
    Object? source = freezed,
    Object? messageId = freezed,
    Object? callId = freezed,
    Object? challenge = freezed,
    Object? chat = freezed,
    Object? approvedBy = freezed,
    Object? approvedAt = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? acpRequestId = freezed,
    Object? acpSessionId = freezed,
    Object? toolName = freezed,
    Object? toolInput = freezed,
    Object? description = freezed,
    Object? permissionOptions = freezed,
    Object? acpStatus = freezed,
    Object? selectedOptionId = freezed,
    Object? acpMessageId = freezed,
    Object? toolCallId = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      aiEnginePermissionId: null == aiEnginePermissionId
          ? _self.aiEnginePermissionId
          : aiEnginePermissionId // ignore: cast_nullable_to_non_nullable
              as String,
      sessionId: null == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      permission: null == permission
          ? _self.permission
          : permission // ignore: cast_nullable_to_non_nullable
              as String,
      patterns: freezed == patterns
          ? _self.patterns
          : patterns // ignore: cast_nullable_to_non_nullable
              as dynamic,
      metadata: freezed == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as dynamic,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as PermissionStatus,
      message: freezed == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      source: freezed == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String?,
      messageId: freezed == messageId
          ? _self.messageId
          : messageId // ignore: cast_nullable_to_non_nullable
              as String?,
      callId: freezed == callId
          ? _self.callId
          : callId // ignore: cast_nullable_to_non_nullable
              as String?,
      challenge: freezed == challenge
          ? _self.challenge
          : challenge // ignore: cast_nullable_to_non_nullable
              as String?,
      chat: freezed == chat
          ? _self.chat
          : chat // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedBy: freezed == approvedBy
          ? _self.approvedBy
          : approvedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedAt: freezed == approvedAt
          ? _self.approvedAt
          : approvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acpRequestId: freezed == acpRequestId
          ? _self.acpRequestId
          : acpRequestId // ignore: cast_nullable_to_non_nullable
              as String?,
      acpSessionId: freezed == acpSessionId
          ? _self.acpSessionId
          : acpSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      toolName: freezed == toolName
          ? _self.toolName
          : toolName // ignore: cast_nullable_to_non_nullable
              as String?,
      toolInput: freezed == toolInput
          ? _self.toolInput
          : toolInput // ignore: cast_nullable_to_non_nullable
              as dynamic,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      permissionOptions: freezed == permissionOptions
          ? _self.permissionOptions
          : permissionOptions // ignore: cast_nullable_to_non_nullable
              as dynamic,
      acpStatus: freezed == acpStatus
          ? _self.acpStatus
          : acpStatus // ignore: cast_nullable_to_non_nullable
              as PermissionAcpStatus?,
      selectedOptionId: freezed == selectedOptionId
          ? _self.selectedOptionId
          : selectedOptionId // ignore: cast_nullable_to_non_nullable
              as String?,
      acpMessageId: freezed == acpMessageId
          ? _self.acpMessageId
          : acpMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      toolCallId: freezed == toolCallId
          ? _self.toolCallId
          : toolCallId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Permission].
extension PermissionPatterns on Permission {
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
    TResult Function(_Permission value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Permission() when $default != null:
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
    TResult Function(_Permission value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Permission():
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
    TResult? Function(_Permission value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Permission() when $default != null:
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
            String aiEnginePermissionId,
            String sessionId,
            String permission,
            dynamic patterns,
            dynamic metadata,
            @JsonKey(unknownEnumValue: PermissionStatus.unknown)
            PermissionStatus status,
            String? message,
            String? source,
            String? messageId,
            String? callId,
            String? challenge,
            String? chat,
            String? approvedBy,
            DateTime? approvedAt,
            DateTime? created,
            DateTime? updated,
            String? acpRequestId,
            String? acpSessionId,
            String? toolName,
            dynamic toolInput,
            String? description,
            dynamic permissionOptions,
            @JsonKey(unknownEnumValue: PermissionAcpStatus.unknown)
            PermissionAcpStatus? acpStatus,
            String? selectedOptionId,
            String? acpMessageId,
            String? toolCallId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Permission() when $default != null:
        return $default(
            _that.id,
            _that.aiEnginePermissionId,
            _that.sessionId,
            _that.permission,
            _that.patterns,
            _that.metadata,
            _that.status,
            _that.message,
            _that.source,
            _that.messageId,
            _that.callId,
            _that.challenge,
            _that.chat,
            _that.approvedBy,
            _that.approvedAt,
            _that.created,
            _that.updated,
            _that.acpRequestId,
            _that.acpSessionId,
            _that.toolName,
            _that.toolInput,
            _that.description,
            _that.permissionOptions,
            _that.acpStatus,
            _that.selectedOptionId,
            _that.acpMessageId,
            _that.toolCallId);
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
            String aiEnginePermissionId,
            String sessionId,
            String permission,
            dynamic patterns,
            dynamic metadata,
            @JsonKey(unknownEnumValue: PermissionStatus.unknown)
            PermissionStatus status,
            String? message,
            String? source,
            String? messageId,
            String? callId,
            String? challenge,
            String? chat,
            String? approvedBy,
            DateTime? approvedAt,
            DateTime? created,
            DateTime? updated,
            String? acpRequestId,
            String? acpSessionId,
            String? toolName,
            dynamic toolInput,
            String? description,
            dynamic permissionOptions,
            @JsonKey(unknownEnumValue: PermissionAcpStatus.unknown)
            PermissionAcpStatus? acpStatus,
            String? selectedOptionId,
            String? acpMessageId,
            String? toolCallId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Permission():
        return $default(
            _that.id,
            _that.aiEnginePermissionId,
            _that.sessionId,
            _that.permission,
            _that.patterns,
            _that.metadata,
            _that.status,
            _that.message,
            _that.source,
            _that.messageId,
            _that.callId,
            _that.challenge,
            _that.chat,
            _that.approvedBy,
            _that.approvedAt,
            _that.created,
            _that.updated,
            _that.acpRequestId,
            _that.acpSessionId,
            _that.toolName,
            _that.toolInput,
            _that.description,
            _that.permissionOptions,
            _that.acpStatus,
            _that.selectedOptionId,
            _that.acpMessageId,
            _that.toolCallId);
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
            String aiEnginePermissionId,
            String sessionId,
            String permission,
            dynamic patterns,
            dynamic metadata,
            @JsonKey(unknownEnumValue: PermissionStatus.unknown)
            PermissionStatus status,
            String? message,
            String? source,
            String? messageId,
            String? callId,
            String? challenge,
            String? chat,
            String? approvedBy,
            DateTime? approvedAt,
            DateTime? created,
            DateTime? updated,
            String? acpRequestId,
            String? acpSessionId,
            String? toolName,
            dynamic toolInput,
            String? description,
            dynamic permissionOptions,
            @JsonKey(unknownEnumValue: PermissionAcpStatus.unknown)
            PermissionAcpStatus? acpStatus,
            String? selectedOptionId,
            String? acpMessageId,
            String? toolCallId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Permission() when $default != null:
        return $default(
            _that.id,
            _that.aiEnginePermissionId,
            _that.sessionId,
            _that.permission,
            _that.patterns,
            _that.metadata,
            _that.status,
            _that.message,
            _that.source,
            _that.messageId,
            _that.callId,
            _that.challenge,
            _that.chat,
            _that.approvedBy,
            _that.approvedAt,
            _that.created,
            _that.updated,
            _that.acpRequestId,
            _that.acpSessionId,
            _that.toolName,
            _that.toolInput,
            _that.description,
            _that.permissionOptions,
            _that.acpStatus,
            _that.selectedOptionId,
            _that.acpMessageId,
            _that.toolCallId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Permission implements Permission {
  const _Permission(
      {required this.id,
      required this.aiEnginePermissionId,
      required this.sessionId,
      required this.permission,
      this.patterns,
      this.metadata,
      @JsonKey(unknownEnumValue: PermissionStatus.unknown) required this.status,
      this.message,
      this.source,
      this.messageId,
      this.callId,
      this.challenge,
      this.chat,
      this.approvedBy,
      this.approvedAt,
      this.created,
      this.updated,
      this.acpRequestId,
      this.acpSessionId,
      this.toolName,
      this.toolInput,
      this.description,
      this.permissionOptions,
      @JsonKey(unknownEnumValue: PermissionAcpStatus.unknown) this.acpStatus,
      this.selectedOptionId,
      this.acpMessageId,
      this.toolCallId});
  factory _Permission.fromJson(Map<String, dynamic> json) =>
      _$PermissionFromJson(json);

  @override
  final String id;
  @override
  final String aiEnginePermissionId;
  @override
  final String sessionId;
  @override
  final String permission;
  @override
  final dynamic patterns;
  @override
  final dynamic metadata;
  @override
  @JsonKey(unknownEnumValue: PermissionStatus.unknown)
  final PermissionStatus status;
  @override
  final String? message;
  @override
  final String? source;
  @override
  final String? messageId;
  @override
  final String? callId;
  @override
  final String? challenge;
  @override
  final String? chat;
  @override
  final String? approvedBy;
  @override
  final DateTime? approvedAt;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;
  @override
  final String? acpRequestId;
  @override
  final String? acpSessionId;
  @override
  final String? toolName;
  @override
  final dynamic toolInput;
  @override
  final String? description;
  @override
  final dynamic permissionOptions;
  @override
  @JsonKey(unknownEnumValue: PermissionAcpStatus.unknown)
  final PermissionAcpStatus? acpStatus;
  @override
  final String? selectedOptionId;
  @override
  final String? acpMessageId;
  @override
  final String? toolCallId;

  /// Create a copy of Permission
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PermissionCopyWith<_Permission> get copyWith =>
      __$PermissionCopyWithImpl<_Permission>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PermissionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Permission &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.aiEnginePermissionId, aiEnginePermissionId) ||
                other.aiEnginePermissionId == aiEnginePermissionId) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.permission, permission) ||
                other.permission == permission) &&
            const DeepCollectionEquality().equals(other.patterns, patterns) &&
            const DeepCollectionEquality().equals(other.metadata, metadata) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.messageId, messageId) ||
                other.messageId == messageId) &&
            (identical(other.callId, callId) || other.callId == callId) &&
            (identical(other.challenge, challenge) ||
                other.challenge == challenge) &&
            (identical(other.chat, chat) || other.chat == chat) &&
            (identical(other.approvedBy, approvedBy) ||
                other.approvedBy == approvedBy) &&
            (identical(other.approvedAt, approvedAt) ||
                other.approvedAt == approvedAt) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.acpRequestId, acpRequestId) ||
                other.acpRequestId == acpRequestId) &&
            (identical(other.acpSessionId, acpSessionId) ||
                other.acpSessionId == acpSessionId) &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            const DeepCollectionEquality().equals(other.toolInput, toolInput) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality()
                .equals(other.permissionOptions, permissionOptions) &&
            (identical(other.acpStatus, acpStatus) ||
                other.acpStatus == acpStatus) &&
            (identical(other.selectedOptionId, selectedOptionId) ||
                other.selectedOptionId == selectedOptionId) &&
            (identical(other.acpMessageId, acpMessageId) ||
                other.acpMessageId == acpMessageId) &&
            (identical(other.toolCallId, toolCallId) ||
                other.toolCallId == toolCallId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        aiEnginePermissionId,
        sessionId,
        permission,
        const DeepCollectionEquality().hash(patterns),
        const DeepCollectionEquality().hash(metadata),
        status,
        message,
        source,
        messageId,
        callId,
        challenge,
        chat,
        approvedBy,
        approvedAt,
        created,
        updated,
        acpRequestId,
        acpSessionId,
        toolName,
        const DeepCollectionEquality().hash(toolInput),
        description,
        const DeepCollectionEquality().hash(permissionOptions),
        acpStatus,
        selectedOptionId,
        acpMessageId,
        toolCallId
      ]);

  @override
  String toString() {
    return 'Permission(id: $id, aiEnginePermissionId: $aiEnginePermissionId, sessionId: $sessionId, permission: $permission, patterns: $patterns, metadata: $metadata, status: $status, message: $message, source: $source, messageId: $messageId, callId: $callId, challenge: $challenge, chat: $chat, approvedBy: $approvedBy, approvedAt: $approvedAt, created: $created, updated: $updated, acpRequestId: $acpRequestId, acpSessionId: $acpSessionId, toolName: $toolName, toolInput: $toolInput, description: $description, permissionOptions: $permissionOptions, acpStatus: $acpStatus, selectedOptionId: $selectedOptionId, acpMessageId: $acpMessageId, toolCallId: $toolCallId)';
  }
}

/// @nodoc
abstract mixin class _$PermissionCopyWith<$Res>
    implements $PermissionCopyWith<$Res> {
  factory _$PermissionCopyWith(
          _Permission value, $Res Function(_Permission) _then) =
      __$PermissionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String aiEnginePermissionId,
      String sessionId,
      String permission,
      dynamic patterns,
      dynamic metadata,
      @JsonKey(unknownEnumValue: PermissionStatus.unknown)
      PermissionStatus status,
      String? message,
      String? source,
      String? messageId,
      String? callId,
      String? challenge,
      String? chat,
      String? approvedBy,
      DateTime? approvedAt,
      DateTime? created,
      DateTime? updated,
      String? acpRequestId,
      String? acpSessionId,
      String? toolName,
      dynamic toolInput,
      String? description,
      dynamic permissionOptions,
      @JsonKey(unknownEnumValue: PermissionAcpStatus.unknown)
      PermissionAcpStatus? acpStatus,
      String? selectedOptionId,
      String? acpMessageId,
      String? toolCallId});
}

/// @nodoc
class __$PermissionCopyWithImpl<$Res> implements _$PermissionCopyWith<$Res> {
  __$PermissionCopyWithImpl(this._self, this._then);

  final _Permission _self;
  final $Res Function(_Permission) _then;

  /// Create a copy of Permission
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? aiEnginePermissionId = null,
    Object? sessionId = null,
    Object? permission = null,
    Object? patterns = freezed,
    Object? metadata = freezed,
    Object? status = null,
    Object? message = freezed,
    Object? source = freezed,
    Object? messageId = freezed,
    Object? callId = freezed,
    Object? challenge = freezed,
    Object? chat = freezed,
    Object? approvedBy = freezed,
    Object? approvedAt = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? acpRequestId = freezed,
    Object? acpSessionId = freezed,
    Object? toolName = freezed,
    Object? toolInput = freezed,
    Object? description = freezed,
    Object? permissionOptions = freezed,
    Object? acpStatus = freezed,
    Object? selectedOptionId = freezed,
    Object? acpMessageId = freezed,
    Object? toolCallId = freezed,
  }) {
    return _then(_Permission(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      aiEnginePermissionId: null == aiEnginePermissionId
          ? _self.aiEnginePermissionId
          : aiEnginePermissionId // ignore: cast_nullable_to_non_nullable
              as String,
      sessionId: null == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      permission: null == permission
          ? _self.permission
          : permission // ignore: cast_nullable_to_non_nullable
              as String,
      patterns: freezed == patterns
          ? _self.patterns
          : patterns // ignore: cast_nullable_to_non_nullable
              as dynamic,
      metadata: freezed == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as dynamic,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as PermissionStatus,
      message: freezed == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      source: freezed == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String?,
      messageId: freezed == messageId
          ? _self.messageId
          : messageId // ignore: cast_nullable_to_non_nullable
              as String?,
      callId: freezed == callId
          ? _self.callId
          : callId // ignore: cast_nullable_to_non_nullable
              as String?,
      challenge: freezed == challenge
          ? _self.challenge
          : challenge // ignore: cast_nullable_to_non_nullable
              as String?,
      chat: freezed == chat
          ? _self.chat
          : chat // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedBy: freezed == approvedBy
          ? _self.approvedBy
          : approvedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      approvedAt: freezed == approvedAt
          ? _self.approvedAt
          : approvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acpRequestId: freezed == acpRequestId
          ? _self.acpRequestId
          : acpRequestId // ignore: cast_nullable_to_non_nullable
              as String?,
      acpSessionId: freezed == acpSessionId
          ? _self.acpSessionId
          : acpSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      toolName: freezed == toolName
          ? _self.toolName
          : toolName // ignore: cast_nullable_to_non_nullable
              as String?,
      toolInput: freezed == toolInput
          ? _self.toolInput
          : toolInput // ignore: cast_nullable_to_non_nullable
              as dynamic,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      permissionOptions: freezed == permissionOptions
          ? _self.permissionOptions
          : permissionOptions // ignore: cast_nullable_to_non_nullable
              as dynamic,
      acpStatus: freezed == acpStatus
          ? _self.acpStatus
          : acpStatus // ignore: cast_nullable_to_non_nullable
              as PermissionAcpStatus?,
      selectedOptionId: freezed == selectedOptionId
          ? _self.selectedOptionId
          : selectedOptionId // ignore: cast_nullable_to_non_nullable
              as String?,
      acpMessageId: freezed == acpMessageId
          ? _self.acpMessageId
          : acpMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      toolCallId: freezed == toolCallId
          ? _self.toolCallId
          : toolCallId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
