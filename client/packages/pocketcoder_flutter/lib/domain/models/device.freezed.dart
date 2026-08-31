// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Device {
  String get id;
  String get user;
  String get name;
  String get pushToken;
  @JsonKey(unknownEnumValue: DevicePushService.unknown)
  DevicePushService get pushService;
  bool? get isActive;
  DateTime? get created;
  DateTime? get updated;
  @JsonKey(unknownEnumValue: DevicePlatform.unknown)
  DevicePlatform? get platform;
  String? get pushToStartToken;

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DeviceCopyWith<Device> get copyWith =>
      _$DeviceCopyWithImpl<Device>(this as Device, _$identity);

  /// Serializes this Device to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Device &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.pushToken, pushToken) ||
                other.pushToken == pushToken) &&
            (identical(other.pushService, pushService) ||
                other.pushService == pushService) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.pushToStartToken, pushToStartToken) ||
                other.pushToStartToken == pushToStartToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, user, name, pushToken,
      pushService, isActive, created, updated, platform, pushToStartToken);

  @override
  String toString() {
    return 'Device(id: $id, user: $user, name: $name, pushToken: $pushToken, pushService: $pushService, isActive: $isActive, created: $created, updated: $updated, platform: $platform, pushToStartToken: $pushToStartToken)';
  }
}

/// @nodoc
abstract mixin class $DeviceCopyWith<$Res> {
  factory $DeviceCopyWith(Device value, $Res Function(Device) _then) =
      _$DeviceCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String user,
      String name,
      String pushToken,
      @JsonKey(unknownEnumValue: DevicePushService.unknown)
      DevicePushService pushService,
      bool? isActive,
      DateTime? created,
      DateTime? updated,
      @JsonKey(unknownEnumValue: DevicePlatform.unknown)
      DevicePlatform? platform,
      String? pushToStartToken});
}

/// @nodoc
class _$DeviceCopyWithImpl<$Res> implements $DeviceCopyWith<$Res> {
  _$DeviceCopyWithImpl(this._self, this._then);

  final Device _self;
  final $Res Function(Device) _then;

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? name = null,
    Object? pushToken = null,
    Object? pushService = null,
    Object? isActive = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? platform = freezed,
    Object? pushToStartToken = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      pushToken: null == pushToken
          ? _self.pushToken
          : pushToken // ignore: cast_nullable_to_non_nullable
              as String,
      pushService: null == pushService
          ? _self.pushService
          : pushService // ignore: cast_nullable_to_non_nullable
              as DevicePushService,
      isActive: freezed == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      platform: freezed == platform
          ? _self.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as DevicePlatform?,
      pushToStartToken: freezed == pushToStartToken
          ? _self.pushToStartToken
          : pushToStartToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Device].
extension DevicePatterns on Device {
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
    TResult Function(_Device value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Device() when $default != null:
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
    TResult Function(_Device value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Device():
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
    TResult? Function(_Device value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Device() when $default != null:
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
            String user,
            String name,
            String pushToken,
            @JsonKey(unknownEnumValue: DevicePushService.unknown)
            DevicePushService pushService,
            bool? isActive,
            DateTime? created,
            DateTime? updated,
            @JsonKey(unknownEnumValue: DevicePlatform.unknown)
            DevicePlatform? platform,
            String? pushToStartToken)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Device() when $default != null:
        return $default(
            _that.id,
            _that.user,
            _that.name,
            _that.pushToken,
            _that.pushService,
            _that.isActive,
            _that.created,
            _that.updated,
            _that.platform,
            _that.pushToStartToken);
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
            String user,
            String name,
            String pushToken,
            @JsonKey(unknownEnumValue: DevicePushService.unknown)
            DevicePushService pushService,
            bool? isActive,
            DateTime? created,
            DateTime? updated,
            @JsonKey(unknownEnumValue: DevicePlatform.unknown)
            DevicePlatform? platform,
            String? pushToStartToken)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Device():
        return $default(
            _that.id,
            _that.user,
            _that.name,
            _that.pushToken,
            _that.pushService,
            _that.isActive,
            _that.created,
            _that.updated,
            _that.platform,
            _that.pushToStartToken);
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
            String user,
            String name,
            String pushToken,
            @JsonKey(unknownEnumValue: DevicePushService.unknown)
            DevicePushService pushService,
            bool? isActive,
            DateTime? created,
            DateTime? updated,
            @JsonKey(unknownEnumValue: DevicePlatform.unknown)
            DevicePlatform? platform,
            String? pushToStartToken)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Device() when $default != null:
        return $default(
            _that.id,
            _that.user,
            _that.name,
            _that.pushToken,
            _that.pushService,
            _that.isActive,
            _that.created,
            _that.updated,
            _that.platform,
            _that.pushToStartToken);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Device implements Device {
  const _Device(
      {required this.id,
      required this.user,
      required this.name,
      required this.pushToken,
      @JsonKey(unknownEnumValue: DevicePushService.unknown)
      required this.pushService,
      this.isActive,
      this.created,
      this.updated,
      @JsonKey(unknownEnumValue: DevicePlatform.unknown) this.platform,
      this.pushToStartToken});
  factory _Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);

