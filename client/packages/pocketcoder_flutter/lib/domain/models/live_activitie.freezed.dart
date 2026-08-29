// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_activitie.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveActivitie {
  String get id;
  String get device;
  String get chat;
  String get user;
  @JsonKey(unknownEnumValue: LiveActivitiePlatform.unknown)
  LiveActivitiePlatform get platform;
  @JsonKey(unknownEnumValue: LiveActivitieStatus.unknown)
  LiveActivitieStatus get status;
  String? get activityPushToken;
  double get contentStateVersion;
  DateTime? get created;
  DateTime? get updated;
  DateTime? get expiresAt;
  DateTime? get lastPushAt;
  DateTime? get endedAt;
  String? get lastError;

  /// Create a copy of LiveActivitie
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LiveActivitieCopyWith<LiveActivitie> get copyWith =>
      _$LiveActivitieCopyWithImpl<LiveActivitie>(
          this as LiveActivitie, _$identity);

  /// Serializes this LiveActivitie to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LiveActivitie &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.device, device) || other.device == device) &&
            (identical(other.chat, chat) || other.chat == chat) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.activityPushToken, activityPushToken) ||
                other.activityPushToken == activityPushToken) &&
            (identical(other.contentStateVersion, contentStateVersion) ||
                other.contentStateVersion == contentStateVersion) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.lastPushAt, lastPushAt) ||
                other.lastPushAt == lastPushAt) &&
            (identical(other.endedAt, endedAt) || other.endedAt == endedAt) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      device,
      chat,
      user,
      platform,
      status,
      activityPushToken,
      contentStateVersion,
      created,
      updated,
      expiresAt,
      lastPushAt,
      endedAt,
      lastError);

  @override
  String toString() {
    return 'LiveActivitie(id: $id, device: $device, chat: $chat, user: $user, platform: $platform, status: $status, activityPushToken: $activityPushToken, contentStateVersion: $contentStateVersion, created: $created, updated: $updated, expiresAt: $expiresAt, lastPushAt: $lastPushAt, endedAt: $endedAt, lastError: $lastError)';
  }
}

/// @nodoc
abstract mixin class $LiveActivitieCopyWith<$Res> {
  factory $LiveActivitieCopyWith(
          LiveActivitie value, $Res Function(LiveActivitie) _then) =
      _$LiveActivitieCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String device,
      String chat,
      String user,
      @JsonKey(unknownEnumValue: LiveActivitiePlatform.unknown)
      LiveActivitiePlatform platform,
      @JsonKey(unknownEnumValue: LiveActivitieStatus.unknown)
      LiveActivitieStatus status,
      String? activityPushToken,
      double contentStateVersion,
      DateTime? created,
      DateTime? updated,
      DateTime? expiresAt,
      DateTime? lastPushAt,
      DateTime? endedAt,
      String? lastError});
}

