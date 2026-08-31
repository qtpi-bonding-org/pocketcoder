// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pocketbase_inspector_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PocketbaseInspectorState {
  PocketbaseInspectorStats? get stats;
  UiFlowStatus get status;
  Object? get error;

  /// Create a copy of PocketbaseInspectorState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PocketbaseInspectorStateCopyWith<PocketbaseInspectorState> get copyWith =>
      _$PocketbaseInspectorStateCopyWithImpl<PocketbaseInspectorState>(
          this as PocketbaseInspectorState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PocketbaseInspectorState &&
            (identical(other.stats, stats) || other.stats == stats) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, stats, status, const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'PocketbaseInspectorState(stats: $stats, status: $status, error: $error)';
  }
}

/// @nodoc
abstract mixin class $PocketbaseInspectorStateCopyWith<$Res> {
  factory $PocketbaseInspectorStateCopyWith(PocketbaseInspectorState value,
          $Res Function(PocketbaseInspectorState) _then) =
      _$PocketbaseInspectorStateCopyWithImpl;
  @useResult
  $Res call(
      {PocketbaseInspectorStats? stats, UiFlowStatus status, Object? error});

  $PocketbaseInspectorStatsCopyWith<$Res>? get stats;
}

/// @nodoc
class _$PocketbaseInspectorStateCopyWithImpl<$Res>
    implements $PocketbaseInspectorStateCopyWith<$Res> {
  _$PocketbaseInspectorStateCopyWithImpl(this._self, this._then);

  final PocketbaseInspectorState _self;
  final $Res Function(PocketbaseInspectorState) _then;

  /// Create a copy of PocketbaseInspectorState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stats = freezed,
    Object? status = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      stats: freezed == stats
          ? _self.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as PocketbaseInspectorStats?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
    ));
  }

  /// Create a copy of PocketbaseInspectorState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PocketbaseInspectorStatsCopyWith<$Res>? get stats {
    if (_self.stats == null) {
      return null;
    }

    return $PocketbaseInspectorStatsCopyWith<$Res>(_self.stats!, (value) {
      return _then(_self.copyWith(stats: value));
    });
  }
}

/// Adds pattern-matching-related methods to [PocketbaseInspectorState].
extension PocketbaseInspectorStatePatterns on PocketbaseInspectorState {
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
    TResult Function(_PocketbaseInspectorState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorState() when $default != null:
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
    TResult Function(_PocketbaseInspectorState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorState():
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
    TResult? Function(_PocketbaseInspectorState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorState() when $default != null:
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
    TResult Function(PocketbaseInspectorStats? stats, UiFlowStatus status,
            Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorState() when $default != null:
        return $default(_that.stats, _that.status, _that.error);
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
            PocketbaseInspectorStats? stats, UiFlowStatus status, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorState():
        return $default(_that.stats, _that.status, _that.error);
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
    TResult? Function(PocketbaseInspectorStats? stats, UiFlowStatus status,
            Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketbaseInspectorState() when $default != null:
        return $default(_that.stats, _that.status, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PocketbaseInspectorState extends PocketbaseInspectorState {
  const _PocketbaseInspectorState(
      {this.stats, this.status = UiFlowStatus.idle, this.error})
      : super._();

  @override
  final PocketbaseInspectorStats? stats;
  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final Object? error;

  /// Create a copy of PocketbaseInspectorState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PocketbaseInspectorStateCopyWith<_PocketbaseInspectorState> get copyWith =>
      __$PocketbaseInspectorStateCopyWithImpl<_PocketbaseInspectorState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PocketbaseInspectorState &&
            (identical(other.stats, stats) || other.stats == stats) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, stats, status, const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'PocketbaseInspectorState(stats: $stats, status: $status, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$PocketbaseInspectorStateCopyWith<$Res>
    implements $PocketbaseInspectorStateCopyWith<$Res> {
  factory _$PocketbaseInspectorStateCopyWith(_PocketbaseInspectorState value,
          $Res Function(_PocketbaseInspectorState) _then) =
      __$PocketbaseInspectorStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {PocketbaseInspectorStats? stats, UiFlowStatus status, Object? error});

  @override
  $PocketbaseInspectorStatsCopyWith<$Res>? get stats;
}

/// @nodoc
class __$PocketbaseInspectorStateCopyWithImpl<$Res>
    implements _$PocketbaseInspectorStateCopyWith<$Res> {
  __$PocketbaseInspectorStateCopyWithImpl(this._self, this._then);

  final _PocketbaseInspectorState _self;
  final $Res Function(_PocketbaseInspectorState) _then;

  /// Create a copy of PocketbaseInspectorState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? stats = freezed,
    Object? status = null,
    Object? error = freezed,
  }) {
    return _then(_PocketbaseInspectorState(
      stats: freezed == stats
          ? _self.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as PocketbaseInspectorStats?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
    ));
  }

  /// Create a copy of PocketbaseInspectorState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PocketbaseInspectorStatsCopyWith<$Res>? get stats {
    if (_self.stats == null) {
      return null;
    }

    return $PocketbaseInspectorStatsCopyWith<$Res>(_self.stats!, (value) {
      return _then(_self.copyWith(stats: value));
    });
  }
}

// dart format on
