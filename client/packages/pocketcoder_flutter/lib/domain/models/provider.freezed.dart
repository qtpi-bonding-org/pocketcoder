// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Provider {
  String get id;
  String get providerId;
  String get name;
  String? get apiKeyEnv;
  dynamic get apiKeyEnvs;
  String? get baseUrlEnv;
  DateTime? get syncedAt;

  /// Create a copy of Provider
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProviderCopyWith<Provider> get copyWith =>
      _$ProviderCopyWithImpl<Provider>(this as Provider, _$identity);

  /// Serializes this Provider to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Provider &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.providerId, providerId) ||
                other.providerId == providerId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.apiKeyEnv, apiKeyEnv) ||
                other.apiKeyEnv == apiKeyEnv) &&
            const DeepCollectionEquality()
                .equals(other.apiKeyEnvs, apiKeyEnvs) &&
            (identical(other.baseUrlEnv, baseUrlEnv) ||
                other.baseUrlEnv == baseUrlEnv) &&
            (identical(other.syncedAt, syncedAt) ||
                other.syncedAt == syncedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, providerId, name, apiKeyEnv,
      const DeepCollectionEquality().hash(apiKeyEnvs), baseUrlEnv, syncedAt);

  @override
  String toString() {
    return 'Provider(id: $id, providerId: $providerId, name: $name, apiKeyEnv: $apiKeyEnv, apiKeyEnvs: $apiKeyEnvs, baseUrlEnv: $baseUrlEnv, syncedAt: $syncedAt)';
  }
}

/// @nodoc
abstract mixin class $ProviderCopyWith<$Res> {
  factory $ProviderCopyWith(Provider value, $Res Function(Provider) _then) =
      _$ProviderCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String providerId,
      String name,
      String? apiKeyEnv,
      dynamic apiKeyEnvs,
      String? baseUrlEnv,
      DateTime? syncedAt});
}

/// @nodoc
class _$ProviderCopyWithImpl<$Res> implements $ProviderCopyWith<$Res> {
  _$ProviderCopyWithImpl(this._self, this._then);

  final Provider _self;
  final $Res Function(Provider) _then;

  /// Create a copy of Provider
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? providerId = null,
    Object? name = null,
    Object? apiKeyEnv = freezed,
    Object? apiKeyEnvs = freezed,
    Object? baseUrlEnv = freezed,
    Object? syncedAt = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      providerId: null == providerId
          ? _self.providerId
          : providerId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      apiKeyEnv: freezed == apiKeyEnv
          ? _self.apiKeyEnv
          : apiKeyEnv // ignore: cast_nullable_to_non_nullable
              as String?,
      apiKeyEnvs: freezed == apiKeyEnvs
          ? _self.apiKeyEnvs
          : apiKeyEnvs // ignore: cast_nullable_to_non_nullable
              as dynamic,
      baseUrlEnv: freezed == baseUrlEnv
          ? _self.baseUrlEnv
          : baseUrlEnv // ignore: cast_nullable_to_non_nullable
              as String?,
      syncedAt: freezed == syncedAt
          ? _self.syncedAt
          : syncedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Provider].
