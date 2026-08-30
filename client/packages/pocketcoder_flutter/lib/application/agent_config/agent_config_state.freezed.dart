// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_config_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentConfigState {
  UiFlowStatus get status;
  List<PocoConfig> get configs;
  List<Prompt> get prompts;
  List<PermissionMode> get permissionModes;
  Object? get error;

  /// Create a copy of AgentConfigState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentConfigStateCopyWith<AgentConfigState> get copyWith =>
      _$AgentConfigStateCopyWithImpl<AgentConfigState>(
          this as AgentConfigState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentConfigState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.configs, configs) &&
            const DeepCollectionEquality().equals(other.prompts, prompts) &&
            const DeepCollectionEquality()
                .equals(other.permissionModes, permissionModes) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(configs),
      const DeepCollectionEquality().hash(prompts),
      const DeepCollectionEquality().hash(permissionModes),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'AgentConfigState(status: $status, configs: $configs, prompts: $prompts, permissionModes: $permissionModes, error: $error)';
  }
}

/// @nodoc
abstract mixin class $AgentConfigStateCopyWith<$Res> {
  factory $AgentConfigStateCopyWith(
          AgentConfigState value, $Res Function(AgentConfigState) _then) =
      _$AgentConfigStateCopyWithImpl;
  @useResult
  $Res call(
      {UiFlowStatus status,
      List<PocoConfig> configs,
      List<Prompt> prompts,
      List<PermissionMode> permissionModes,
      Object? error});
}

/// @nodoc
class _$AgentConfigStateCopyWithImpl<$Res>
    implements $AgentConfigStateCopyWith<$Res> {
  _$AgentConfigStateCopyWithImpl(this._self, this._then);

  final AgentConfigState _self;
  final $Res Function(AgentConfigState) _then;

  /// Create a copy of AgentConfigState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? configs = null,
    Object? prompts = null,
    Object? permissionModes = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      configs: null == configs
          ? _self.configs
          : configs // ignore: cast_nullable_to_non_nullable
              as List<PocoConfig>,
      prompts: null == prompts
          ? _self.prompts
          : prompts // ignore: cast_nullable_to_non_nullable
              as List<Prompt>,
      permissionModes: null == permissionModes
          ? _self.permissionModes
          : permissionModes // ignore: cast_nullable_to_non_nullable
              as List<PermissionMode>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [AgentConfigState].
extension AgentConfigStatePatterns on AgentConfigState {
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
    TResult Function(_AgentConfigState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AgentConfigState() when $default != null:
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
    TResult Function(_AgentConfigState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentConfigState():
        return $default(_that);
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
    TResult? Function(_AgentConfigState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentConfigState() when $default != null:
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
            UiFlowStatus status,
            List<PocoConfig> configs,
            List<Prompt> prompts,
            List<PermissionMode> permissionModes,
            Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AgentConfigState() when $default != null:
        return $default(_that.status, _that.configs, _that.prompts,
            _that.permissionModes, _that.error);
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
            UiFlowStatus status,
            List<PocoConfig> configs,
            List<Prompt> prompts,
            List<PermissionMode> permissionModes,
            Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentConfigState():
        return $default(_that.status, _that.configs, _that.prompts,
            _that.permissionModes, _that.error);
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
            UiFlowStatus status,
            List<PocoConfig> configs,
            List<Prompt> prompts,
            List<PermissionMode> permissionModes,
            Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentConfigState() when $default != null:
        return $default(_that.status, _that.configs, _that.prompts,
            _that.permissionModes, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AgentConfigState extends AgentConfigState {
  const _AgentConfigState(
      {this.status = UiFlowStatus.idle,
      final List<PocoConfig> configs = const [],
      final List<Prompt> prompts = const [],
      final List<PermissionMode> permissionModes = const [],
      this.error})
      : _configs = configs,
        _prompts = prompts,
        _permissionModes = permissionModes,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  final List<PocoConfig> _configs;
  @override
  @JsonKey()
  List<PocoConfig> get configs {
    if (_configs is EqualUnmodifiableListView) return _configs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_configs);
  }

  final List<Prompt> _prompts;
  @override
  @JsonKey()
  List<Prompt> get prompts {
    if (_prompts is EqualUnmodifiableListView) return _prompts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_prompts);
  }

  final List<PermissionMode> _permissionModes;
  @override
  @JsonKey()
  List<PermissionMode> get permissionModes {
    if (_permissionModes is EqualUnmodifiableListView) return _permissionModes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_permissionModes);
  }

  @override
  final Object? error;

  /// Create a copy of AgentConfigState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AgentConfigStateCopyWith<_AgentConfigState> get copyWith =>
      __$AgentConfigStateCopyWithImpl<_AgentConfigState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AgentConfigState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._configs, _configs) &&
            const DeepCollectionEquality().equals(other._prompts, _prompts) &&
            const DeepCollectionEquality()
                .equals(other._permissionModes, _permissionModes) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_configs),
      const DeepCollectionEquality().hash(_prompts),
      const DeepCollectionEquality().hash(_permissionModes),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'AgentConfigState(status: $status, configs: $configs, prompts: $prompts, permissionModes: $permissionModes, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$AgentConfigStateCopyWith<$Res>
    implements $AgentConfigStateCopyWith<$Res> {
  factory _$AgentConfigStateCopyWith(
          _AgentConfigState value, $Res Function(_AgentConfigState) _then) =
      __$AgentConfigStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {UiFlowStatus status,
      List<PocoConfig> configs,
      List<Prompt> prompts,
      List<PermissionMode> permissionModes,
      Object? error});
}

/// @nodoc
class __$AgentConfigStateCopyWithImpl<$Res>
    implements _$AgentConfigStateCopyWith<$Res> {
  __$AgentConfigStateCopyWithImpl(this._self, this._then);

  final _AgentConfigState _self;
  final $Res Function(_AgentConfigState) _then;

  /// Create a copy of AgentConfigState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? configs = null,
    Object? prompts = null,
    Object? permissionModes = null,
    Object? error = freezed,
  }) {
    return _then(_AgentConfigState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      configs: null == configs
          ? _self._configs
          : configs // ignore: cast_nullable_to_non_nullable
              as List<PocoConfig>,
      prompts: null == prompts
          ? _self._prompts
          : prompts // ignore: cast_nullable_to_non_nullable
              as List<Prompt>,
      permissionModes: null == permissionModes
          ? _self._permissionModes
          : permissionModes // ignore: cast_nullable_to_non_nullable
              as List<PermissionMode>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
