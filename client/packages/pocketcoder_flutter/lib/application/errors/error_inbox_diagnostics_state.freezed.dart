// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error_inbox_diagnostics_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ErrorInboxDiagnosticsState {
  UiFlowStatus get status;
  Object? get error;

  /// Create a copy of ErrorInboxDiagnosticsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErrorInboxDiagnosticsStateCopyWith<ErrorInboxDiagnosticsState>
      get copyWith =>
          _$ErrorInboxDiagnosticsStateCopyWithImpl<ErrorInboxDiagnosticsState>(
              this as ErrorInboxDiagnosticsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErrorInboxDiagnosticsState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, status, const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'ErrorInboxDiagnosticsState(status: $status, error: $error)';
  }
}

/// @nodoc
abstract mixin class $ErrorInboxDiagnosticsStateCopyWith<$Res> {
  factory $ErrorInboxDiagnosticsStateCopyWith(ErrorInboxDiagnosticsState value,
          $Res Function(ErrorInboxDiagnosticsState) _then) =
      _$ErrorInboxDiagnosticsStateCopyWithImpl;
  @useResult
  $Res call({UiFlowStatus status, Object? error});
}

/// @nodoc
class _$ErrorInboxDiagnosticsStateCopyWithImpl<$Res>
    implements $ErrorInboxDiagnosticsStateCopyWith<$Res> {
  _$ErrorInboxDiagnosticsStateCopyWithImpl(this._self, this._then);

  final ErrorInboxDiagnosticsState _self;
  final $Res Function(ErrorInboxDiagnosticsState) _then;

  /// Create a copy of ErrorInboxDiagnosticsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [ErrorInboxDiagnosticsState].
extension ErrorInboxDiagnosticsStatePatterns on ErrorInboxDiagnosticsState {
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
    TResult Function(_ErrorInboxDiagnosticsState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxDiagnosticsState() when $default != null:
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
    TResult Function(_ErrorInboxDiagnosticsState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxDiagnosticsState():
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
    TResult? Function(_ErrorInboxDiagnosticsState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxDiagnosticsState() when $default != null:
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
    TResult Function(UiFlowStatus status, Object? error)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxDiagnosticsState() when $default != null:
        return $default(_that.status, _that.error);
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
    TResult Function(UiFlowStatus status, Object? error) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxDiagnosticsState():
        return $default(_that.status, _that.error);
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
    TResult? Function(UiFlowStatus status, Object? error)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxDiagnosticsState() when $default != null:
        return $default(_that.status, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ErrorInboxDiagnosticsState extends ErrorInboxDiagnosticsState {
  const _ErrorInboxDiagnosticsState(
      {this.status = UiFlowStatus.idle, this.error})
      : super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final Object? error;

  /// Create a copy of ErrorInboxDiagnosticsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ErrorInboxDiagnosticsStateCopyWith<_ErrorInboxDiagnosticsState>
      get copyWith => __$ErrorInboxDiagnosticsStateCopyWithImpl<
          _ErrorInboxDiagnosticsState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ErrorInboxDiagnosticsState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, status, const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'ErrorInboxDiagnosticsState(status: $status, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$ErrorInboxDiagnosticsStateCopyWith<$Res>
    implements $ErrorInboxDiagnosticsStateCopyWith<$Res> {
  factory _$ErrorInboxDiagnosticsStateCopyWith(
          _ErrorInboxDiagnosticsState value,
          $Res Function(_ErrorInboxDiagnosticsState) _then) =
      __$ErrorInboxDiagnosticsStateCopyWithImpl;
  @override
  @useResult
  $Res call({UiFlowStatus status, Object? error});
}

/// @nodoc
class __$ErrorInboxDiagnosticsStateCopyWithImpl<$Res>
    implements _$ErrorInboxDiagnosticsStateCopyWith<$Res> {
  __$ErrorInboxDiagnosticsStateCopyWithImpl(this._self, this._then);

  final _ErrorInboxDiagnosticsState _self;
  final $Res Function(_ErrorInboxDiagnosticsState) _then;

  /// Create a copy of ErrorInboxDiagnosticsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? error = freezed,
  }) {
    return _then(_ErrorInboxDiagnosticsState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
