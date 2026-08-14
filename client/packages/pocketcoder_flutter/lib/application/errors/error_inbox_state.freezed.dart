// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error_inbox_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ErrorInboxState {
  UiFlowStatus get status;
  List<ErrorBoxEntry> get errors;
  Object? get error;

  /// Create a copy of ErrorInboxState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErrorInboxStateCopyWith<ErrorInboxState> get copyWith =>
      _$ErrorInboxStateCopyWithImpl<ErrorInboxState>(
          this as ErrorInboxState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErrorInboxState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.errors, errors) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(errors),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'ErrorInboxState(status: $status, errors: $errors, error: $error)';
  }
}

/// @nodoc
abstract mixin class $ErrorInboxStateCopyWith<$Res> {
  factory $ErrorInboxStateCopyWith(
          ErrorInboxState value, $Res Function(ErrorInboxState) _then) =
      _$ErrorInboxStateCopyWithImpl;
  @useResult
  $Res call({UiFlowStatus status, List<ErrorBoxEntry> errors, Object? error});
}

/// @nodoc
class _$ErrorInboxStateCopyWithImpl<$Res>
    implements $ErrorInboxStateCopyWith<$Res> {
  _$ErrorInboxStateCopyWithImpl(this._self, this._then);

  final ErrorInboxState _self;
  final $Res Function(ErrorInboxState) _then;

  /// Create a copy of ErrorInboxState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? errors = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      errors: null == errors
          ? _self.errors
          : errors // ignore: cast_nullable_to_non_nullable
              as List<ErrorBoxEntry>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [ErrorInboxState].
extension ErrorInboxStatePatterns on ErrorInboxState {
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
    TResult Function(_ErrorInboxState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxState() when $default != null:
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
    TResult Function(_ErrorInboxState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxState():
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
    TResult? Function(_ErrorInboxState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxState() when $default != null:
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
            UiFlowStatus status, List<ErrorBoxEntry> errors, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxState() when $default != null:
        return $default(_that.status, _that.errors, _that.error);
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
            UiFlowStatus status, List<ErrorBoxEntry> errors, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxState():
        return $default(_that.status, _that.errors, _that.error);
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
            UiFlowStatus status, List<ErrorBoxEntry> errors, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ErrorInboxState() when $default != null:
        return $default(_that.status, _that.errors, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ErrorInboxState extends ErrorInboxState {
  const _ErrorInboxState(
      {this.status = UiFlowStatus.idle,
      final List<ErrorBoxEntry> errors = const [],
      this.error})
      : _errors = errors,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  final List<ErrorBoxEntry> _errors;
  @override
  @JsonKey()
  List<ErrorBoxEntry> get errors {
    if (_errors is EqualUnmodifiableListView) return _errors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_errors);
  }

  @override
  final Object? error;

  /// Create a copy of ErrorInboxState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ErrorInboxStateCopyWith<_ErrorInboxState> get copyWith =>
      __$ErrorInboxStateCopyWithImpl<_ErrorInboxState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ErrorInboxState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._errors, _errors) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_errors),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'ErrorInboxState(status: $status, errors: $errors, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$ErrorInboxStateCopyWith<$Res>
    implements $ErrorInboxStateCopyWith<$Res> {
  factory _$ErrorInboxStateCopyWith(
          _ErrorInboxState value, $Res Function(_ErrorInboxState) _then) =
      __$ErrorInboxStateCopyWithImpl;
  @override
  @useResult
  $Res call({UiFlowStatus status, List<ErrorBoxEntry> errors, Object? error});
}

/// @nodoc
class __$ErrorInboxStateCopyWithImpl<$Res>
    implements _$ErrorInboxStateCopyWith<$Res> {
  __$ErrorInboxStateCopyWithImpl(this._self, this._then);

  final _ErrorInboxState _self;
  final $Res Function(_ErrorInboxState) _then;

  /// Create a copy of ErrorInboxState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? errors = null,
    Object? error = freezed,
  }) {
    return _then(_ErrorInboxState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      errors: null == errors
          ? _self._errors
          : errors // ignore: cast_nullable_to_non_nullable
              as List<ErrorBoxEntry>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
