// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'memory_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MemoryState {
  MemoryStats? get stats;
  UiFlowStatus get status;
  Object? get error;

  /// Create a copy of MemoryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MemoryStateCopyWith<MemoryState> get copyWith =>
      _$MemoryStateCopyWithImpl<MemoryState>(this as MemoryState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MemoryState &&
            (identical(other.stats, stats) || other.stats == stats) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, stats, status, const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'MemoryState(stats: $stats, status: $status, error: $error)';
  }
}

/// @nodoc
abstract mixin class $MemoryStateCopyWith<$Res> {
  factory $MemoryStateCopyWith(
          MemoryState value, $Res Function(MemoryState) _then) =
      _$MemoryStateCopyWithImpl;
  @useResult
  $Res call({MemoryStats? stats, UiFlowStatus status, Object? error});

  $MemoryStatsCopyWith<$Res>? get stats;
}

/// @nodoc
class _$MemoryStateCopyWithImpl<$Res> implements $MemoryStateCopyWith<$Res> {
  _$MemoryStateCopyWithImpl(this._self, this._then);

  final MemoryState _self;
  final $Res Function(MemoryState) _then;

  /// Create a copy of MemoryState
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
              as MemoryStats?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
    ));
  }

  /// Create a copy of MemoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MemoryStatsCopyWith<$Res>? get stats {
    if (_self.stats == null) {
      return null;
    }

    return $MemoryStatsCopyWith<$Res>(_self.stats!, (value) {
      return _then(_self.copyWith(stats: value));
    });
  }
}

/// Adds pattern-matching-related methods to [MemoryState].
extension MemoryStatePatterns on MemoryState {
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
    TResult Function(_MemoryState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MemoryState() when $default != null:
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
    TResult Function(_MemoryState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryState():
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
    TResult? Function(_MemoryState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryState() when $default != null:
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
    TResult Function(MemoryStats? stats, UiFlowStatus status, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MemoryState() when $default != null:
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
    TResult Function(MemoryStats? stats, UiFlowStatus status, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryState():
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
    TResult? Function(MemoryStats? stats, UiFlowStatus status, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MemoryState() when $default != null:
        return $default(_that.stats, _that.status, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _MemoryState extends MemoryState {
  const _MemoryState({this.stats, this.status = UiFlowStatus.idle, this.error})
      : super._();

  @override
  final MemoryStats? stats;
  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final Object? error;

  /// Create a copy of MemoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MemoryStateCopyWith<_MemoryState> get copyWith =>
      __$MemoryStateCopyWithImpl<_MemoryState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MemoryState &&
            (identical(other.stats, stats) || other.stats == stats) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, stats, status, const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'MemoryState(stats: $stats, status: $status, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$MemoryStateCopyWith<$Res>
    implements $MemoryStateCopyWith<$Res> {
  factory _$MemoryStateCopyWith(
          _MemoryState value, $Res Function(_MemoryState) _then) =
      __$MemoryStateCopyWithImpl;
  @override
  @useResult
  $Res call({MemoryStats? stats, UiFlowStatus status, Object? error});

  @override
  $MemoryStatsCopyWith<$Res>? get stats;
}

/// @nodoc
class __$MemoryStateCopyWithImpl<$Res> implements _$MemoryStateCopyWith<$Res> {
  __$MemoryStateCopyWithImpl(this._self, this._then);

  final _MemoryState _self;
  final $Res Function(_MemoryState) _then;

  /// Create a copy of MemoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? stats = freezed,
    Object? status = null,
    Object? error = freezed,
  }) {
    return _then(_MemoryState(
      stats: freezed == stats
          ? _self.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as MemoryStats?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
    ));
  }

  /// Create a copy of MemoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MemoryStatsCopyWith<$Res>? get stats {
    if (_self.stats == null) {
      return null;
    }

    return $MemoryStatsCopyWith<$Res>(_self.stats!, (value) {
      return _then(_self.copyWith(stats: value));
    });
  }
}

// dart format on
