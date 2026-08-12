// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tool_permission.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ToolPermission {
  String get id;
  String get tool;
  String get pattern;
  @JsonKey(unknownEnumValue: ToolPermissionAction.unknown)
  ToolPermissionAction get action;
  bool? get active;
  String? get pocoConfig;

  /// Create a copy of ToolPermission
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ToolPermissionCopyWith<ToolPermission> get copyWith =>
      _$ToolPermissionCopyWithImpl<ToolPermission>(
          this as ToolPermission, _$identity);

  /// Serializes this ToolPermission to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ToolPermission &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tool, tool) || other.tool == tool) &&
            (identical(other.pattern, pattern) || other.pattern == pattern) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.pocoConfig, pocoConfig) ||
                other.pocoConfig == pocoConfig));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, tool, pattern, action, active, pocoConfig);

  @override
  String toString() {
    return 'ToolPermission(id: $id, tool: $tool, pattern: $pattern, action: $action, active: $active, pocoConfig: $pocoConfig)';
  }
}

/// @nodoc
abstract mixin class $ToolPermissionCopyWith<$Res> {
  factory $ToolPermissionCopyWith(
          ToolPermission value, $Res Function(ToolPermission) _then) =
      _$ToolPermissionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String tool,
      String pattern,
      @JsonKey(unknownEnumValue: ToolPermissionAction.unknown)
      ToolPermissionAction action,
      bool? active,
      String? pocoConfig});
}

/// @nodoc
class _$ToolPermissionCopyWithImpl<$Res>
    implements $ToolPermissionCopyWith<$Res> {
  _$ToolPermissionCopyWithImpl(this._self, this._then);

  final ToolPermission _self;
  final $Res Function(ToolPermission) _then;

  /// Create a copy of ToolPermission
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tool = null,
    Object? pattern = null,
    Object? action = null,
    Object? active = freezed,
    Object? pocoConfig = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tool: null == tool
          ? _self.tool
          : tool // ignore: cast_nullable_to_non_nullable
              as String,
      pattern: null == pattern
          ? _self.pattern
          : pattern // ignore: cast_nullable_to_non_nullable
              as String,
      action: null == action
          ? _self.action
          : action // ignore: cast_nullable_to_non_nullable
              as ToolPermissionAction,
      active: freezed == active
          ? _self.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool?,
      pocoConfig: freezed == pocoConfig
          ? _self.pocoConfig
          : pocoConfig // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ToolPermission].
extension ToolPermissionPatterns on ToolPermission {
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
    TResult Function(_ToolPermission value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ToolPermission() when $default != null:
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
    TResult Function(_ToolPermission value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ToolPermission():
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
    TResult? Function(_ToolPermission value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ToolPermission() when $default != null:
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
            String tool,
            String pattern,
            @JsonKey(unknownEnumValue: ToolPermissionAction.unknown)
            ToolPermissionAction action,
            bool? active,
            String? pocoConfig)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ToolPermission() when $default != null:
        return $default(_that.id, _that.tool, _that.pattern, _that.action,
            _that.active, _that.pocoConfig);
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
            String tool,
            String pattern,
            @JsonKey(unknownEnumValue: ToolPermissionAction.unknown)
            ToolPermissionAction action,
            bool? active,
            String? pocoConfig)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ToolPermission():
        return $default(_that.id, _that.tool, _that.pattern, _that.action,
            _that.active, _that.pocoConfig);
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
            String tool,
            String pattern,
            @JsonKey(unknownEnumValue: ToolPermissionAction.unknown)
            ToolPermissionAction action,
            bool? active,
            String? pocoConfig)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ToolPermission() when $default != null:
        return $default(_that.id, _that.tool, _that.pattern, _that.action,
            _that.active, _that.pocoConfig);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ToolPermission implements ToolPermission {
  const _ToolPermission(
      {required this.id,
      required this.tool,
      required this.pattern,
      @JsonKey(unknownEnumValue: ToolPermissionAction.unknown)
      required this.action,
      this.active,
      this.pocoConfig});
  factory _ToolPermission.fromJson(Map<String, dynamic> json) =>
      _$ToolPermissionFromJson(json);

  @override
  final String id;
  @override
  final String tool;
  @override
  final String pattern;
  @override
  @JsonKey(unknownEnumValue: ToolPermissionAction.unknown)
  final ToolPermissionAction action;
  @override
  final bool? active;
  @override
  final String? pocoConfig;

  /// Create a copy of ToolPermission
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ToolPermissionCopyWith<_ToolPermission> get copyWith =>
      __$ToolPermissionCopyWithImpl<_ToolPermission>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ToolPermissionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ToolPermission &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tool, tool) || other.tool == tool) &&
            (identical(other.pattern, pattern) || other.pattern == pattern) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.pocoConfig, pocoConfig) ||
                other.pocoConfig == pocoConfig));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, tool, pattern, action, active, pocoConfig);

  @override
  String toString() {
    return 'ToolPermission(id: $id, tool: $tool, pattern: $pattern, action: $action, active: $active, pocoConfig: $pocoConfig)';
  }
}

/// @nodoc
abstract mixin class _$ToolPermissionCopyWith<$Res>
    implements $ToolPermissionCopyWith<$Res> {
  factory _$ToolPermissionCopyWith(
          _ToolPermission value, $Res Function(_ToolPermission) _then) =
      __$ToolPermissionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String tool,
      String pattern,
      @JsonKey(unknownEnumValue: ToolPermissionAction.unknown)
      ToolPermissionAction action,
      bool? active,
      String? pocoConfig});
}

/// @nodoc
class __$ToolPermissionCopyWithImpl<$Res>
    implements _$ToolPermissionCopyWith<$Res> {
  __$ToolPermissionCopyWithImpl(this._self, this._then);

  final _ToolPermission _self;
  final $Res Function(_ToolPermission) _then;

  /// Create a copy of ToolPermission
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? tool = null,
    Object? pattern = null,
    Object? action = null,
    Object? active = freezed,
    Object? pocoConfig = freezed,
  }) {
    return _then(_ToolPermission(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tool: null == tool
          ? _self.tool
          : tool // ignore: cast_nullable_to_non_nullable
              as String,
      pattern: null == pattern
          ? _self.pattern
          : pattern // ignore: cast_nullable_to_non_nullable
              as String,
      action: null == action
          ? _self.action
          : action // ignore: cast_nullable_to_non_nullable
              as ToolPermissionAction,
      active: freezed == active
          ? _self.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool?,
      pocoConfig: freezed == pocoConfig
          ? _self.pocoConfig
          : pocoConfig // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