  @override
  final String id;
  @override
  final String user;
  @override
  final String name;
  @override
  final String pushToken;
  @override
  @JsonKey(unknownEnumValue: DevicePushService.unknown)
  final DevicePushService pushService;
  @override
  final bool? isActive;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;
  @override
  @JsonKey(unknownEnumValue: DevicePlatform.unknown)
  final DevicePlatform? platform;
  @override
  final String? pushToStartToken;

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DeviceCopyWith<_Device> get copyWith =>
      __$DeviceCopyWithImpl<_Device>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DeviceToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Device &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.pushToken, pushToken) ||
                other.pushToken == pushToken) &&
            (identical(other.pushService, pushService) ||
                other.pushService == pushService) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.pushToStartToken, pushToStartToken) ||
                other.pushToStartToken == pushToStartToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, user, name, pushToken,
      pushService, isActive, created, updated, platform, pushToStartToken);

  @override
  String toString() {
    return 'Device(id: $id, user: $user, name: $name, pushToken: $pushToken, pushService: $pushService, isActive: $isActive, created: $created, updated: $updated, platform: $platform, pushToStartToken: $pushToStartToken)';
  }
}

/// @nodoc
abstract mixin class _$DeviceCopyWith<$Res> implements $DeviceCopyWith<$Res> {
  factory _$DeviceCopyWith(_Device value, $Res Function(_Device) _then) =
      __$DeviceCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String user,
      String name,
      String pushToken,
      @JsonKey(unknownEnumValue: DevicePushService.unknown)
      DevicePushService pushService,
      bool? isActive,
      DateTime? created,
      DateTime? updated,
      @JsonKey(unknownEnumValue: DevicePlatform.unknown)
      DevicePlatform? platform,
      String? pushToStartToken});
}

/// @nodoc
class __$DeviceCopyWithImpl<$Res> implements _$DeviceCopyWith<$Res> {
  __$DeviceCopyWithImpl(this._self, this._then);

  final _Device _self;
  final $Res Function(_Device) _then;

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? name = null,
    Object? pushToken = null,
    Object? pushService = null,
    Object? isActive = freezed,
    Object? created = freezed,
    Object? updated = freezed,
    Object? platform = freezed,
    Object? pushToStartToken = freezed,
  }) {
    return _then(_Device(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      pushToken: null == pushToken
          ? _self.pushToken
          : pushToken // ignore: cast_nullable_to_non_nullable
              as String,
      pushService: null == pushService
          ? _self.pushService
          : pushService // ignore: cast_nullable_to_non_nullable
              as DevicePushService,
      isActive: freezed == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool?,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      platform: freezed == platform
          ? _self.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as DevicePlatform?,
      pushToStartToken: freezed == pushToStartToken
          ? _self.pushToStartToken
          : pushToStartToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
