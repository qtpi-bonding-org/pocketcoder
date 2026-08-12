// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HealthState {
  List<Healthcheck> get checks;
  UiFlowStatus get status;
  Object? get error;

  /// Create a copy of HealthState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HealthStateCopyWith<HealthState> get copyWith =>
      _$HealthStateCopyWithImpl<HealthState>(this as HealthState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HealthState &&
            const DeepCollectionEquality().equals(other.checks, checks) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(checks),
      status,
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'HealthState(checks: $checks, status: $status, error: $error)';
  }
}

/// @nodoc
abstract mixin class $HealthStateCopyWith<$Res> {
  factory $HealthStateCopyWith(
          HealthState value, $Res Function(HealthState) _then) =
      _$HealthStateCopyWithImpl;
  @useResult
  $Res call({List<Healthcheck> checks, UiFlowStatus status, Object? error});
}

/// @nodoc
class _$HealthStateCopyWithImpl<$Res> implements $HealthStateCopyWith<$Res> {
  _$HealthStateCopyWithImpl(this._self, this._then);

  final HealthState _self;
  final $Res Function(HealthState) _then;

  /// Create a copy of HealthState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checks = null,
    Object? status = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      checks: null == checks
          ? _self.checks
          : checks // ignore: cast_nullable_to_non_nullable
              as List<Healthcheck>,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [HealthState].
extension HealthStatePatterns on HealthState {
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
    TResult Function(_HealthState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HealthState() when $default != null:
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
    TResult Function(_HealthState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthState():
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
    TResult? Function(_HealthState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthState() when $default != null:
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
            List<Healthcheck> checks, UiFlowStatus status, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HealthState() when $default != null:
        return $default(_that.checks, _that.status, _that.error);
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
            List<Healthcheck> checks, UiFlowStatus status, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthState():
        return $default(_that.checks, _that.status, _that.error);
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
            List<Healthcheck> checks, UiFlowStatus status, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HealthState() when $default != null:
        return $default(_that.checks, _that.status, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _HealthState extends HealthState {
  const _HealthState(
      {final List<Healthcheck> checks = const [],
      this.status = UiFlowStatus.idle,
      this.error})
      : _checks = checks,
        super._();

  final List<Healthcheck> _checks;
  @override
  @JsonKey()
  List<Healthcheck> get checks {
    if (_checks is EqualUnmodifiableListView) return _checks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_checks);
  }

  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final Object? error;

  /// Create a copy of HealthState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HealthStateCopyWith<_HealthState> get copyWith =>
      __$HealthStateCopyWithImpl<_HealthState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HealthState &&
            const DeepCollectionEquality().equals(other._checks, _checks) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_checks),
      status,
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'HealthState(checks: $checks, status: $status, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$HealthStateCopyWith<$Res>
    implements $HealthStateCopyWith<$Res> {
  factory _$HealthStateCopyWith(
          _HealthState value, $Res Function(_HealthState) _then) =
      __$HealthStateCopyWithImpl;
  @override
  @useResult
  $Res call({List<Healthcheck> checks, UiFlowStatus status, Object? error});
}

/// @nodoc
class __$HealthStateCopyWithImpl<$Res> implements _$HealthStateCopyWith<$Res> {
  __$HealthStateCopyWithImpl(this._self, this._then);

  final _HealthState _self;
  final $Res Function(_HealthState) _then;

  /// Create a copy of HealthState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? checks = null,
    Object? status = null,
    Object? error = freezed,
  }) {
    return _then(_HealthState(
      checks: null == checks
          ? _self._checks
          : checks // ignore: cast_nullable_to_non_nullable
              as List<Healthcheck>,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
