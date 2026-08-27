// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harness_oauth_account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessOauthAccount {
  String get id;
  String get harness;
  String get provider;
  String get owner;
  String get name;
  @JsonKey(unknownEnumValue: HarnessOauthAccountVisibility.unknown)
  HarnessOauthAccountVisibility get visibility;
  @JsonKey(unknownEnumValue: HarnessOauthAccountStatus.unknown)
  HarnessOauthAccountStatus get status;
  String? get lastError;
  DateTime? get created;
  DateTime? get updated;

  /// Create a copy of HarnessOauthAccount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HarnessOauthAccountCopyWith<HarnessOauthAccount> get copyWith =>
      _$HarnessOauthAccountCopyWithImpl<HarnessOauthAccount>(
          this as HarnessOauthAccount, _$identity);

  /// Serializes this HarnessOauthAccount to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HarnessOauthAccount &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, harness, provider, owner,
      name, visibility, status, lastError, created, updated);

  @override
  String toString() {
    return 'HarnessOauthAccount(id: $id, harness: $harness, provider: $provider, owner: $owner, name: $name, visibility: $visibility, status: $status, lastError: $lastError, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class $HarnessOauthAccountCopyWith<$Res> {
  factory $HarnessOauthAccountCopyWith(
          HarnessOauthAccount value, $Res Function(HarnessOauthAccount) _then) =
      _$HarnessOauthAccountCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String harness,
      String provider,
      String owner,
      String name,
      @JsonKey(unknownEnumValue: HarnessOauthAccountVisibility.unknown)
      HarnessOauthAccountVisibility visibility,
      @JsonKey(unknownEnumValue: HarnessOauthAccountStatus.unknown)
      HarnessOauthAccountStatus status,
      String? lastError,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class _$HarnessOauthAccountCopyWithImpl<$Res>
    implements $HarnessOauthAccountCopyWith<$Res> {
  _$HarnessOauthAccountCopyWithImpl(this._self, this._then);

  final HarnessOauthAccount _self;
  final $Res Function(HarnessOauthAccount) _then;

  /// Create a copy of HarnessOauthAccount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? harness = null,
    Object? provider = null,
    Object? owner = null,
    Object? name = null,
    Object? visibility = null,
    Object? status = null,
    Object? lastError = freezed,
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
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _self.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      visibility: null == visibility
          ? _self.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as HarnessOauthAccountVisibility,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as HarnessOauthAccountStatus,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
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

/// Adds pattern-matching-related methods to [HarnessOauthAccount].
extension HarnessOauthAccountPatterns on HarnessOauthAccount {
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
    TResult Function(_HarnessOauthAccount value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAccount() when $default != null:
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
    TResult Function(_HarnessOauthAccount value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAccount():
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
    TResult? Function(_HarnessOauthAccount value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAccount() when $default != null:
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
            String provider,
            String owner,
            String name,
            @JsonKey(unknownEnumValue: HarnessOauthAccountVisibility.unknown)
            HarnessOauthAccountVisibility visibility,
            @JsonKey(unknownEnumValue: HarnessOauthAccountStatus.unknown)
            HarnessOauthAccountStatus status,
            String? lastError,
            DateTime? created,
            DateTime? updated)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAccount() when $default != null:
        return $default(
            _that.id,
            _that.harness,
            _that.provider,
            _that.owner,
            _that.name,
            _that.visibility,
            _that.status,
            _that.lastError,
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
            String provider,
            String owner,
            String name,
            @JsonKey(unknownEnumValue: HarnessOauthAccountVisibility.unknown)
            HarnessOauthAccountVisibility visibility,
            @JsonKey(unknownEnumValue: HarnessOauthAccountStatus.unknown)
            HarnessOauthAccountStatus status,
            String? lastError,
            DateTime? created,
            DateTime? updated)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAccount():
        return $default(
            _that.id,
            _that.harness,
            _that.provider,
            _that.owner,
            _that.name,
            _that.visibility,
            _that.status,
            _that.lastError,
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
            String provider,
            String owner,
            String name,
            @JsonKey(unknownEnumValue: HarnessOauthAccountVisibility.unknown)
            HarnessOauthAccountVisibility visibility,
            @JsonKey(unknownEnumValue: HarnessOauthAccountStatus.unknown)
            HarnessOauthAccountStatus status,
            String? lastError,
            DateTime? created,
            DateTime? updated)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAccount() when $default != null:
        return $default(
            _that.id,
            _that.harness,
            _that.provider,
            _that.owner,
            _that.name,
            _that.visibility,
            _that.status,
            _that.lastError,
            _that.created,
            _that.updated);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _HarnessOauthAccount implements HarnessOauthAccount {
  const _HarnessOauthAccount(
      {required this.id,
      required this.harness,
      required this.provider,
      required this.owner,
      required this.name,
      @JsonKey(unknownEnumValue: HarnessOauthAccountVisibility.unknown)
      required this.visibility,
      @JsonKey(unknownEnumValue: HarnessOauthAccountStatus.unknown)
      required this.status,
      this.lastError,
      this.created,
      this.updated});
  factory _HarnessOauthAccount.fromJson(Map<String, dynamic> json) =>
      _$HarnessOauthAccountFromJson(json);

  @override
  final String id;
  @override
  final String harness;
  @override
  final String provider;
  @override
  final String owner;
  @override
  final String name;
  @override
  @JsonKey(unknownEnumValue: HarnessOauthAccountVisibility.unknown)
  final HarnessOauthAccountVisibility visibility;
  @override
  @JsonKey(unknownEnumValue: HarnessOauthAccountStatus.unknown)
  final HarnessOauthAccountStatus status;
  @override
  final String? lastError;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;

  /// Create a copy of HarnessOauthAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HarnessOauthAccountCopyWith<_HarnessOauthAccount> get copyWith =>
      __$HarnessOauthAccountCopyWithImpl<_HarnessOauthAccount>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HarnessOauthAccountToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HarnessOauthAccount &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, harness, provider, owner,
      name, visibility, status, lastError, created, updated);

  @override
  String toString() {
    return 'HarnessOauthAccount(id: $id, harness: $harness, provider: $provider, owner: $owner, name: $name, visibility: $visibility, status: $status, lastError: $lastError, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class _$HarnessOauthAccountCopyWith<$Res>
    implements $HarnessOauthAccountCopyWith<$Res> {
  factory _$HarnessOauthAccountCopyWith(_HarnessOauthAccount value,
          $Res Function(_HarnessOauthAccount) _then) =
      __$HarnessOauthAccountCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String harness,
      String provider,
      String owner,
      String name,
      @JsonKey(unknownEnumValue: HarnessOauthAccountVisibility.unknown)
      HarnessOauthAccountVisibility visibility,
      @JsonKey(unknownEnumValue: HarnessOauthAccountStatus.unknown)
      HarnessOauthAccountStatus status,
      String? lastError,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class __$HarnessOauthAccountCopyWithImpl<$Res>
    implements _$HarnessOauthAccountCopyWith<$Res> {
  __$HarnessOauthAccountCopyWithImpl(this._self, this._then);

  final _HarnessOauthAccount _self;
  final $Res Function(_HarnessOauthAccount) _then;

  /// Create a copy of HarnessOauthAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? harness = null,
    Object? provider = null,
    Object? owner = null,
    Object? name = null,
    Object? visibility = null,
    Object? status = null,
    Object? lastError = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(_HarnessOauthAccount(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      harness: null == harness
          ? _self.harness
          : harness // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _self.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      visibility: null == visibility
          ? _self.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as HarnessOauthAccountVisibility,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as HarnessOauthAccountStatus,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
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
