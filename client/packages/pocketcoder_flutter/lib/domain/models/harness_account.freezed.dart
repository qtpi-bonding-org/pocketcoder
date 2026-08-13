// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harness_account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessAccount {
  String get id;
  String get harness;
  String get owner;
  String get name;
  @JsonKey(unknownEnumValue: HarnessAccountVisibility.unknown)
  HarnessAccountVisibility get visibility;
  @JsonKey(unknownEnumValue: HarnessAccountCredentialMode.unknown)
  HarnessAccountCredentialMode get credentialMode;
  String? get providerKey;
  @JsonKey(unknownEnumValue: HarnessAccountStatus.unknown)
  HarnessAccountStatus get status;
  String? get lastError;
  DateTime? get created;
  DateTime? get updated;

  /// Create a copy of HarnessAccount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HarnessAccountCopyWith<HarnessAccount> get copyWith =>
      _$HarnessAccountCopyWithImpl<HarnessAccount>(
          this as HarnessAccount, _$identity);

  /// Serializes this HarnessAccount to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HarnessAccount &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            (identical(other.credentialMode, credentialMode) ||
                other.credentialMode == credentialMode) &&
            (identical(other.providerKey, providerKey) ||
                other.providerKey == providerKey) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      harness,
      owner,
      name,
      visibility,
      credentialMode,
      providerKey,
      status,
      lastError,
      created,
      updated);

  @override
  String toString() {
    return 'HarnessAccount(id: $id, harness: $harness, owner: $owner, name: $name, visibility: $visibility, credentialMode: $credentialMode, providerKey: $providerKey, status: $status, lastError: $lastError, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class $HarnessAccountCopyWith<$Res> {
  factory $HarnessAccountCopyWith(
          HarnessAccount value, $Res Function(HarnessAccount) _then) =
      _$HarnessAccountCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String harness,
      String owner,
      String name,
      @JsonKey(unknownEnumValue: HarnessAccountVisibility.unknown)
      HarnessAccountVisibility visibility,
      @JsonKey(unknownEnumValue: HarnessAccountCredentialMode.unknown)
      HarnessAccountCredentialMode credentialMode,
      String? providerKey,
      @JsonKey(unknownEnumValue: HarnessAccountStatus.unknown)
      HarnessAccountStatus status,
      String? lastError,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class _$HarnessAccountCopyWithImpl<$Res>
    implements $HarnessAccountCopyWith<$Res> {
  _$HarnessAccountCopyWithImpl(this._self, this._then);

  final HarnessAccount _self;
  final $Res Function(HarnessAccount) _then;

  /// Create a copy of HarnessAccount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? harness = null,
    Object? owner = null,
    Object? name = null,
    Object? visibility = null,
    Object? credentialMode = null,
    Object? providerKey = freezed,
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
              as HarnessAccountVisibility,
      credentialMode: null == credentialMode
          ? _self.credentialMode
          : credentialMode // ignore: cast_nullable_to_non_nullable
              as HarnessAccountCredentialMode,
      providerKey: freezed == providerKey
          ? _self.providerKey
          : providerKey // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as HarnessAccountStatus,
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

/// Adds pattern-matching-related methods to [HarnessAccount].
extension HarnessAccountPatterns on HarnessAccount {
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
    TResult Function(_HarnessAccount value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessAccount() when $default != null:
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
    TResult Function(_HarnessAccount value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAccount():
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
    TResult? Function(_HarnessAccount value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAccount() when $default != null:
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
            String owner,
            String name,
            @JsonKey(unknownEnumValue: HarnessAccountVisibility.unknown)
            HarnessAccountVisibility visibility,
            @JsonKey(unknownEnumValue: HarnessAccountCredentialMode.unknown)
            HarnessAccountCredentialMode credentialMode,
            String? providerKey,
            @JsonKey(unknownEnumValue: HarnessAccountStatus.unknown)
            HarnessAccountStatus status,
            String? lastError,
            DateTime? created,
            DateTime? updated)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessAccount() when $default != null:
        return $default(
            _that.id,
            _that.harness,
            _that.owner,
            _that.name,
            _that.visibility,
            _that.credentialMode,
            _that.providerKey,
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
            String owner,
            String name,
            @JsonKey(unknownEnumValue: HarnessAccountVisibility.unknown)
            HarnessAccountVisibility visibility,
            @JsonKey(unknownEnumValue: HarnessAccountCredentialMode.unknown)
            HarnessAccountCredentialMode credentialMode,
            String? providerKey,
            @JsonKey(unknownEnumValue: HarnessAccountStatus.unknown)
            HarnessAccountStatus status,
            String? lastError,
            DateTime? created,
            DateTime? updated)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAccount():
        return $default(
            _that.id,
            _that.harness,
            _that.owner,
            _that.name,
            _that.visibility,
            _that.credentialMode,
            _that.providerKey,
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
            String owner,
            String name,
            @JsonKey(unknownEnumValue: HarnessAccountVisibility.unknown)
            HarnessAccountVisibility visibility,
            @JsonKey(unknownEnumValue: HarnessAccountCredentialMode.unknown)
            HarnessAccountCredentialMode credentialMode,
            String? providerKey,
            @JsonKey(unknownEnumValue: HarnessAccountStatus.unknown)
            HarnessAccountStatus status,
            String? lastError,
            DateTime? created,
            DateTime? updated)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAccount() when $default != null:
        return $default(
            _that.id,
            _that.harness,
            _that.owner,
            _that.name,
            _that.visibility,
            _that.credentialMode,
            _that.providerKey,
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
class _HarnessAccount implements HarnessAccount {
  const _HarnessAccount(
      {required this.id,
      required this.harness,
      required this.owner,
      required this.name,
      @JsonKey(unknownEnumValue: HarnessAccountVisibility.unknown)
      required this.visibility,
      @JsonKey(unknownEnumValue: HarnessAccountCredentialMode.unknown)
      required this.credentialMode,
      this.providerKey,
      @JsonKey(unknownEnumValue: HarnessAccountStatus.unknown)
      required this.status,
      this.lastError,
      this.created,
      this.updated});
  factory _HarnessAccount.fromJson(Map<String, dynamic> json) =>
      _$HarnessAccountFromJson(json);

  @override
  final String id;
  @override
  final String harness;
  @override
  final String owner;
  @override
  final String name;
  @override
  @JsonKey(unknownEnumValue: HarnessAccountVisibility.unknown)
  final HarnessAccountVisibility visibility;
  @override
  @JsonKey(unknownEnumValue: HarnessAccountCredentialMode.unknown)
  final HarnessAccountCredentialMode credentialMode;
  @override
  final String? providerKey;
  @override
  @JsonKey(unknownEnumValue: HarnessAccountStatus.unknown)
  final HarnessAccountStatus status;
  @override
  final String? lastError;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;

  /// Create a copy of HarnessAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HarnessAccountCopyWith<_HarnessAccount> get copyWith =>
      __$HarnessAccountCopyWithImpl<_HarnessAccount>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HarnessAccountToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HarnessAccount &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            (identical(other.credentialMode, credentialMode) ||
                other.credentialMode == credentialMode) &&
            (identical(other.providerKey, providerKey) ||
                other.providerKey == providerKey) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      harness,
      owner,
      name,
      visibility,
      credentialMode,
      providerKey,
      status,
      lastError,
      created,
      updated);

  @override
  String toString() {
    return 'HarnessAccount(id: $id, harness: $harness, owner: $owner, name: $name, visibility: $visibility, credentialMode: $credentialMode, providerKey: $providerKey, status: $status, lastError: $lastError, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class _$HarnessAccountCopyWith<$Res>
    implements $HarnessAccountCopyWith<$Res> {
  factory _$HarnessAccountCopyWith(
          _HarnessAccount value, $Res Function(_HarnessAccount) _then) =
      __$HarnessAccountCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String harness,
      String owner,
      String name,
      @JsonKey(unknownEnumValue: HarnessAccountVisibility.unknown)
      HarnessAccountVisibility visibility,
      @JsonKey(unknownEnumValue: HarnessAccountCredentialMode.unknown)
      HarnessAccountCredentialMode credentialMode,
      String? providerKey,
      @JsonKey(unknownEnumValue: HarnessAccountStatus.unknown)
      HarnessAccountStatus status,
      String? lastError,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class __$HarnessAccountCopyWithImpl<$Res>
    implements _$HarnessAccountCopyWith<$Res> {
  __$HarnessAccountCopyWithImpl(this._self, this._then);

  final _HarnessAccount _self;
  final $Res Function(_HarnessAccount) _then;

  /// Create a copy of HarnessAccount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? harness = null,
    Object? owner = null,
    Object? name = null,
    Object? visibility = null,
    Object? credentialMode = null,
    Object? providerKey = freezed,
    Object? status = null,
    Object? lastError = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(_HarnessAccount(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      harness: null == harness
          ? _self.harness
          : harness // ignore: cast_nullable_to_non_nullable
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
              as HarnessAccountVisibility,
      credentialMode: null == credentialMode
          ? _self.credentialMode
          : credentialMode // ignore: cast_nullable_to_non_nullable
              as HarnessAccountCredentialMode,
      providerKey: freezed == providerKey
          ? _self.providerKey
          : providerKey // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as HarnessAccountStatus,
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
