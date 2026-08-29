// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harness_instance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessInstance {
  String get id;
  String get harness;
  String? get user;
  String? get harnessModel;
  String? get oauthAccount;
  String? get launchKey;
  String get containerName;
  String? get acpEndpoint;
  String? get secret;
  @JsonKey(unknownEnumValue: HarnessInstanceStatus.unknown)
  HarnessInstanceStatus get status;
  String? get lastError;
  bool? get managed;
  bool? get retryable;
  String? get lastUsed;
  String? get lastLogExcerpt;
  dynamic get syncedCredentials;
  DateTime? get created;
  DateTime? get updated;

  /// Create a copy of HarnessInstance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HarnessInstanceCopyWith<HarnessInstance> get copyWith =>
      _$HarnessInstanceCopyWithImpl<HarnessInstance>(
          this as HarnessInstance, _$identity);

  /// Serializes this HarnessInstance to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HarnessInstance &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.harnessModel, harnessModel) ||
                other.harnessModel == harnessModel) &&
            (identical(other.oauthAccount, oauthAccount) ||
                other.oauthAccount == oauthAccount) &&
            (identical(other.launchKey, launchKey) ||
                other.launchKey == launchKey) &&
            (identical(other.containerName, containerName) ||
                other.containerName == containerName) &&
            (identical(other.acpEndpoint, acpEndpoint) ||
                other.acpEndpoint == acpEndpoint) &&
            (identical(other.secret, secret) || other.secret == secret) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.managed, managed) || other.managed == managed) &&
            (identical(other.retryable, retryable) ||
                other.retryable == retryable) &&
            (identical(other.lastUsed, lastUsed) ||
                other.lastUsed == lastUsed) &&
            (identical(other.lastLogExcerpt, lastLogExcerpt) ||
                other.lastLogExcerpt == lastLogExcerpt) &&
            const DeepCollectionEquality()
                .equals(other.syncedCredentials, syncedCredentials) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      harness,
      user,
      harnessModel,
      oauthAccount,
      launchKey,
      containerName,
      acpEndpoint,
      secret,
      status,
      lastError,
      managed,
      retryable,
      lastUsed,
      lastLogExcerpt,
      const DeepCollectionEquality().hash(syncedCredentials),
      created,
      updated);

  @override
  String toString() {
    return 'HarnessInstance(id: $id, harness: $harness, user: $user, harnessModel: $harnessModel, oauthAccount: $oauthAccount, launchKey: $launchKey, containerName: $containerName, acpEndpoint: $acpEndpoint, secret: $secret, status: $status, lastError: $lastError, managed: $managed, retryable: $retryable, lastUsed: $lastUsed, lastLogExcerpt: $lastLogExcerpt, syncedCredentials: $syncedCredentials, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class $HarnessInstanceCopyWith<$Res> {
  factory $HarnessInstanceCopyWith(
          HarnessInstance value, $Res Function(HarnessInstance) _then) =
      _$HarnessInstanceCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String harness,
      String? user,
      String? harnessModel,
      String? oauthAccount,
      String? launchKey,
      String containerName,
      String? acpEndpoint,
      String? secret,
      @JsonKey(unknownEnumValue: HarnessInstanceStatus.unknown)
      HarnessInstanceStatus status,
      String? lastError,
      bool? managed,
      bool? retryable,
      String? lastUsed,
      String? lastLogExcerpt,
      dynamic syncedCredentials,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class _$HarnessInstanceCopyWithImpl<$Res>
    implements $HarnessInstanceCopyWith<$Res> {
  _$HarnessInstanceCopyWithImpl(this._self, this._then);

  final HarnessInstance _self;
  final $Res Function(HarnessInstance) _then;

  /// Create a copy of HarnessInstance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? harness = null,
    Object? user = freezed,
    Object? harnessModel = freezed,
    Object? oauthAccount = freezed,
    Object? launchKey = freezed,
    Object? containerName = null,
    Object? acpEndpoint = freezed,
    Object? secret = freezed,
    Object? status = null,
    Object? lastError = freezed,
    Object? managed = freezed,
    Object? retryable = freezed,
    Object? lastUsed = freezed,
    Object? lastLogExcerpt = freezed,
    Object? syncedCredentials = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      harness: null == harness
          ? _self.harness
          : harness // ignore: cast_nullable_to_non_nullable
              as String,
      user: freezed == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String?,
      harnessModel: freezed == harnessModel
          ? _self.harnessModel
          : harnessModel // ignore: cast_nullable_to_non_nullable
              as String?,
      oauthAccount: freezed == oauthAccount
          ? _self.oauthAccount
          : oauthAccount // ignore: cast_nullable_to_non_nullable
              as String?,
      launchKey: freezed == launchKey
          ? _self.launchKey
          : launchKey // ignore: cast_nullable_to_non_nullable
              as String?,
      containerName: null == containerName
          ? _self.containerName
          : containerName // ignore: cast_nullable_to_non_nullable
              as String,
      acpEndpoint: freezed == acpEndpoint
          ? _self.acpEndpoint
          : acpEndpoint // ignore: cast_nullable_to_non_nullable
              as String?,
      secret: freezed == secret
          ? _self.secret
          : secret // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as HarnessInstanceStatus,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
      managed: freezed == managed
          ? _self.managed
          : managed // ignore: cast_nullable_to_non_nullable
              as bool?,
      retryable: freezed == retryable
          ? _self.retryable
          : retryable // ignore: cast_nullable_to_non_nullable
              as bool?,
      lastUsed: freezed == lastUsed
          ? _self.lastUsed
          : lastUsed // ignore: cast_nullable_to_non_nullable
              as String?,
      lastLogExcerpt: freezed == lastLogExcerpt
          ? _self.lastLogExcerpt
          : lastLogExcerpt // ignore: cast_nullable_to_non_nullable
              as String?,
      syncedCredentials: freezed == syncedCredentials
          ? _self.syncedCredentials
          : syncedCredentials // ignore: cast_nullable_to_non_nullable
              as dynamic,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [HarnessInstance].
extension HarnessInstancePatterns on HarnessInstance {
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
    TResult Function(_HarnessInstance value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessInstance() when $default != null:
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
    TResult Function(_HarnessInstance value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessInstance():
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
    TResult? Function(_HarnessInstance value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessInstance() when $default != null:
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
            String harness,
            String? user,
            String? harnessModel,
            String? oauthAccount,
            String? launchKey,
            String containerName,
            String? acpEndpoint,
            String? secret,
            @JsonKey(unknownEnumValue: HarnessInstanceStatus.unknown)
            HarnessInstanceStatus status,
            String? lastError,
            bool? managed,
            bool? retryable,
            String? lastUsed,
            String? lastLogExcerpt,
            dynamic syncedCredentials,
            DateTime? created,
            DateTime? updated)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessInstance() when $default != null:
        return $default(
            _that.id,
            _that.harness,
            _that.user,
            _that.harnessModel,
            _that.oauthAccount,
            _that.launchKey,
            _that.containerName,
            _that.acpEndpoint,
            _that.secret,
            _that.status,
            _that.lastError,
            _that.managed,
            _that.retryable,
            _that.lastUsed,
            _that.lastLogExcerpt,
            _that.syncedCredentials,
            _that.created,
            _that.updated);
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
            String harness,
            String? user,
            String? harnessModel,
            String? oauthAccount,
            String? launchKey,
            String containerName,
            String? acpEndpoint,
            String? secret,
            @JsonKey(unknownEnumValue: HarnessInstanceStatus.unknown)
            HarnessInstanceStatus status,
            String? lastError,
            bool? managed,
            bool? retryable,
            String? lastUsed,
            String? lastLogExcerpt,
            dynamic syncedCredentials,
            DateTime? created,
            DateTime? updated)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessInstance():
        return $default(
            _that.id,
            _that.harness,
            _that.user,
            _that.harnessModel,
            _that.oauthAccount,
            _that.launchKey,
            _that.containerName,
            _that.acpEndpoint,
            _that.secret,
            _that.status,
            _that.lastError,
            _that.managed,
            _that.retryable,
            _that.lastUsed,
            _that.lastLogExcerpt,
            _that.syncedCredentials,
            _that.created,
            _that.updated);
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
            String harness,
            String? user,
            String? harnessModel,
            String? oauthAccount,
            String? launchKey,
            String containerName,
            String? acpEndpoint,
            String? secret,
            @JsonKey(unknownEnumValue: HarnessInstanceStatus.unknown)
            HarnessInstanceStatus status,
            String? lastError,
            bool? managed,
            bool? retryable,
            String? lastUsed,
            String? lastLogExcerpt,
            dynamic syncedCredentials,
            DateTime? created,
            DateTime? updated)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessInstance() when $default != null:
        return $default(
            _that.id,
            _that.harness,
            _that.user,
            _that.harnessModel,
            _that.oauthAccount,
            _that.launchKey,
            _that.containerName,
            _that.acpEndpoint,
            _that.secret,
            _that.status,
            _that.lastError,
            _that.managed,
            _that.retryable,
            _that.lastUsed,
            _that.lastLogExcerpt,
            _that.syncedCredentials,
            _that.created,
            _that.updated);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _HarnessInstance implements HarnessInstance {
  const _HarnessInstance(
      {required this.id,
      required this.harness,
      this.user,
      this.harnessModel,
      this.oauthAccount,
      this.launchKey,
      required this.containerName,
      this.acpEndpoint,
      this.secret,
      @JsonKey(unknownEnumValue: HarnessInstanceStatus.unknown)
      required this.status,
      this.lastError,
      this.managed,
      this.retryable,
      this.lastUsed,
      this.lastLogExcerpt,
      this.syncedCredentials,
      this.created,
      this.updated});
  factory _HarnessInstance.fromJson(Map<String, dynamic> json) =>
      _$HarnessInstanceFromJson(json);

  @override
  final String id;
  @override
  final String harness;
  @override
  final String? user;
  @override
  final String? harnessModel;
  @override
  final String? oauthAccount;
  @override
  final String? launchKey;
  @override
  final String containerName;
  @override
  final String? acpEndpoint;
  @override
  final String? secret;
  @override
  @JsonKey(unknownEnumValue: HarnessInstanceStatus.unknown)
  final HarnessInstanceStatus status;
  @override
  final String? lastError;
  @override
  final bool? managed;
  @override
  final bool? retryable;
  @override
  final String? lastUsed;
  @override
  final String? lastLogExcerpt;
  @override
  final dynamic syncedCredentials;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;

  /// Create a copy of HarnessInstance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HarnessInstanceCopyWith<_HarnessInstance> get copyWith =>
      __$HarnessInstanceCopyWithImpl<_HarnessInstance>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HarnessInstanceToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HarnessInstance &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.harnessModel, harnessModel) ||
                other.harnessModel == harnessModel) &&
            (identical(other.oauthAccount, oauthAccount) ||
                other.oauthAccount == oauthAccount) &&
            (identical(other.launchKey, launchKey) ||
                other.launchKey == launchKey) &&
            (identical(other.containerName, containerName) ||
                other.containerName == containerName) &&
            (identical(other.acpEndpoint, acpEndpoint) ||
                other.acpEndpoint == acpEndpoint) &&
            (identical(other.secret, secret) || other.secret == secret) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.managed, managed) || other.managed == managed) &&
            (identical(other.retryable, retryable) ||
                other.retryable == retryable) &&
            (identical(other.lastUsed, lastUsed) ||
                other.lastUsed == lastUsed) &&
            (identical(other.lastLogExcerpt, lastLogExcerpt) ||
                other.lastLogExcerpt == lastLogExcerpt) &&
            const DeepCollectionEquality()
                .equals(other.syncedCredentials, syncedCredentials) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      harness,
      user,
      harnessModel,
      oauthAccount,
      launchKey,
      containerName,
      acpEndpoint,
      secret,
      status,
      lastError,
      managed,
      retryable,
      lastUsed,
      lastLogExcerpt,
      const DeepCollectionEquality().hash(syncedCredentials),
      created,
      updated);

  @override
  String toString() {
    return 'HarnessInstance(id: $id, harness: $harness, user: $user, harnessModel: $harnessModel, oauthAccount: $oauthAccount, launchKey: $launchKey, containerName: $containerName, acpEndpoint: $acpEndpoint, secret: $secret, status: $status, lastError: $lastError, managed: $managed, retryable: $retryable, lastUsed: $lastUsed, lastLogExcerpt: $lastLogExcerpt, syncedCredentials: $syncedCredentials, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class _$HarnessInstanceCopyWith<$Res>
    implements $HarnessInstanceCopyWith<$Res> {
  factory _$HarnessInstanceCopyWith(
          _HarnessInstance value, $Res Function(_HarnessInstance) _then) =
      __$HarnessInstanceCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String harness,
      String? user,
      String? harnessModel,
      String? oauthAccount,
      String? launchKey,
      String containerName,
      String? acpEndpoint,
      String? secret,
      @JsonKey(unknownEnumValue: HarnessInstanceStatus.unknown)
      HarnessInstanceStatus status,
      String? lastError,
      bool? managed,
      bool? retryable,
      String? lastUsed,
      String? lastLogExcerpt,
      dynamic syncedCredentials,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class __$HarnessInstanceCopyWithImpl<$Res>
    implements _$HarnessInstanceCopyWith<$Res> {
  __$HarnessInstanceCopyWithImpl(this._self, this._then);

  final _HarnessInstance _self;
  final $Res Function(_HarnessInstance) _then;

  /// Create a copy of HarnessInstance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? harness = null,
    Object? user = freezed,
    Object? harnessModel = freezed,
    Object? oauthAccount = freezed,
    Object? launchKey = freezed,
    Object? containerName = null,
    Object? acpEndpoint = freezed,
    Object? secret = freezed,
    Object? status = null,
    Object? lastError = freezed,
    Object? managed = freezed,
    Object? retryable = freezed,
    Object? lastUsed = freezed,
    Object? lastLogExcerpt = freezed,
    Object? syncedCredentials = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(_HarnessInstance(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      harness: null == harness
          ? _self.harness
          : harness // ignore: cast_nullable_to_non_nullable
              as String,
      user: freezed == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String?,
      harnessModel: freezed == harnessModel
          ? _self.harnessModel
          : harnessModel // ignore: cast_nullable_to_non_nullable
              as String?,
      oauthAccount: freezed == oauthAccount
          ? _self.oauthAccount
          : oauthAccount // ignore: cast_nullable_to_non_nullable
              as String?,
      launchKey: freezed == launchKey
          ? _self.launchKey
          : launchKey // ignore: cast_nullable_to_non_nullable
              as String?,
      containerName: null == containerName
          ? _self.containerName
          : containerName // ignore: cast_nullable_to_non_nullable
              as String,
      acpEndpoint: freezed == acpEndpoint
          ? _self.acpEndpoint
          : acpEndpoint // ignore: cast_nullable_to_non_nullable
              as String?,
      secret: freezed == secret
          ? _self.secret
          : secret // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as HarnessInstanceStatus,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
      managed: freezed == managed
          ? _self.managed
          : managed // ignore: cast_nullable_to_non_nullable
              as bool?,
      retryable: freezed == retryable
          ? _self.retryable
          : retryable // ignore: cast_nullable_to_non_nullable
              as bool?,
      lastUsed: freezed == lastUsed
          ? _self.lastUsed
          : lastUsed // ignore: cast_nullable_to_non_nullable
              as String?,
      lastLogExcerpt: freezed == lastLogExcerpt
          ? _self.lastLogExcerpt
          : lastLogExcerpt // ignore: cast_nullable_to_non_nullable
              as String?,
      syncedCredentials: freezed == syncedCredentials
          ? _self.syncedCredentials
          : syncedCredentials // ignore: cast_nullable_to_non_nullable
              as dynamic,
      created: freezed == created
          ? _self.created
          : created // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updated: freezed == updated
          ? _self.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
