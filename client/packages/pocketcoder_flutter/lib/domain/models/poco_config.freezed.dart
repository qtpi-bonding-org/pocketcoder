// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'poco_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PocoConfig {
  String get id;
  String get name;
  String? get systemPrompt;
  dynamic get workspaceFolders;
  dynamic get acpMcpServers;
  bool? get isDefault;
  String? get permissionMode;

  /// Create a copy of PocoConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PocoConfigCopyWith<PocoConfig> get copyWith =>
      _$PocoConfigCopyWithImpl<PocoConfig>(this as PocoConfig, _$identity);

  /// Serializes this PocoConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PocoConfig &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.systemPrompt, systemPrompt) ||
                other.systemPrompt == systemPrompt) &&
            const DeepCollectionEquality()
                .equals(other.workspaceFolders, workspaceFolders) &&
            const DeepCollectionEquality()
                .equals(other.acpMcpServers, acpMcpServers) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.permissionMode, permissionMode) ||
                other.permissionMode == permissionMode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      systemPrompt,
      const DeepCollectionEquality().hash(workspaceFolders),
      const DeepCollectionEquality().hash(acpMcpServers),
      isDefault,
      permissionMode);

  @override
  String toString() {
    return 'PocoConfig(id: $id, name: $name, systemPrompt: $systemPrompt, workspaceFolders: $workspaceFolders, acpMcpServers: $acpMcpServers, isDefault: $isDefault, permissionMode: $permissionMode)';
  }
}

/// @nodoc
abstract mixin class $PocoConfigCopyWith<$Res> {
  factory $PocoConfigCopyWith(
          PocoConfig value, $Res Function(PocoConfig) _then) =
      _$PocoConfigCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String? systemPrompt,
      dynamic workspaceFolders,
      dynamic acpMcpServers,
      bool? isDefault,
      String? permissionMode});
}

/// @nodoc
class _$PocoConfigCopyWithImpl<$Res> implements $PocoConfigCopyWith<$Res> {
  _$PocoConfigCopyWithImpl(this._self, this._then);

  final PocoConfig _self;
  final $Res Function(PocoConfig) _then;

  /// Create a copy of PocoConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? systemPrompt = freezed,
    Object? workspaceFolders = freezed,
    Object? acpMcpServers = freezed,
    Object? isDefault = freezed,
    Object? permissionMode = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      systemPrompt: freezed == systemPrompt
          ? _self.systemPrompt
          : systemPrompt // ignore: cast_nullable_to_non_nullable
              as String?,
      workspaceFolders: freezed == workspaceFolders
          ? _self.workspaceFolders
          : workspaceFolders // ignore: cast_nullable_to_non_nullable
              as dynamic,
      acpMcpServers: freezed == acpMcpServers
          ? _self.acpMcpServers
          : acpMcpServers // ignore: cast_nullable_to_non_nullable
              as dynamic,
      isDefault: freezed == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool?,
      permissionMode: freezed == permissionMode
          ? _self.permissionMode
          : permissionMode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [PocoConfig].
extension PocoConfigPatterns on PocoConfig {
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
    TResult Function(_PocoConfig value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocoConfig() when $default != null:
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
    TResult Function(_PocoConfig value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocoConfig():
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
    TResult? Function(_PocoConfig value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocoConfig() when $default != null:
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
            String name,
            String? systemPrompt,
            dynamic workspaceFolders,
            dynamic acpMcpServers,
            bool? isDefault,
            String? permissionMode)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocoConfig() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.systemPrompt,
            _that.workspaceFolders,
            _that.acpMcpServers,
            _that.isDefault,
            _that.permissionMode);
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
            String name,
            String? systemPrompt,
            dynamic workspaceFolders,
            dynamic acpMcpServers,
            bool? isDefault,
            String? permissionMode)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocoConfig():
        return $default(
            _that.id,
            _that.name,
            _that.systemPrompt,
            _that.workspaceFolders,
            _that.acpMcpServers,
            _that.isDefault,
            _that.permissionMode);
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
            String name,
            String? systemPrompt,
            dynamic workspaceFolders,
            dynamic acpMcpServers,
            bool? isDefault,
            String? permissionMode)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocoConfig() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.systemPrompt,
            _that.workspaceFolders,
            _that.acpMcpServers,
            _that.isDefault,
            _that.permissionMode);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PocoConfig implements PocoConfig {
  const _PocoConfig(
      {required this.id,
      required this.name,
      this.systemPrompt,
      this.workspaceFolders,
      this.acpMcpServers,
      this.isDefault,
      this.permissionMode});
  factory _PocoConfig.fromJson(Map<String, dynamic> json) =>
      _$PocoConfigFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? systemPrompt;
  @override
  final dynamic workspaceFolders;
  @override
  final dynamic acpMcpServers;
  @override
  final bool? isDefault;
  @override
  final String? permissionMode;

  /// Create a copy of PocoConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PocoConfigCopyWith<_PocoConfig> get copyWith =>
      __$PocoConfigCopyWithImpl<_PocoConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PocoConfigToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PocoConfig &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.systemPrompt, systemPrompt) ||
                other.systemPrompt == systemPrompt) &&
            const DeepCollectionEquality()
                .equals(other.workspaceFolders, workspaceFolders) &&
            const DeepCollectionEquality()
                .equals(other.acpMcpServers, acpMcpServers) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.permissionMode, permissionMode) ||
                other.permissionMode == permissionMode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      systemPrompt,
      const DeepCollectionEquality().hash(workspaceFolders),
      const DeepCollectionEquality().hash(acpMcpServers),
      isDefault,
      permissionMode);

  @override
  String toString() {
    return 'PocoConfig(id: $id, name: $name, systemPrompt: $systemPrompt, workspaceFolders: $workspaceFolders, acpMcpServers: $acpMcpServers, isDefault: $isDefault, permissionMode: $permissionMode)';
  }
}

/// @nodoc
abstract mixin class _$PocoConfigCopyWith<$Res>
    implements $PocoConfigCopyWith<$Res> {
  factory _$PocoConfigCopyWith(
          _PocoConfig value, $Res Function(_PocoConfig) _then) =
      __$PocoConfigCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? systemPrompt,
      dynamic workspaceFolders,
      dynamic acpMcpServers,
      bool? isDefault,
      String? permissionMode});
}

/// @nodoc
class __$PocoConfigCopyWithImpl<$Res> implements _$PocoConfigCopyWith<$Res> {
  __$PocoConfigCopyWithImpl(this._self, this._then);

  final _PocoConfig _self;
  final $Res Function(_PocoConfig) _then;

  /// Create a copy of PocoConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? systemPrompt = freezed,
    Object? workspaceFolders = freezed,
    Object? acpMcpServers = freezed,
    Object? isDefault = freezed,
    Object? permissionMode = freezed,
  }) {
    return _then(_PocoConfig(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      systemPrompt: freezed == systemPrompt
          ? _self.systemPrompt
          : systemPrompt // ignore: cast_nullable_to_non_nullable
              as String?,
      workspaceFolders: freezed == workspaceFolders
          ? _self.workspaceFolders
          : workspaceFolders // ignore: cast_nullable_to_non_nullable
              as dynamic,
      acpMcpServers: freezed == acpMcpServers
          ? _self.acpMcpServers
          : acpMcpServers // ignore: cast_nullable_to_non_nullable
              as dynamic,
      isDefault: freezed == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool?,
      permissionMode: freezed == permissionMode
          ? _self.permissionMode
          : permissionMode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
