// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider_key.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProviderKey {
  String get id;
  String get user;
  String get provider;
  dynamic get envVars;

  /// Create a copy of ProviderKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProviderKeyCopyWith<ProviderKey> get copyWith =>
      _$ProviderKeyCopyWithImpl<ProviderKey>(this as ProviderKey, _$identity);

  /// Serializes this ProviderKey to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProviderKey &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            const DeepCollectionEquality().equals(other.envVars, envVars));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, user, provider,
      const DeepCollectionEquality().hash(envVars));

  @override
  String toString() {
    return 'ProviderKey(id: $id, user: $user, provider: $provider, envVars: $envVars)';
  }
}

/// @nodoc
abstract mixin class $ProviderKeyCopyWith<$Res> {
  factory $ProviderKeyCopyWith(
          ProviderKey value, $Res Function(ProviderKey) _then) =
      _$ProviderKeyCopyWithImpl;
  @useResult
  $Res call({String id, String user, String provider, dynamic envVars});
}

/// @nodoc
class _$ProviderKeyCopyWithImpl<$Res> implements $ProviderKeyCopyWith<$Res> {
  _$ProviderKeyCopyWithImpl(this._self, this._then);

  final ProviderKey _self;
  final $Res Function(ProviderKey) _then;

  /// Create a copy of ProviderKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? provider = null,
    Object? envVars = freezed,
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
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      envVars: freezed == envVars
          ? _self.envVars
          : envVars // ignore: cast_nullable_to_non_nullable
              as dynamic,
    ));
  }
}

/// Adds pattern-matching-related methods to [ProviderKey].
extension ProviderKeyPatterns on ProviderKey {
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
    TResult Function(_ProviderKey value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProviderKey() when $default != null:
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
    TResult Function(_ProviderKey value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderKey():
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
    TResult? Function(_ProviderKey value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderKey() when $default != null:
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
    TResult Function(String id, String user, String provider, dynamic envVars)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProviderKey() when $default != null:
        return $default(_that.id, _that.user, _that.provider, _that.envVars);
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
    TResult Function(String id, String user, String provider, dynamic envVars)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderKey():
        return $default(_that.id, _that.user, _that.provider, _that.envVars);
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
    TResult? Function(String id, String user, String provider, dynamic envVars)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderKey() when $default != null:
        return $default(_that.id, _that.user, _that.provider, _that.envVars);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ProviderKey implements ProviderKey {
  const _ProviderKey(
      {required this.id,
      required this.user,
      required this.provider,
      this.envVars});
  factory _ProviderKey.fromJson(Map<String, dynamic> json) =>
      _$ProviderKeyFromJson(json);

  @override
  final String id;
  @override
  final String user;
  @override
  final String provider;
  @override
  final dynamic envVars;

  /// Create a copy of ProviderKey
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProviderKeyCopyWith<_ProviderKey> get copyWith =>
      __$ProviderKeyCopyWithImpl<_ProviderKey>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProviderKeyToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProviderKey &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            const DeepCollectionEquality().equals(other.envVars, envVars));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, user, provider,
      const DeepCollectionEquality().hash(envVars));

  @override
  String toString() {
    return 'ProviderKey(id: $id, user: $user, provider: $provider, envVars: $envVars)';
  }
}

/// @nodoc
abstract mixin class _$ProviderKeyCopyWith<$Res>
    implements $ProviderKeyCopyWith<$Res> {
  factory _$ProviderKeyCopyWith(
          _ProviderKey value, $Res Function(_ProviderKey) _then) =
      __$ProviderKeyCopyWithImpl;
  @override
  @useResult
  $Res call({String id, String user, String provider, dynamic envVars});
}

/// @nodoc
class __$ProviderKeyCopyWithImpl<$Res> implements _$ProviderKeyCopyWith<$Res> {
  __$ProviderKeyCopyWithImpl(this._self, this._then);

  final _ProviderKey _self;
  final $Res Function(_ProviderKey) _then;

  /// Create a copy of ProviderKey
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? provider = null,
    Object? envVars = freezed,
  }) {
    return _then(_ProviderKey(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      envVars: freezed == envVars
          ? _self.envVars
          : envVars // ignore: cast_nullable_to_non_nullable
              as dynamic,
    ));
  }
}

// dart format on