/// @nodoc
class _$LiveActivitieCopyWithImpl<$Res>
    implements $LiveActivitieCopyWith<$Res> {
  _$LiveActivitieCopyWithImpl(this._self, this._then);

  final LiveActivitie _self;
  final $Res Function(LiveActivitie) _then;

  /// Create a copy of LiveActivitie
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? device = null,
    Object? chat = null,
    Object? user = null,
    Object? platform = null,
    Object? status = null,
    Object? activityPushToken = freezed,
    Object? contentStateVersion = null,
    Object? created = freezed,
    Object? updated = freezed,
    Object? expiresAt = freezed,
    Object? lastPushAt = freezed,
    Object? endedAt = freezed,
    Object? lastError = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      device: null == device
          ? _self.device
          : device // ignore: cast_nullable_to_non_nullable
              as String,
      chat: null == chat
          ? _self.chat
          : chat // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      platform: null == platform
          ? _self.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as LiveActivitiePlatform,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LiveActivitieStatus,
      activityPushToken: freezed == activityPushToken
          ? _self.activityPushToken
          : activityPushToken // ignore: cast_nullable_to_non_nullable
              as String?,
      contentStateVersion: null == contentStateVersion
          ? _self.contentStateVersion
          : contentStateVersion // ignore: cast_nullable_to_non_nullable
              as double,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      expiresAt: freezed == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastPushAt: freezed == lastPushAt
          ? _self.lastPushAt
          : lastPushAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endedAt: freezed == endedAt
          ? _self.endedAt
          : endedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [LiveActivitie].
extension LiveActivitiePatterns on LiveActivitie {
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
    TResult Function(_LiveActivitie value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LiveActivitie() when $default != null:
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
    TResult Function(_LiveActivitie value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LiveActivitie():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
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
    TResult? Function(_LiveActivitie value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LiveActivitie() when $default != null:
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
            String device,
            String chat,
            String user,
            @JsonKey(unknownEnumValue: LiveActivitiePlatform.unknown)
            LiveActivitiePlatform platform,
            @JsonKey(unknownEnumValue: LiveActivitieStatus.unknown)
            LiveActivitieStatus status,
            String? activityPushToken,
            double contentStateVersion,
            DateTime? created,
            DateTime? updated,
            DateTime? expiresAt,
            DateTime? lastPushAt,
            DateTime? endedAt,
            String? lastError)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LiveActivitie() when $default != null:
        return $default(
            _that.id,
            _that.device,
            _that.chat,
            _that.user,
            _that.platform,
            _that.status,
            _that.activityPushToken,
            _that.contentStateVersion,
            _that.created,
            _that.updated,
            _that.expiresAt,
            _that.lastPushAt,
            _that.endedAt,
            _that.lastError);
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
            String device,
            String chat,
            String user,
            @JsonKey(unknownEnumValue: LiveActivitiePlatform.unknown)
            LiveActivitiePlatform platform,
            @JsonKey(unknownEnumValue: LiveActivitieStatus.unknown)
            LiveActivitieStatus status,
            String? activityPushToken,
            double contentStateVersion,
            DateTime? created,
            DateTime? updated,
            DateTime? expiresAt,
            DateTime? lastPushAt,
            DateTime? endedAt,
            String? lastError)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LiveActivitie():
        return $default(
            _that.id,
            _that.device,
            _that.chat,
            _that.user,
            _that.platform,
            _that.status,
            _that.activityPushToken,
            _that.contentStateVersion,
            _that.created,
            _that.updated,
            _that.expiresAt,
            _that.lastPushAt,
            _that.endedAt,
            _that.lastError);
      case _:
        throw StateError('Unexpected subclass');
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
            String device,
            String chat,
            String user,
            @JsonKey(unknownEnumValue: LiveActivitiePlatform.unknown)
            LiveActivitiePlatform platform,
            @JsonKey(unknownEnumValue: LiveActivitieStatus.unknown)
            LiveActivitieStatus status,
            String? activityPushToken,
            double contentStateVersion,
            DateTime? created,
            DateTime? updated,
            DateTime? expiresAt,
            DateTime? lastPushAt,
            DateTime? endedAt,
            String? lastError)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LiveActivitie() when $default != null:
        return $default(
            _that.id,
            _that.device,
            _that.chat,
            _that.user,
            _that.platform,
            _that.status,
            _that.activityPushToken,
            _that.contentStateVersion,
            _that.created,
            _that.updated,
            _that.expiresAt,
            _that.lastPushAt,
            _that.endedAt,
            _that.lastError);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _LiveActivitie implements LiveActivitie {
  const _LiveActivitie(
      {required this.id,
      required this.device,
      required this.chat,
      required this.user,
      @JsonKey(unknownEnumValue: LiveActivitiePlatform.unknown)
      required this.platform,
      @JsonKey(unknownEnumValue: LiveActivitieStatus.unknown)
      required this.status,
      this.activityPushToken,
      required this.contentStateVersion,
      this.created,
      this.updated,
      this.expiresAt,
      this.lastPushAt,
      this.endedAt,
      this.lastError});
  factory _LiveActivitie.fromJson(Map<String, dynamic> json) =>
      _$LiveActivitieFromJson(json);

  @override
  final String id;
  @override
  final String device;
  @override
  final String chat;
  @override
  final String user;
  @override
  @JsonKey(unknownEnumValue: LiveActivitiePlatform.unknown)
  final LiveActivitiePlatform platform;
  @override
  @JsonKey(unknownEnumValue: LiveActivitieStatus.unknown)
  final LiveActivitieStatus status;
  @override
  final String? activityPushToken;
  @override
  final double contentStateVersion;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;
  @override
  final DateTime? expiresAt;
  @override
  final DateTime? lastPushAt;
  @override
  final DateTime? endedAt;
  @override
  final String? lastError;

  /// Create a copy of LiveActivitie
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LiveActivitieCopyWith<_LiveActivitie> get copyWith =>
      __$LiveActivitieCopyWithImpl<_LiveActivitie>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$LiveActivitieToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LiveActivitie &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.device, device) || other.device == device) &&
            (identical(other.chat, chat) || other.chat == chat) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.activityPushToken, activityPushToken) ||
                other.activityPushToken == activityPushToken) &&
            (identical(other.contentStateVersion, contentStateVersion) ||
                other.contentStateVersion == contentStateVersion) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.lastPushAt, lastPushAt) ||
                other.lastPushAt == lastPushAt) &&
            (identical(other.endedAt, endedAt) || other.endedAt == endedAt) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      device,
      chat,
      user,
      platform,
      status,
      activityPushToken,
      contentStateVersion,
      created,
      updated,
      expiresAt,
      lastPushAt,
      endedAt,
      lastError);

  @override
  String toString() {
    return 'LiveActivitie(id: $id, device: $device, chat: $chat, user: $user, platform: $platform, status: $status, activityPushToken: $activityPushToken, contentStateVersion: $contentStateVersion, created: $created, updated: $updated, expiresAt: $expiresAt, lastPushAt: $lastPushAt, endedAt: $endedAt, lastError: $lastError)';
  }
}

