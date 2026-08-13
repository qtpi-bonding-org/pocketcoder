// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'permission_mode.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PermissionMode {
  String get id;
  String get name;
  String? get description;
  @JsonKey(unknownEnumValue: PermissionModeBaseSessionMode.unknown)
  PermissionModeBaseSessionMode get baseSessionMode;
  String? get user;
  bool? get isSystem;
  bool? get isDefault;

  /// Create a copy of PermissionMode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PermissionModeCopyWith<PermissionMode> get copyWith =>
      _$PermissionModeCopyWithImpl<PermissionMode>(
          this as PermissionMode, _$identity);

  /// Serializes this PermissionMode to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PermissionMode &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.baseSessionMode, baseSessionMode) ||
                other.baseSessionMode == baseSessionMode) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.isSystem, isSystem) ||
                other.isSystem == isSystem) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, description,
      baseSessionMode, user, isSystem, isDefault);

  @override
  String toString() {
    return 'PermissionMode(id: $id, name: $name, description: $description, baseSessionMode: $baseSessionMode, user: $user, isSystem: $isSystem, isDefault: $isDefault)';
  }
}

/// @nodoc
abstract mixin class $PermissionModeCopyWith<$Res> {
  factory $PermissionModeCopyWith(
          PermissionMode value, $Res Function(PermissionMode) _then) =
      _$PermissionModeCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      @JsonKey(unknownEnumValue: PermissionModeBaseSessionMode.unknown)
      PermissionModeBaseSessionMode baseSessionMode,
      String? user,
      bool? isSystem,
      bool? isDefault});
}

/// @nodoc
class _$PermissionModeCopyWithImpl<$Res>
    implements $PermissionModeCopyWith<$Res> {
  _$PermissionModeCopyWithImpl(this._self, this._then);

  final PermissionMode _self;
  final $Res Function(PermissionMode) _then;

  /// Create a copy of PermissionMode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? baseSessionMode = null,
    Object? user = freezed,
    Object? isSystem = freezed,
    Object? isDefault = freezed,
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
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      baseSessionMode: null == baseSessionMode
          ? _self.baseSessionMode
          : baseSessionMode // ignore: cast_nullable_to_non_nullable
              as PermissionModeBaseSessionMode,
      user: freezed == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String?,
      isSystem: freezed == isSystem
          ? _self.isSystem
          : isSystem // ignore: cast_nullable_to_non_nullable
              as bool?,
      isDefault: freezed == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// Adds pattern-matching-related methods to [PermissionMode].
extension PermissionModePatterns on PermissionMode {
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
    TResult Function(_PermissionMode value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PermissionMode() when $default != null:
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
    TResult Function(_PermissionMode value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionMode():
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
    TResult? Function(_PermissionMode value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionMode() when $default != null:
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
            String? description,
            @JsonKey(unknownEnumValue: PermissionModeBaseSessionMode.unknown)
            PermissionModeBaseSessionMode baseSessionMode,
            String? user,
            bool? isSystem,
            bool? isDefault)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PermissionMode() when $default != null:
        return $default(_that.id, _that.name, _that.description,
            _that.baseSessionMode, _that.user, _that.isSystem, _that.isDefault);
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
            String? description,
            @JsonKey(unknownEnumValue: PermissionModeBaseSessionMode.unknown)
            PermissionModeBaseSessionMode baseSessionMode,
            String? user,
            bool? isSystem,
            bool? isDefault)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionMode():
        return $default(_that.id, _that.name, _that.description,
            _that.baseSessionMode, _that.user, _that.isSystem, _that.isDefault);
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
            String? description,
            @JsonKey(unknownEnumValue: PermissionModeBaseSessionMode.unknown)
            PermissionModeBaseSessionMode baseSessionMode,
            String? user,
            bool? isSystem,
            bool? isDefault)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionMode() when $default != null:
        return $default(_that.id, _that.name, _that.description,
            _that.baseSessionMode, _that.user, _that.isSystem, _that.isDefault);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PermissionMode implements PermissionMode {
  const _PermissionMode(
      {required this.id,
      required this.name,
      this.description,
      @JsonKey(unknownEnumValue: PermissionModeBaseSessionMode.unknown)
      required this.baseSessionMode,
      this.user,
      this.isSystem,
      this.isDefault});
  factory _PermissionMode.fromJson(Map<String, dynamic> json) =>
      _$PermissionModeFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  @override
  @JsonKey(unknownEnumValue: PermissionModeBaseSessionMode.unknown)
  final PermissionModeBaseSessionMode baseSessionMode;
  @override
  final String? user;
  @override
  final bool? isSystem;
  @override
  final bool? isDefault;

  /// Create a copy of PermissionMode
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PermissionModeCopyWith<_PermissionMode> get copyWith =>
      __$PermissionModeCopyWithImpl<_PermissionMode>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PermissionModeToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PermissionMode &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.baseSessionMode, baseSessionMode) ||
                other.baseSessionMode == baseSessionMode) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.isSystem, isSystem) ||
                other.isSystem == isSystem) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, description,
      baseSessionMode, user, isSystem, isDefault);

  @override
  String toString() {
    return 'PermissionMode(id: $id, name: $name, description: $description, baseSessionMode: $baseSessionMode, user: $user, isSystem: $isSystem, isDefault: $isDefault)';
  }
}

/// @nodoc
abstract mixin class _$PermissionModeCopyWith<$Res>
    implements $PermissionModeCopyWith<$Res> {
  factory _$PermissionModeCopyWith(
          _PermissionMode value, $Res Function(_PermissionMode) _then) =
      __$PermissionModeCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      @JsonKey(unknownEnumValue: PermissionModeBaseSessionMode.unknown)
      PermissionModeBaseSessionMode baseSessionMode,
      String? user,
      bool? isSystem,
      bool? isDefault});
}

/// @nodoc
class __$PermissionModeCopyWithImpl<$Res>
    implements _$PermissionModeCopyWith<$Res> {
  __$PermissionModeCopyWithImpl(this._self, this._then);

  final _PermissionMode _self;
  final $Res Function(_PermissionMode) _then;

  /// Create a copy of PermissionMode
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? baseSessionMode = null,
    Object? user = freezed,
    Object? isSystem = freezed,
    Object? isDefault = freezed,
  }) {
    return _then(_PermissionMode(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      baseSessionMode: null == baseSessionMode
          ? _self.baseSessionMode
          : baseSessionMode // ignore: cast_nullable_to_non_nullable
              as PermissionModeBaseSessionMode,
      user: freezed == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String?,
      isSystem: freezed == isSystem
          ? _self.isSystem
          : isSystem // ignore: cast_nullable_to_non_nullable
              as bool?,
      isDefault: freezed == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

// dart format on
