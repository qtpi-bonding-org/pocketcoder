// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harness_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessProvider {
  String get id;
  String get harness;
  String get provider;
  bool? get supportsOauth;
  String? get oauthAuthenticator;
  String? get apiKeyEnvOverride;
  bool? get isPinned;
  DateTime? get created;
  DateTime? get updated;

  /// Create a copy of HarnessProvider
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HarnessProviderCopyWith<HarnessProvider> get copyWith =>
      _$HarnessProviderCopyWithImpl<HarnessProvider>(
          this as HarnessProvider, _$identity);

  /// Serializes this HarnessProvider to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HarnessProvider &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.supportsOauth, supportsOauth) ||
                other.supportsOauth == supportsOauth) &&
            (identical(other.oauthAuthenticator, oauthAuthenticator) ||
                other.oauthAuthenticator == oauthAuthenticator) &&
            (identical(other.apiKeyEnvOverride, apiKeyEnvOverride) ||
                other.apiKeyEnvOverride == apiKeyEnvOverride) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      harness,
      provider,
      supportsOauth,
      oauthAuthenticator,
      apiKeyEnvOverride,
      isPinned,
      created,
      updated);

  @override
  String toString() {
    return 'HarnessProvider(id: $id, harness: $harness, provider: $provider, supportsOauth: $supportsOauth, oauthAuthenticator: $oauthAuthenticator, apiKeyEnvOverride: $apiKeyEnvOverride, isPinned: $isPinned, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class $HarnessProviderCopyWith<$Res> {
  factory $HarnessProviderCopyWith(
          HarnessProvider value, $Res Function(HarnessProvider) _then) =
      _$HarnessProviderCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String harness,
      String provider,
      bool? supportsOauth,
      String? oauthAuthenticator,
      String? apiKeyEnvOverride,
      bool? isPinned,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class _$HarnessProviderCopyWithImpl<$Res>
    implements $HarnessProviderCopyWith<$Res> {
  _$HarnessProviderCopyWithImpl(this._self, this._then);

  final HarnessProvider _self;
  final $Res Function(HarnessProvider) _then;

  /// Create a copy of HarnessProvider
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? harness = null,
    Object? provider = null,
    Object? supportsOauth = freezed,
    Object? oauthAuthenticator = freezed,
    Object? apiKeyEnvOverride = freezed,
    Object? isPinned = freezed,
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
      supportsOauth: freezed == supportsOauth
          ? _self.supportsOauth
          : supportsOauth // ignore: cast_nullable_to_non_nullable
              as bool?,
      oauthAuthenticator: freezed == oauthAuthenticator
          ? _self.oauthAuthenticator
          : oauthAuthenticator // ignore: cast_nullable_to_non_nullable
              as String?,
      apiKeyEnvOverride: freezed == apiKeyEnvOverride
          ? _self.apiKeyEnvOverride
          : apiKeyEnvOverride // ignore: cast_nullable_to_non_nullable
              as String?,
      isPinned: freezed == isPinned
          ? _self.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool?,
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

/// Adds pattern-matching-related methods to [HarnessProvider].
extension HarnessProviderPatterns on HarnessProvider {
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
    TResult Function(_HarnessProvider value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessProvider() when $default != null:
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
    TResult Function(_HarnessProvider value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessProvider():
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
    TResult? Function(_HarnessProvider value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessProvider() when $default != null:
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
            bool? supportsOauth,
            String? oauthAuthenticator,
            String? apiKeyEnvOverride,
            bool? isPinned,
            DateTime? created,
            DateTime? updated)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessProvider() when $default != null:
        return $default(
            _that.id,
            _that.harness,
            _that.provider,
            _that.supportsOauth,
            _that.oauthAuthenticator,
            _that.apiKeyEnvOverride,
            _that.isPinned,
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
            bool? supportsOauth,
            String? oauthAuthenticator,
            String? apiKeyEnvOverride,
            bool? isPinned,
            DateTime? created,
            DateTime? updated)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessProvider():
        return $default(
            _that.id,
            _that.harness,
            _that.provider,
            _that.supportsOauth,
            _that.oauthAuthenticator,
            _that.apiKeyEnvOverride,
            _that.isPinned,
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
            bool? supportsOauth,
            String? oauthAuthenticator,
            String? apiKeyEnvOverride,
            bool? isPinned,
            DateTime? created,
            DateTime? updated)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessProvider() when $default != null:
        return $default(
            _that.id,
            _that.harness,
            _that.provider,
            _that.supportsOauth,
            _that.oauthAuthenticator,
            _that.apiKeyEnvOverride,
            _that.isPinned,
            _that.created,
            _that.updated);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _HarnessProvider implements HarnessProvider {
  const _HarnessProvider(
      {required this.id,
      required this.harness,
      required this.provider,
      this.supportsOauth,
      this.oauthAuthenticator,
      this.apiKeyEnvOverride,
      this.isPinned,
      this.created,
      this.updated});
  factory _HarnessProvider.fromJson(Map<String, dynamic> json) =>
      _$HarnessProviderFromJson(json);

  @override
  final String id;
  @override
  final String harness;
  @override
  final String provider;
  @override
  final bool? supportsOauth;
  @override
  final String? oauthAuthenticator;
  @override
  final String? apiKeyEnvOverride;
  @override
  final bool? isPinned;
  @override
  final DateTime? created;
  @override
  final DateTime? updated;

  /// Create a copy of HarnessProvider
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HarnessProviderCopyWith<_HarnessProvider> get copyWith =>
      __$HarnessProviderCopyWithImpl<_HarnessProvider>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HarnessProviderToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HarnessProvider &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.supportsOauth, supportsOauth) ||
                other.supportsOauth == supportsOauth) &&
            (identical(other.oauthAuthenticator, oauthAuthenticator) ||
                other.oauthAuthenticator == oauthAuthenticator) &&
            (identical(other.apiKeyEnvOverride, apiKeyEnvOverride) ||
                other.apiKeyEnvOverride == apiKeyEnvOverride) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned) &&
            (identical(other.created, created) || other.created == created) &&
            (identical(other.updated, updated) || other.updated == updated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      harness,
      provider,
      supportsOauth,
      oauthAuthenticator,
      apiKeyEnvOverride,
      isPinned,
      created,
      updated);

  @override
  String toString() {
    return 'HarnessProvider(id: $id, harness: $harness, provider: $provider, supportsOauth: $supportsOauth, oauthAuthenticator: $oauthAuthenticator, apiKeyEnvOverride: $apiKeyEnvOverride, isPinned: $isPinned, created: $created, updated: $updated)';
  }
}

/// @nodoc
abstract mixin class _$HarnessProviderCopyWith<$Res>
    implements $HarnessProviderCopyWith<$Res> {
  factory _$HarnessProviderCopyWith(
          _HarnessProvider value, $Res Function(_HarnessProvider) _then) =
      __$HarnessProviderCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String harness,
      String provider,
      bool? supportsOauth,
      String? oauthAuthenticator,
      String? apiKeyEnvOverride,
      bool? isPinned,
      DateTime? created,
      DateTime? updated});
}

