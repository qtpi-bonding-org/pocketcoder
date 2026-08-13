// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pocketcoder_update_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PocketCoderUpdateState {
  UiFlowStatus get status;
  Object? get error;
  ServerReleaseStatusSnapshot? get preview;
  PocketCoderUpdateResult? get result;
  bool get upgradeConfirmed;

  /// Create a copy of PocketCoderUpdateState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PocketCoderUpdateStateCopyWith<PocketCoderUpdateState> get copyWith =>
      _$PocketCoderUpdateStateCopyWithImpl<PocketCoderUpdateState>(
          this as PocketCoderUpdateState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PocketCoderUpdateState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            (identical(other.preview, preview) || other.preview == preview) &&
            (identical(other.result, result) || other.result == result) &&
            (identical(other.upgradeConfirmed, upgradeConfirmed) ||
                other.upgradeConfirmed == upgradeConfirmed));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(error),
      preview,
      result,
      upgradeConfirmed);

  @override
  String toString() {
    return 'PocketCoderUpdateState(status: $status, error: $error, preview: $preview, result: $result, upgradeConfirmed: $upgradeConfirmed)';
  }
}

/// @nodoc
abstract mixin class $PocketCoderUpdateStateCopyWith<$Res> {
  factory $PocketCoderUpdateStateCopyWith(PocketCoderUpdateState value,
          $Res Function(PocketCoderUpdateState) _then) =
      _$PocketCoderUpdateStateCopyWithImpl;
  @useResult
  $Res call(
      {UiFlowStatus status,
      Object? error,
      ServerReleaseStatusSnapshot? preview,
      PocketCoderUpdateResult? result,
      bool upgradeConfirmed});
}

/// @nodoc
class _$PocketCoderUpdateStateCopyWithImpl<$Res>
    implements $PocketCoderUpdateStateCopyWith<$Res> {
  _$PocketCoderUpdateStateCopyWithImpl(this._self, this._then);

  final PocketCoderUpdateState _self;
  final $Res Function(PocketCoderUpdateState) _then;

  /// Create a copy of PocketCoderUpdateState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? error = freezed,
    Object? preview = freezed,
    Object? result = freezed,
    Object? upgradeConfirmed = null,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
      preview: freezed == preview
          ? _self.preview
          : preview // ignore: cast_nullable_to_non_nullable
              as ServerReleaseStatusSnapshot?,
      result: freezed == result
          ? _self.result
          : result // ignore: cast_nullable_to_non_nullable
              as PocketCoderUpdateResult?,
      upgradeConfirmed: null == upgradeConfirmed
          ? _self.upgradeConfirmed
          : upgradeConfirmed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [PocketCoderUpdateState].
extension PocketCoderUpdateStatePatterns on PocketCoderUpdateState {
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
    TResult Function(_PocketCoderUpdateState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocketCoderUpdateState() when $default != null:
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
    TResult Function(_PocketCoderUpdateState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketCoderUpdateState():
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
    TResult? Function(_PocketCoderUpdateState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketCoderUpdateState() when $default != null:
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
            Object? error,
            ServerReleaseStatusSnapshot? preview,
            PocketCoderUpdateResult? result,
            bool upgradeConfirmed)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PocketCoderUpdateState() when $default != null:
        return $default(_that.status, _that.error, _that.preview, _that.result,
            _that.upgradeConfirmed);
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
            Object? error,
            ServerReleaseStatusSnapshot? preview,
            PocketCoderUpdateResult? result,
            bool upgradeConfirmed)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketCoderUpdateState():
        return $default(_that.status, _that.error, _that.preview, _that.result,
            _that.upgradeConfirmed);
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
            Object? error,
            ServerReleaseStatusSnapshot? preview,
            PocketCoderUpdateResult? result,
            bool upgradeConfirmed)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PocketCoderUpdateState() when $default != null:
        return $default(_that.status, _that.error, _that.preview, _that.result,
            _that.upgradeConfirmed);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PocketCoderUpdateState extends PocketCoderUpdateState {
  const _PocketCoderUpdateState(
      {this.status = UiFlowStatus.idle,
      this.error,
      this.preview,
      this.result,
      this.upgradeConfirmed = false})
      : super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final Object? error;
  @override
  final ServerReleaseStatusSnapshot? preview;
  @override
  final PocketCoderUpdateResult? result;
  @override
  @JsonKey()
  final bool upgradeConfirmed;

  /// Create a copy of PocketCoderUpdateState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PocketCoderUpdateStateCopyWith<_PocketCoderUpdateState> get copyWith =>
      __$PocketCoderUpdateStateCopyWithImpl<_PocketCoderUpdateState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PocketCoderUpdateState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.error, error) &&
            (identical(other.preview, preview) || other.preview == preview) &&
            (identical(other.result, result) || other.result == result) &&
            (identical(other.upgradeConfirmed, upgradeConfirmed) ||
                other.upgradeConfirmed == upgradeConfirmed));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(error),
      preview,
      result,
      upgradeConfirmed);

  @override
  String toString() {
    return 'PocketCoderUpdateState(status: $status, error: $error, preview: $preview, result: $result, upgradeConfirmed: $upgradeConfirmed)';
  }
}

/// @nodoc
abstract mixin class _$PocketCoderUpdateStateCopyWith<$Res>
    implements $PocketCoderUpdateStateCopyWith<$Res> {
  factory _$PocketCoderUpdateStateCopyWith(_PocketCoderUpdateState value,
          $Res Function(_PocketCoderUpdateState) _then) =
      __$PocketCoderUpdateStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {UiFlowStatus status,
      Object? error,
      ServerReleaseStatusSnapshot? preview,
      PocketCoderUpdateResult? result,
      bool upgradeConfirmed});
}

/// @nodoc
class __$PocketCoderUpdateStateCopyWithImpl<$Res>
    implements _$PocketCoderUpdateStateCopyWith<$Res> {
  __$PocketCoderUpdateStateCopyWithImpl(this._self, this._then);

  final _PocketCoderUpdateState _self;
  final $Res Function(_PocketCoderUpdateState) _then;

  /// Create a copy of PocketCoderUpdateState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? error = freezed,
    Object? preview = freezed,
    Object? result = freezed,
    Object? upgradeConfirmed = null,
  }) {
    return _then(_PocketCoderUpdateState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      error: freezed == error ? _self.error : error,
      preview: freezed == preview
          ? _self.preview
          : preview // ignore: cast_nullable_to_non_nullable
              as ServerReleaseStatusSnapshot?,
      result: freezed == result
          ? _self.result
          : result // ignore: cast_nullable_to_non_nullable
              as PocketCoderUpdateResult?,
      upgradeConfirmed: null == upgradeConfirmed
          ? _self.upgradeConfirmed
          : upgradeConfirmed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
