// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harness_oauth_attempt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessOauthAttempt {
  String get id;
  String get account;
  @JsonKey(unknownEnumValue: HarnessOauthAttemptStatus.unknown)
  HarnessOauthAttemptStatus get status;
  String? get lastError;
  DateTime? get expiresAt;
  DateTime? get created;
  DateTime? get updated;

  /// Create a copy of HarnessOauthAttempt
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HarnessOauthAttemptCopyWith<HarnessOauthAttempt> get copyWith =>
      _$HarnessOauthAttemptCopyWithImpl<HarnessOauthAttempt>(
          this as HarnessOauthAttempt, _$identity);

  /// Serializes this HarnessOauthAttempt to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HarnessOauthAttempt &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.account, account) || other.account == account) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, account, status, lastError, expiresAt, created, updated);

  @override
  String toString() {
    return 'HarnessOauthAttempt(id: $id, account: $account, status: $status, lastError: $lastError, expiresAt: $expiresAt, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class $HarnessOauthAttemptCopyWith<$Res> {
  factory $HarnessOauthAttemptCopyWith(
          HarnessOauthAttempt value, $Res Function(HarnessOauthAttempt) _then) =
      _$HarnessOauthAttemptCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String account,
      @JsonKey(unknownEnumValue: HarnessOauthAttemptStatus.unknown)
      HarnessOauthAttemptStatus status,
      String? lastError,
      DateTime? expiresAt,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class _$HarnessOauthAttemptCopyWithImpl<$Res>
    implements $HarnessOauthAttemptCopyWith<$Res> {
  _$HarnessOauthAttemptCopyWithImpl(this._self, this._then);

  final HarnessOauthAttempt _self;
  final $Res Function(HarnessOauthAttempt) _then;

  /// Create a copy of HarnessOauthAttempt
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? account = null,
    Object? status = null,
    Object? lastError = freezed,
    Object? expiresAt = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      account: null == account
          ? _self.account
          : account // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as HarnessOauthAttemptStatus,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
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

/// Adds pattern-matching-related methods to [HarnessOauthAttempt].
extension HarnessOauthAttemptPatterns on HarnessOauthAttempt {
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
    TResult Function(_HarnessOauthAttempt value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAttempt() when $default != null:
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
    TResult Function(_HarnessOauthAttempt value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAttempt():
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
    TResult? Function(_HarnessOauthAttempt value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAttempt() when $default != null:
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
            String account,
            @JsonKey(unknownEnumValue: HarnessOauthAttemptStatus.unknown)
            HarnessOauthAttemptStatus status,
            String? lastError,
            DateTime? expiresAt,
            DateTime? created,
            DateTime? updated)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAttempt() when $default != null:
        return $default(_that.id, _that.account, _that.status, _that.lastError,
            _that.expiresAt, _that.created, _that.updated);
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
            String account,
            @JsonKey(unknownEnumValue: HarnessOauthAttemptStatus.unknown)
            HarnessOauthAttemptStatus status,
            String? lastError,
            DateTime? expiresAt,
            DateTime? created,
            DateTime? updated)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAttempt():
        return $default(_that.id, _that.account, _that.status, _that.lastError,
            _that.expiresAt, _that.created, _that.updated);
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
            String account,
            @JsonKey(unknownEnumValue: HarnessOauthAttemptStatus.unknown)
            HarnessOauthAttemptStatus status,
            String? lastError,
            DateTime? expiresAt,
            DateTime? created,
            DateTime? updated)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessOauthAttempt() when $default != null:
        return $default(_that.id, _that.account, _that.status, _that.lastError,
            _that.expiresAt, _that.created, _that.updated);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _HarnessOauthAttempt implements HarnessOauthAttempt {
  const _HarnessOauthAttempt(
      {required this.id,
      required this.account,
      @JsonKey(unknownEnumValue: HarnessOauthAttemptStatus.unknown)
      required this.status,
      this.lastError,
      this.expiresAt,
      this.created,
      this.updated});
  factory _HarnessOauthAttempt.fromJson(Map<String, dynamic> json) =>
      _$HarnessOauthAttemptFromJson(json);

  @override
  final String id;
  @override
  final String account;
  @override
  @JsonKey(unknownEnumValue: HarnessOauthAttemptStatus.unknown)
  final HarnessOauthAttemptStatus status;
  @override
  final String? lastError;
  @override
  final DateTime? expiresAt;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;

  /// Create a copy of HarnessOauthAttempt
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HarnessOauthAttemptCopyWith<_HarnessOauthAttempt> get copyWith =>
      __$HarnessOauthAttemptCopyWithImpl<_HarnessOauthAttempt>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HarnessOauthAttemptToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HarnessOauthAttempt &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.account, account) || other.account == account) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastError, lastError) ||
                other.lastError == lastError) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, account, status, lastError, expiresAt, created, updated);

  @override
  String toString() {
    return 'HarnessOauthAttempt(id: $id, account: $account, status: $status, lastError: $lastError, expiresAt: $expiresAt, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class _$HarnessOauthAttemptCopyWith<$Res>
    implements $HarnessOauthAttemptCopyWith<$Res> {
  factory _$HarnessOauthAttemptCopyWith(_HarnessOauthAttempt value,
          $Res Function(_HarnessOauthAttempt) _then) =
      __$HarnessOauthAttemptCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String account,
      @JsonKey(unknownEnumValue: HarnessOauthAttemptStatus.unknown)
      HarnessOauthAttemptStatus status,
      String? lastError,
      DateTime? expiresAt,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class __$HarnessOauthAttemptCopyWithImpl<$Res>
    implements _$HarnessOauthAttemptCopyWith<$Res> {
  __$HarnessOauthAttemptCopyWithImpl(this._self, this._then);

  final _HarnessOauthAttempt _self;
  final $Res Function(_HarnessOauthAttempt) _then;

  /// Create a copy of HarnessOauthAttempt
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? account = null,
    Object? status = null,
    Object? lastError = freezed,
    Object? expiresAt = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(_HarnessOauthAttempt(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      account: null == account
          ? _self.account
          : account // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as HarnessOauthAttemptStatus,
      lastError: freezed == lastError
          ? _self.lastError
          : lastError // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
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
