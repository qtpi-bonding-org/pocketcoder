// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cognee_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CogneeConfig {
  String get id;
  String get llmProvider;
  String get llmModel;
  String? get llmBaseUrl;
  String get llmApiKey;

  /// Create a copy of CogneeConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CogneeConfigCopyWith<CogneeConfig> get copyWith =>
      _$CogneeConfigCopyWithImpl<CogneeConfig>(
          this as CogneeConfig, _$identity);

  /// Serializes this CogneeConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CogneeConfig &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.llmProvider, llmProvider) ||
                other.llmProvider == llmProvider) &&
            (identical(other.llmModel, llmModel) ||
                other.llmModel == llmModel) &&
            (identical(other.llmBaseUrl, llmBaseUrl) ||
                other.llmBaseUrl == llmBaseUrl) &&
            (identical(other.llmApiKey, llmApiKey) ||
                other.llmApiKey == llmApiKey));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, llmProvider, llmModel, llmBaseUrl, llmApiKey);

  @override
  String toString() {
    return 'CogneeConfig(id: $id, llmProvider: $llmProvider, llmModel: $llmModel, llmBaseUrl: $llmBaseUrl, llmApiKey: $llmApiKey)';
  }
}

/// @nodoc
abstract mixin class $CogneeConfigCopyWith<$Res> {
  factory $CogneeConfigCopyWith(
          CogneeConfig value, $Res Function(CogneeConfig) _then) =
      _$CogneeConfigCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String llmProvider,
      String llmModel,
      String? llmBaseUrl,
      String llmApiKey});
}

/// @nodoc
class _$CogneeConfigCopyWithImpl<$Res> implements $CogneeConfigCopyWith<$Res> {
  _$CogneeConfigCopyWithImpl(this._self, this._then);

  final CogneeConfig _self;
  final $Res Function(CogneeConfig) _then;

  /// Create a copy of CogneeConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? llmProvider = null,
    Object? llmModel = null,
    Object? llmBaseUrl = freezed,
    Object? llmApiKey = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      llmProvider: null == llmProvider
          ? _self.llmProvider
          : llmProvider // ignore: cast_nullable_to_non_nullable
              as String,
      llmModel: null == llmModel
          ? _self.llmModel
          : llmModel // ignore: cast_nullable_to_non_nullable
              as String,
      llmBaseUrl: freezed == llmBaseUrl
          ? _self.llmBaseUrl
          : llmBaseUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      llmApiKey: null == llmApiKey
          ? _self.llmApiKey
          : llmApiKey // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [CogneeConfig].
extension CogneeConfigPatterns on CogneeConfig {
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
    TResult Function(_CogneeConfig value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CogneeConfig() when $default != null:
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
    TResult Function(_CogneeConfig value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CogneeConfig():
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
    TResult? Function(_CogneeConfig value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CogneeConfig() when $default != null:
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
    TResult Function(String id, String llmProvider, String llmModel,
            String? llmBaseUrl, String llmApiKey)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CogneeConfig() when $default != null:
        return $default(_that.id, _that.llmProvider, _that.llmModel,
            _that.llmBaseUrl, _that.llmApiKey);
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
    TResult Function(String id, String llmProvider, String llmModel,
            String? llmBaseUrl, String llmApiKey)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CogneeConfig():
        return $default(_that.id, _that.llmProvider, _that.llmModel,
            _that.llmBaseUrl, _that.llmApiKey);
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
    TResult? Function(String id, String llmProvider, String llmModel,
            String? llmBaseUrl, String llmApiKey)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CogneeConfig() when $default != null:
        return $default(_that.id, _that.llmProvider, _that.llmModel,
            _that.llmBaseUrl, _that.llmApiKey);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CogneeConfig implements CogneeConfig {
  const _CogneeConfig(
      {required this.id,
      required this.llmProvider,
      required this.llmModel,
      this.llmBaseUrl,
      required this.llmApiKey});
  factory _CogneeConfig.fromJson(Map<String, dynamic> json) =>
      _$CogneeConfigFromJson(json);

  @override
  final String id;
  @override
  final String llmProvider;
  @override
  final String llmModel;
  @override
  final String? llmBaseUrl;
  @override
  final String llmApiKey;

  /// Create a copy of CogneeConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CogneeConfigCopyWith<_CogneeConfig> get copyWith =>
      __$CogneeConfigCopyWithImpl<_CogneeConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CogneeConfigToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CogneeConfig &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.llmProvider, llmProvider) ||
                other.llmProvider == llmProvider) &&
            (identical(other.llmModel, llmModel) ||
                other.llmModel == llmModel) &&
            (identical(other.llmBaseUrl, llmBaseUrl) ||
                other.llmBaseUrl == llmBaseUrl) &&
            (identical(other.llmApiKey, llmApiKey) ||
                other.llmApiKey == llmApiKey));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, llmProvider, llmModel, llmBaseUrl, llmApiKey);

  @override
  String toString() {
    return 'CogneeConfig(id: $id, llmProvider: $llmProvider, llmModel: $llmModel, llmBaseUrl: $llmBaseUrl, llmApiKey: $llmApiKey)';
  }
}

/// @nodoc
abstract mixin class _$CogneeConfigCopyWith<$Res>
    implements $CogneeConfigCopyWith<$Res> {
  factory _$CogneeConfigCopyWith(
          _CogneeConfig value, $Res Function(_CogneeConfig) _then) =
      __$CogneeConfigCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String llmProvider,
      String llmModel,
      String? llmBaseUrl,
      String llmApiKey});
}

/// @nodoc
class __$CogneeConfigCopyWithImpl<$Res>
    implements _$CogneeConfigCopyWith<$Res> {
  __$CogneeConfigCopyWithImpl(this._self, this._then);

  final _CogneeConfig _self;
  final $Res Function(_CogneeConfig) _then;

  /// Create a copy of CogneeConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? llmProvider = null,
    Object? llmModel = null,
    Object? llmBaseUrl = freezed,
    Object? llmApiKey = null,
  }) {
    return _then(_CogneeConfig(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      llmProvider: null == llmProvider
          ? _self.llmProvider
          : llmProvider // ignore: cast_nullable_to_non_nullable
              as String,
      llmModel: null == llmModel
          ? _self.llmModel
          : llmModel // ignore: cast_nullable_to_non_nullable
              as String,
      llmBaseUrl: freezed == llmBaseUrl
          ? _self.llmBaseUrl
          : llmBaseUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      llmApiKey: null == llmApiKey
          ? _self.llmApiKey
          : llmApiKey // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
