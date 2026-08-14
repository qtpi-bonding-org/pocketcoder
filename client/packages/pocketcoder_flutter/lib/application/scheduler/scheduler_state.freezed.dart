// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduler_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SchedulerState {
  UiFlowStatus get status;
  List<ScheduleOwner> get schedules;
  Object? get error;

  /// Create a copy of SchedulerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SchedulerStateCopyWith<SchedulerState> get copyWith =>
      _$SchedulerStateCopyWithImpl<SchedulerState>(
          this as SchedulerState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SchedulerState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.schedules, schedules) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(schedules),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'SchedulerState(status: $status, schedules: $schedules, error: $error)';
  }
}

/// @nodoc
abstract mixin class $SchedulerStateCopyWith<$Res> {
  factory $SchedulerStateCopyWith(
          SchedulerState value, $Res Function(SchedulerState) _then) =
      _$SchedulerStateCopyWithImpl;
  @useResult
  $Res call(
      {UiFlowStatus status, List<ScheduleOwner> schedules, Object? error});
}

/// @nodoc
class _$SchedulerStateCopyWithImpl<$Res>
    implements $SchedulerStateCopyWith<$Res> {
  _$SchedulerStateCopyWithImpl(this._self, this._then);

  final SchedulerState _self;
  final $Res Function(SchedulerState) _then;

  /// Create a copy of SchedulerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? schedules = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      schedules: null == schedules
          ? _self.schedules
          : schedules // ignore: cast_nullable_to_non_nullable
              as List<ScheduleOwner>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [SchedulerState].
extension SchedulerStatePatterns on SchedulerState {
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
    TResult Function(_SchedulerState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SchedulerState() when $default != null:
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
    TResult Function(_SchedulerState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SchedulerState():
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
    TResult? Function(_SchedulerState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SchedulerState() when $default != null:
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
            UiFlowStatus status, List<ScheduleOwner> schedules, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SchedulerState() when $default != null:
        return $default(_that.status, _that.schedules, _that.error);
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
            UiFlowStatus status, List<ScheduleOwner> schedules, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SchedulerState():
        return $default(_that.status, _that.schedules, _that.error);
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
            UiFlowStatus status, List<ScheduleOwner> schedules, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SchedulerState() when $default != null:
        return $default(_that.status, _that.schedules, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SchedulerState extends SchedulerState {
  const _SchedulerState(
      {this.status = UiFlowStatus.idle,
      final List<ScheduleOwner> schedules = const [],
      this.error})
      : _schedules = schedules,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  final List<ScheduleOwner> _schedules;
  @override
  @JsonKey()
  List<ScheduleOwner> get schedules {
    if (_schedules is EqualUnmodifiableListView) return _schedules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_schedules);
  }

  @override
  final Object? error;

  /// Create a copy of SchedulerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SchedulerStateCopyWith<_SchedulerState> get copyWith =>
      __$SchedulerStateCopyWithImpl<_SchedulerState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SchedulerState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality()
                .equals(other._schedules, _schedules) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_schedules),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'SchedulerState(status: $status, schedules: $schedules, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$SchedulerStateCopyWith<$Res>
    implements $SchedulerStateCopyWith<$Res> {
  factory _$SchedulerStateCopyWith(
          _SchedulerState value, $Res Function(_SchedulerState) _then) =
      __$SchedulerStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {UiFlowStatus status, List<ScheduleOwner> schedules, Object? error});
}

/// @nodoc
class __$SchedulerStateCopyWithImpl<$Res>
    implements _$SchedulerStateCopyWith<$Res> {
  __$SchedulerStateCopyWithImpl(this._self, this._then);

  final _SchedulerState _self;
  final $Res Function(_SchedulerState) _then;

  /// Create a copy of SchedulerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? schedules = null,
    Object? error = freezed,
  }) {
    return _then(_SchedulerState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      schedules: null == schedules
          ? _self._schedules
          : schedules // ignore: cast_nullable_to_non_nullable
              as List<ScheduleOwner>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