/// @nodoc
class __$HarnessProviderCopyWithImpl<$Res>
    implements _$HarnessProviderCopyWith<$Res> {
  __$HarnessProviderCopyWithImpl(this._self, this._then);

  final _HarnessProvider _self;
  final $Res Function(_HarnessProvider) _then;

  /// Create a copy of HarnessProvider
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? harness = null,
    Object? provider = null,
    Object? supportsOauth = freezed,
    Object? oauthAuthenticator = freezed,
    Object? apiKeyEnvOverride = freezed,
    Object? isPinned = freezed,
    Object? created = freezed,
    Object? updated = freezed,
  }) {
    return _then(_HarnessProvider(
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
      supportsOauth: freezed == supportsOauth
          ? _self.supportsOauth
          : supportsOauth // ignore: cast_nullable_to_non_nullable
              as bool?,
      oauthAuthenticator: freezed == oauthAuthenticator
          ? _self.oauthAuthenticator
          : oauthAuthenticator // ignore: cast_nullable_to_non_nullable
              as String?,
      apiKeyEnvOverride: freezed == apiKeyEnvOverride
          ? _self.apiKeyEnvOverride
          : apiKeyEnvOverride // ignore: cast_nullable_to_non_nullable
              as String?,
      isPinned: freezed == isPinned
          ? _self.isPinned
          : isPinned // ignore: cast_nullable_to_non_nullable
              as bool?,
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