/// @nodoc
abstract mixin class _$LiveActivitieCopyWith<$Res>
    implements $LiveActivitieCopyWith<$Res> {
  factory _$LiveActivitieCopyWith(
          _LiveActivitie value, $Res Function(_LiveActivitie) _then) =
      __$LiveActivitieCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String device,
      String chat,
      String user,
      @JsonKey(unknownEnumValue: LiveActivitiePlatform.unknown)
      LiveActivitiePlatform platform,
      @JsonKey(unknownEnumValue: LiveActivitieStatus.unknown)
      LiveActivitieStatus status,
      String? activityPushToken,
      double contentStateVersion,
      DateTime? created,
      DateTime? updated,
      DateTime? expiresAt,
      DateTime? lastPushAt,
      DateTime? endedAt,
      String? lastError});
}

/// @nodoc
class __$LiveActivitieCopyWithImpl<$Res>
    implements _$LiveActivitieCopyWith<$Res> {
  __$LiveActivitieCopyWithImpl(this._self, this._then);

  final _LiveActivitie _self;
  final $Res Function(_LiveActivitie) _then;

  /// Create a copy of LiveActivitie
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? device = null,
    Object? chat = null,
    Object? user = null,
    Object? platform = null,
    Object? status = null,
    Object? activityPushToken = freezed,
    Object? contentStateVersion = null,
    Object? created = freezed,
    Object? updated = freezed,
    Object? expiresAt = freezed,
    Object? lastPushAt = freezed,
    Object? endedAt = freezed,
    Object? lastError = freezed,
  }) {
    return _then(_LiveActivitie(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      device: null == device
          ? _self.device
          : device // ignore: cast_nullable_to_non_nullable
              as String,
      chat: null == chat
          ? _self.chat
          : chat // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      platform: null == platform
          ? _self.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as LiveActivitiePlatform,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LiveActivitieStatus,
      activityPushToken: freezed == activityPushToken
          ? _self.activityPushToken
          : activityPushToken // ignore: cast_nullable_to_non_nullable
              as String?,
      contentStateVersion: null == contentStateVersion
          ? _self.contentStateVersion
          : contentStateVersion // ignore: cast_nullable_to_non_nullable
              as double,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      expiresAt: freezed == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastPushAt: freezed == lastPushAt
          ? _self.lastPushAt
          : lastPushAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endedAt: freezed == endedAt
          ? _self.endedAt
          : endedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
