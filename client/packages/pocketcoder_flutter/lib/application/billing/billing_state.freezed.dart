// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'billing_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BillingState {
  List<BillingPackage> get packages;
  UiFlowStatus get status;
  bool get isPro;
  Object? get error;

  /// Create a copy of BillingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BillingStateCopyWith<BillingState> get copyWith =>
      _$BillingStateCopyWithImpl<BillingState>(
          this as BillingState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BillingState &&
            const DeepCollectionEquality().equals(other.packages, packages) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isPro, isPro) || other.isPro == isPro) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(packages),
      status,
      isPro,
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'BillingState(packages: $packages, status: $status, isPro: $isPro, error: $error)';
  }
}

/// @nodoc
abstract mixin class $BillingStateCopyWith<$Res> {
  factory $BillingStateCopyWith(
          BillingState value, $Res Function(BillingState) _then) =
      _$BillingStateCopyWithImpl;
  @useResult
  $Res call(
      {List<BillingPackage> packages,
      UiFlowStatus status,
      bool isPro,
      Object? error});
}

/// @nodoc
class _$BillingStateCopyWithImpl<$Res> implements $BillingStateCopyWith<$Res> {
  _$BillingStateCopyWithImpl(this._self, this._then);

  final BillingState _self;
  final $Res Function(BillingState) _then;

  /// Create a copy of BillingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? packages = null,
    Object? status = null,
    Object? isPro = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      packages: null == packages
          ? _self.packages
          : packages // ignore: cast_nullable_to_non_nullable
              as List<BillingPackage>,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      isPro: null == isPro
          ? _self.isPro
          : isPro // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [BillingState].
extension BillingStatePatterns on BillingState {
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
    TResult Function(_BillingState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BillingState() when $default != null:
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
    TResult Function(_BillingState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillingState():
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
    TResult? Function(_BillingState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillingState() when $default != null:
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
    TResult Function(List<BillingPackage> packages, UiFlowStatus status,
            bool isPro, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BillingState() when $default != null:
        return $default(_that.packages, _that.status, _that.isPro, _that.error);
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
    TResult Function(List<BillingPackage> packages, UiFlowStatus status,
            bool isPro, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillingState():
        return $default(_that.packages, _that.status, _that.isPro, _that.error);
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
    TResult? Function(List<BillingPackage> packages, UiFlowStatus status,
            bool isPro, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillingState() when $default != null:
        return $default(_that.packages, _that.status, _that.isPro, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _BillingState extends BillingState {
  const _BillingState(
      {final List<BillingPackage> packages = const [],
      this.status = UiFlowStatus.idle,
      this.isPro = false,
      this.error})
      : _packages = packages,
        super._();

  final List<BillingPackage> _packages;
  @override
  @JsonKey()
  List<BillingPackage> get packages {
    if (_packages is EqualUnmodifiableListView) return _packages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_packages);
  }

  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  @JsonKey()
  final bool isPro;
  @override
  final Object? error;

  /// Create a copy of BillingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BillingStateCopyWith<_BillingState> get copyWith =>
      __$BillingStateCopyWithImpl<_BillingState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BillingState &&
            const DeepCollectionEquality().equals(other._packages, _packages) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isPro, isPro) || other.isPro == isPro) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_packages),
      status,
      isPro,
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'BillingState(packages: $packages, status: $status, isPro: $isPro, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$BillingStateCopyWith<$Res>
    implements $BillingStateCopyWith<$Res> {
  factory _$BillingStateCopyWith(
          _BillingState value, $Res Function(_BillingState) _then) =
      __$BillingStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<BillingPackage> packages,
      UiFlowStatus status,
      bool isPro,
      Object? error});
}

/// @nodoc
class __$BillingStateCopyWithImpl<$Res>
    implements _$BillingStateCopyWith<$Res> {
  __$BillingStateCopyWithImpl(this._self, this._then);

  final _BillingState _self;
  final $Res Function(_BillingState) _then;

  /// Create a copy of BillingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? packages = null,
    Object? status = null,
    Object? isPro = null,
    Object? error = freezed,
  }) {
    return _then(_BillingState(
      packages: null == packages
          ? _self._packages
          : packages // ignore: cast_nullable_to_non_nullable
              as List<BillingPackage>,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      isPro: null == isPro
          ? _self.isPro
          : isPro // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
