// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'permission_mode_rules_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PermissionModeRulesState {
  UiFlowStatus get status;
  List<ToolPermission> get rules;
  Object? get error;

  /// Create a copy of PermissionModeRulesState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PermissionModeRulesStateCopyWith<PermissionModeRulesState> get copyWith =>
      _$PermissionModeRulesStateCopyWithImpl<PermissionModeRulesState>(
          this as PermissionModeRulesState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PermissionModeRulesState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.rules, rules) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(rules),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'PermissionModeRulesState(status: $status, rules: $rules, error: $error)';
  }
}

/// @nodoc
abstract mixin class $PermissionModeRulesStateCopyWith<$Res> {
  factory $PermissionModeRulesStateCopyWith(PermissionModeRulesState value,
          $Res Function(PermissionModeRulesState) _then) =
      _$PermissionModeRulesStateCopyWithImpl;
  @useResult
  $Res call({UiFlowStatus status, List<ToolPermission> rules, Object? error});
}

/// @nodoc
class _$PermissionModeRulesStateCopyWithImpl<$Res>
    implements $PermissionModeRulesStateCopyWith<$Res> {
  _$PermissionModeRulesStateCopyWithImpl(this._self, this._then);

  final PermissionModeRulesState _self;
  final $Res Function(PermissionModeRulesState) _then;

  /// Create a copy of PermissionModeRulesState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? rules = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      rules: null == rules
          ? _self.rules
          : rules // ignore: cast_nullable_to_non_nullable
              as List<ToolPermission>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [PermissionModeRulesState].
extension PermissionModeRulesStatePatterns on PermissionModeRulesState {
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
    TResult Function(_PermissionModeRulesState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PermissionModeRulesState() when $default != null:
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
    TResult Function(_PermissionModeRulesState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionModeRulesState():
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
    TResult? Function(_PermissionModeRulesState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionModeRulesState() when $default != null:
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
            UiFlowStatus status, List<ToolPermission> rules, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PermissionModeRulesState() when $default != null:
        return $default(_that.status, _that.rules, _that.error);
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
            UiFlowStatus status, List<ToolPermission> rules, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionModeRulesState():
        return $default(_that.status, _that.rules, _that.error);
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
            UiFlowStatus status, List<ToolPermission> rules, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionModeRulesState() when $default != null:
        return $default(_that.status, _that.rules, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PermissionModeRulesState extends PermissionModeRulesState {
  const _PermissionModeRulesState(
      {this.status = UiFlowStatus.idle,
      final List<ToolPermission> rules = const [],
      this.error})
      : _rules = rules,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  final List<ToolPermission> _rules;
  @override
  @JsonKey()
  List<ToolPermission> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  @override
  final Object? error;

  /// Create a copy of PermissionModeRulesState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PermissionModeRulesStateCopyWith<_PermissionModeRulesState> get copyWith =>
      __$PermissionModeRulesStateCopyWithImpl<_PermissionModeRulesState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PermissionModeRulesState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_rules),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'PermissionModeRulesState(status: $status, rules: $rules, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$PermissionModeRulesStateCopyWith<$Res>
    implements $PermissionModeRulesStateCopyWith<$Res> {
  factory _$PermissionModeRulesStateCopyWith(_PermissionModeRulesState value,
          $Res Function(_PermissionModeRulesState) _then) =
      __$PermissionModeRulesStateCopyWithImpl;
  @override
  @useResult
  $Res call({UiFlowStatus status, List<ToolPermission> rules, Object? error});
}

/// @nodoc
class __$PermissionModeRulesStateCopyWithImpl<$Res>
    implements _$PermissionModeRulesStateCopyWith<$Res> {
  __$PermissionModeRulesStateCopyWithImpl(this._self, this._then);

  final _PermissionModeRulesState _self;
  final $Res Function(_PermissionModeRulesState) _then;

  /// Create a copy of PermissionModeRulesState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? rules = null,
    Object? error = freezed,
  }) {
    return _then(_PermissionModeRulesState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      rules: null == rules
          ? _self._rules
          : rules // ignore: cast_nullable_to_non_nullable
              as List<ToolPermission>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
