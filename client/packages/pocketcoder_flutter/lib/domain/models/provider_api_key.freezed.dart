// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider_api_key.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProviderApiKey {
  String get id;
  String get owner;
  String get provider;
  String get apiKey;
  String? get baseUrl;
  dynamic get extraEnv;
  DateTime? get lastVerified;
  DateTime? get created;
  DateTime? get updated;

  /// Create a copy of ProviderApiKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProviderApiKeyCopyWith<ProviderApiKey> get copyWith =>
      _$ProviderApiKeyCopyWithImpl<ProviderApiKey>(
          this as ProviderApiKey, _$identity);

  /// Serializes this ProviderApiKey to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProviderApiKey &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey) &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            const DeepCollectionEquality().equals(other.extraEnv, extraEnv) &&
            (identical(other.lastVerified, lastVerified) ||
                other.lastVerified == lastVerified) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      owner,
      provider,
      apiKey,
      baseUrl,
      const DeepCollectionEquality().hash(extraEnv),
      lastVerified,
      created,
      updated);

  @override
  String toString() {
    return 'ProviderApiKey(id: $id, owner: $owner, provider: $provider, apiKey: $apiKey, baseUrl: $baseUrl, extraEnv: $extraEnv, lastVerified: $lastVerified, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class $ProviderApiKeyCopyWith<$Res> {
  factory $ProviderApiKeyCopyWith(
          ProviderApiKey value, $Res Function(ProviderApiKey) _then) =
      _$ProviderApiKeyCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String owner,
      String provider,
      String apiKey,
      String? baseUrl,
      dynamic extraEnv,
      DateTime? lastVerified,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class _$ProviderApiKeyCopyWithImpl<$Res>
    implements $ProviderApiKeyCopyWith<$Res> {
  _$ProviderApiKeyCopyWithImpl(this._self, this._then);

  final ProviderApiKey _self;
  final $Res Function(ProviderApiKey) _then;

  /// Create a copy of ProviderApiKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? owner = null,
    Object? provider = null,
    Object? apiKey = null,
    Object? baseUrl = freezed,
    Object? extraEnv = freezed,
    Object? lastVerified = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _self.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      apiKey: null == apiKey
          ? _self.apiKey
          : apiKey // ignore: cast_nullable_to_non_nullable
              as String,
      baseUrl: freezed == baseUrl
          ? _self.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      extraEnv: freezed == extraEnv
          ? _self.extraEnv
          : extraEnv // ignore: cast_nullable_to_non_nullable
              as dynamic,
      lastVerified: freezed == lastVerified
          ? _self.lastVerified
          : lastVerified // ignore: cast_nullable_to_non_nullable
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

/// Adds pattern-matching-related methods to [ProviderApiKey].
extension ProviderApiKeyPatterns on ProviderApiKey {
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
    TResult Function(_ProviderApiKey value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProviderApiKey() when $default != null:
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
    TResult Function(_ProviderApiKey value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderApiKey():
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
    TResult? Function(_ProviderApiKey value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderApiKey() when $default != null:
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
            String owner,
            String provider,
            String apiKey,
            String? baseUrl,
            dynamic extraEnv,
            DateTime? lastVerified,
            DateTime? created,
            DateTime? updated)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProviderApiKey() when $default != null:
        return $default(
            _that.id,
            _that.owner,
            _that.provider,
            _that.apiKey,
            _that.baseUrl,
            _that.extraEnv,
            _that.lastVerified,
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
            String owner,
            String provider,
            String apiKey,
            String? baseUrl,
            dynamic extraEnv,
            DateTime? lastVerified,
            DateTime? created,
            DateTime? updated)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderApiKey():
        return $default(
            _that.id,
            _that.owner,
            _that.provider,
            _that.apiKey,
            _that.baseUrl,
            _that.extraEnv,
            _that.lastVerified,
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
            String owner,
            String provider,
            String apiKey,
            String? baseUrl,
            dynamic extraEnv,
            DateTime? lastVerified,
            DateTime? created,
            DateTime? updated)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderApiKey() when $default != null:
        return $default(
            _that.id,
            _that.owner,
            _that.provider,
            _that.apiKey,
            _that.baseUrl,
            _that.extraEnv,
            _that.lastVerified,
            _that.created,
            _that.updated);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ProviderApiKey implements ProviderApiKey {
  const _ProviderApiKey(
      {required this.id,
      required this.owner,
      required this.provider,
      required this.apiKey,
      this.baseUrl,
      this.extraEnv,
      this.lastVerified,
      this.created,
      this.updated});
  factory _ProviderApiKey.fromJson(Map<String, dynamic> json) =>
      _$ProviderApiKeyFromJson(json);

  @override
  final String id;
  @override
  final String owner;
  @override
  final String provider;
  @override
  final String apiKey;
  @override
  final String? baseUrl;
  @override
  final dynamic extraEnv;
  @override
  final DateTime? lastVerified;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;

  /// Create a copy of ProviderApiKey
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProviderApiKeyCopyWith<_ProviderApiKey> get copyWith =>
      __$ProviderApiKeyCopyWithImpl<_ProviderApiKey>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProviderApiKeyToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProviderApiKey &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey) &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl) &&
            const DeepCollectionEquality().equals(other.extraEnv, extraEnv) &&
            (identical(other.lastVerified, lastVerified) ||
                other.lastVerified == lastVerified) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      owner,
      provider,
      apiKey,
      baseUrl,
      const DeepCollectionEquality().hash(extraEnv),
      lastVerified,
      created,
      updated);

  @override
  String toString() {
    return 'ProviderApiKey(id: $id, owner: $owner, provider: $provider, apiKey: $apiKey, baseUrl: $baseUrl, extraEnv: $extraEnv, lastVerified: $lastVerified, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class _$ProviderApiKeyCopyWith<$Res>
    implements $ProviderApiKeyCopyWith<$Res> {
  factory _$ProviderApiKeyCopyWith(
          _ProviderApiKey value, $Res Function(_ProviderApiKey) _then) =
      __$ProviderApiKeyCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String owner,
      String provider,
      String apiKey,
      String? baseUrl,
      dynamic extraEnv,
      DateTime? lastVerified,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class __$ProviderApiKeyCopyWithImpl<$Res>
    implements _$ProviderApiKeyCopyWith<$Res> {
  __$ProviderApiKeyCopyWithImpl(this._self, this._then);

  final _ProviderApiKey _self;
  final $Res Function(_ProviderApiKey) _then;

  /// Create a copy of ProviderApiKey
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? owner = null,
    Object? provider = null,
    Object? apiKey = null,
    Object? baseUrl = freezed,
    Object? extraEnv = freezed,
    Object? lastVerified = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(_ProviderApiKey(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _self.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      apiKey: null == apiKey
          ? _self.apiKey
          : apiKey // ignore: cast_nullable_to_non_nullable
              as String,
      baseUrl: freezed == baseUrl
          ? _self.baseUrl
          : baseUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      extraEnv: freezed == extraEnv
          ? _self.extraEnv
          : extraEnv // ignore: cast_nullable_to_non_nullable
              as dynamic,
      lastVerified: freezed == lastVerified
          ? _self.lastVerified
          : lastVerified // ignore: cast_nullable_to_non_nullable
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
