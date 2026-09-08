// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'permission_modes_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PermissionModesState {
  UiFlowStatus get status;
  List<PermissionMode> get modes;
  Object? get error;

  /// Create a copy of PermissionModesState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PermissionModesStateCopyWith<PermissionModesState> get copyWith =>
      _$PermissionModesStateCopyWithImpl<PermissionModesState>(
          this as PermissionModesState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PermissionModesState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.modes, modes) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(modes),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'PermissionModesState(status: $status, modes: $modes, error: $error)';
  }
}

/// @nodoc
abstract mixin class $PermissionModesStateCopyWith<$Res> {
  factory $PermissionModesStateCopyWith(PermissionModesState value,
          $Res Function(PermissionModesState) _then) =
      _$PermissionModesStateCopyWithImpl;
  @useResult
  $Res call({UiFlowStatus status, List<PermissionMode> modes, Object? error});
}

/// @nodoc
class _$PermissionModesStateCopyWithImpl<$Res>
    implements $PermissionModesStateCopyWith<$Res> {
  _$PermissionModesStateCopyWithImpl(this._self, this._then);

  final PermissionModesState _self;
  final $Res Function(PermissionModesState) _then;

  /// Create a copy of PermissionModesState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? modes = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      modes: null == modes
          ? _self.modes
          : modes // ignore: cast_nullable_to_non_nullable
              as List<PermissionMode>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [PermissionModesState].
extension PermissionModesStatePatterns on PermissionModesState {
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
    TResult Function(_PermissionModesState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PermissionModesState() when $default != null:
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
    TResult Function(_PermissionModesState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionModesState():
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
    TResult? Function(_PermissionModesState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionModesState() when $default != null:
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
            UiFlowStatus status, List<PermissionMode> modes, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PermissionModesState() when $default != null:
        return $default(_that.status, _that.modes, _that.error);
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
            UiFlowStatus status, List<PermissionMode> modes, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionModesState():
        return $default(_that.status, _that.modes, _that.error);
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
            UiFlowStatus status, List<PermissionMode> modes, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionModesState() when $default != null:
        return $default(_that.status, _that.modes, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PermissionModesState extends PermissionModesState {
  const _PermissionModesState(
      {this.status = UiFlowStatus.idle,
      final List<PermissionMode> modes = const [],
      this.error})
      : _modes = modes,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  final List<PermissionMode> _modes;
  @override
  @JsonKey()
  List<PermissionMode> get modes {
    if (_modes is EqualUnmodifiableListView) return _modes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_modes);
  }

  @override
  final Object? error;

  /// Create a copy of PermissionModesState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PermissionModesStateCopyWith<_PermissionModesState> get copyWith =>
      __$PermissionModesStateCopyWithImpl<_PermissionModesState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PermissionModesState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._modes, _modes) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_modes),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'PermissionModesState(status: $status, modes: $modes, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$PermissionModesStateCopyWith<$Res>
    implements $PermissionModesStateCopyWith<$Res> {
  factory _$PermissionModesStateCopyWith(_PermissionModesState value,
          $Res Function(_PermissionModesState) _then) =
      __$PermissionModesStateCopyWithImpl;
  @override
  @useResult
  $Res call({UiFlowStatus status, List<PermissionMode> modes, Object? error});
}

/// @nodoc
class __$PermissionModesStateCopyWithImpl<$Res>
    implements _$PermissionModesStateCopyWith<$Res> {
  __$PermissionModesStateCopyWithImpl(this._self, this._then);

  final _PermissionModesState _self;
  final $Res Function(_PermissionModesState) _then;

  /// Create a copy of PermissionModesState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? modes = null,
    Object? error = freezed,
  }) {
    return _then(_PermissionModesState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      modes: null == modes
          ? _self._modes
          : modes // ignore: cast_nullable_to_non_nullable
              as List<PermissionMode>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
