// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'status_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StatusState {
  bool get isConnected;
  UiFlowStatus get status;
  Object? get error;

  /// Create a copy of StatusState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StatusStateCopyWith<StatusState> get copyWith =>
      _$StatusStateCopyWithImpl<StatusState>(this as StatusState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StatusState &&
            (identical(other.isConnected, isConnected) ||
                other.isConnected == isConnected) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(runtimeType, isConnected, status,
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'StatusState(isConnected: $isConnected, status: $status, error: $error)';
  }
}

/// @nodoc
abstract mixin class $StatusStateCopyWith<$Res> {
  factory $StatusStateCopyWith(
          StatusState value, $Res Function(StatusState) _then) =
      _$StatusStateCopyWithImpl;
  @useResult
  $Res call({bool isConnected, UiFlowStatus status, Object? error});
}

/// @nodoc
class _$StatusStateCopyWithImpl<$Res> implements $StatusStateCopyWith<$Res> {
  _$StatusStateCopyWithImpl(this._self, this._then);

  final StatusState _self;
  final $Res Function(StatusState) _then;

  /// Create a copy of StatusState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isConnected = null,
    Object? status = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      isConnected: null == isConnected
          ? _self.isConnected
          : isConnected // ignore: cast_nullable_to_non_nullable
              as bool,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [StatusState].
extension StatusStatePatterns on StatusState {
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
    TResult Function(_StatusState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _StatusState() when $default != null:
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
    TResult Function(_StatusState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StatusState():
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
    TResult? Function(_StatusState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StatusState() when $default != null:
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
    TResult Function(bool isConnected, UiFlowStatus status, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _StatusState() when $default != null:
        return $default(_that.isConnected, _that.status, _that.error);
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
    TResult Function(bool isConnected, UiFlowStatus status, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StatusState():
        return $default(_that.isConnected, _that.status, _that.error);
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
    TResult? Function(bool isConnected, UiFlowStatus status, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StatusState() when $default != null:
        return $default(_that.isConnected, _that.status, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _StatusState extends StatusState {
  const _StatusState(
      {this.isConnected = true, this.status = UiFlowStatus.idle, this.error})
      : super._();

  @override
  @JsonKey()
  final bool isConnected;
  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final Object? error;

  /// Create a copy of StatusState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$StatusStateCopyWith<_StatusState> get copyWith =>
      __$StatusStateCopyWithImpl<_StatusState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _StatusState &&
            (identical(other.isConnected, isConnected) ||
                other.isConnected == isConnected) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(runtimeType, isConnected, status,
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'StatusState(isConnected: $isConnected, status: $status, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$StatusStateCopyWith<$Res>
    implements $StatusStateCopyWith<$Res> {
  factory _$StatusStateCopyWith(
          _StatusState value, $Res Function(_StatusState) _then) =
      __$StatusStateCopyWithImpl;
  @override
  @useResult
  $Res call({bool isConnected, UiFlowStatus status, Object? error});
}

/// @nodoc
class __$StatusStateCopyWithImpl<$Res> implements _$StatusStateCopyWith<$Res> {
  __$StatusStateCopyWithImpl(this._self, this._then);

  final _StatusState _self;
  final $Res Function(_StatusState) _then;

  /// Create a copy of StatusState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? isConnected = null,
    Object? status = null,
    Object? error = freezed,
  }) {
    return _then(_StatusState(
      isConnected: null == isConnected
          ? _self.isConnected
          : isConnected // ignore: cast_nullable_to_non_nullable
              as bool,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