extension ProviderPatterns on Provider {
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
    TResult Function(_Provider value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Provider() when $default != null:
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
    TResult Function(_Provider value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Provider():
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
    TResult? Function(_Provider value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Provider() when $default != null:
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
            String providerId,
            String name,
            String? apiKeyEnv,
            dynamic apiKeyEnvs,
            String? baseUrlEnv,
            DateTime? syncedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Provider() when $default != null:
        return $default(_that.id, _that.providerId, _that.name, _that.apiKeyEnv,
            _that.apiKeyEnvs, _that.baseUrlEnv, _that.syncedAt);
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
            String providerId,
            String name,
            String? apiKeyEnv,
            dynamic apiKeyEnvs,
            String? baseUrlEnv,
            DateTime? syncedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Provider():
        return $default(_that.id, _that.providerId, _that.name, _that.apiKeyEnv,
            _that.apiKeyEnvs, _that.baseUrlEnv, _that.syncedAt);
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
            String providerId,
            String name,
            String? apiKeyEnv,
            dynamic apiKeyEnvs,
            String? baseUrlEnv,
            DateTime? syncedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Provider() when $default != null:
        return $default(_that.id, _that.providerId, _that.name, _that.apiKeyEnv,
            _that.apiKeyEnvs, _that.baseUrlEnv, _that.syncedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Provider implements Provider {
  const _Provider(
      {required this.id,
      required this.providerId,
      required this.name,
      this.apiKeyEnv,
      this.apiKeyEnvs,
      this.baseUrlEnv,
      this.syncedAt});
  factory _Provider.fromJson(Map<String, dynamic> json) =>
      _$ProviderFromJson(json);

  @override
  final String id;
  @override
  final String providerId;
  @override
  final String name;
  @override
  final String? apiKeyEnv;
  @override
  final dynamic apiKeyEnvs;
  @override
  final String? baseUrlEnv;
  @override
  final DateTime? syncedAt;

  /// Create a copy of Provider
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProviderCopyWith<_Provider> get copyWith =>
      __$ProviderCopyWithImpl<_Provider>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProviderToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Provider &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.providerId, providerId) ||
                other.providerId == providerId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.apiKeyEnv, apiKeyEnv) ||
                other.apiKeyEnv == apiKeyEnv) &&
            const DeepCollectionEquality()
                .equals(other.apiKeyEnvs, apiKeyEnvs) &&
            (identical(other.baseUrlEnv, baseUrlEnv) ||
                other.baseUrlEnv == baseUrlEnv) &&
            (identical(other.syncedAt, syncedAt) ||
                other.syncedAt == syncedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, providerId, name, apiKeyEnv,
      const DeepCollectionEquality().hash(apiKeyEnvs), baseUrlEnv, syncedAt);

  @override
  String toString() {
    return 'Provider(id: $id, providerId: $providerId, name: $name, apiKeyEnv: $apiKeyEnv, apiKeyEnvs: $apiKeyEnvs, baseUrlEnv: $baseUrlEnv, syncedAt: $syncedAt)';
  }
}

/// @nodoc
abstract mixin class _$ProviderCopyWith<$Res>
    implements $ProviderCopyWith<$Res> {
  factory _$ProviderCopyWith(_Provider value, $Res Function(_Provider) _then) =
      __$ProviderCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String providerId,
      String name,
      String? apiKeyEnv,
      dynamic apiKeyEnvs,
      String? baseUrlEnv,
      DateTime? syncedAt});
}

/// @nodoc
class __$ProviderCopyWithImpl<$Res> implements _$ProviderCopyWith<$Res> {
  __$ProviderCopyWithImpl(this._self, this._then);

  final _Provider _self;
  final $Res Function(_Provider) _then;

  /// Create a copy of Provider
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? providerId = null,
    Object? name = null,
    Object? apiKeyEnv = freezed,
    Object? apiKeyEnvs = freezed,
    Object? baseUrlEnv = freezed,
    Object? syncedAt = freezed,
  }) {
    return _then(_Provider(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      providerId: null == providerId
          ? _self.providerId
          : providerId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      apiKeyEnv: freezed == apiKeyEnv
          ? _self.apiKeyEnv
          : apiKeyEnv // ignore: cast_nullable_to_non_nullable
              as String?,
      apiKeyEnvs: freezed == apiKeyEnvs
          ? _self.apiKeyEnvs
          : apiKeyEnvs // ignore: cast_nullable_to_non_nullable
              as dynamic,
      baseUrlEnv: freezed == baseUrlEnv
          ? _self.baseUrlEnv
          : baseUrlEnv // ignore: cast_nullable_to_non_nullable
              as String?,
      syncedAt: freezed == syncedAt
          ? _self.syncedAt
          : syncedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
