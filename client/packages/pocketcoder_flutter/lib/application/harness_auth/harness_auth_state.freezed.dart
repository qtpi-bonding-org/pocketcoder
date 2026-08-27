// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harness_auth_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessAuthState {
  UiFlowStatus get status;
  List<Harnesse> get harnesses;
  List<HarnessProvider> get harnessProviders;
  Map<String, HarnessAuthStatus> get statuses;
  Set<String> get busyHarnesses;
  Object? get error;

  /// Create a copy of HarnessAuthState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HarnessAuthStateCopyWith<HarnessAuthState> get copyWith =>
      _$HarnessAuthStateCopyWithImpl<HarnessAuthState>(
          this as HarnessAuthState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HarnessAuthState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.harnesses, harnesses) &&
            const DeepCollectionEquality()
                .equals(other.harnessProviders, harnessProviders) &&
            const DeepCollectionEquality().equals(other.statuses, statuses) &&
            const DeepCollectionEquality()
                .equals(other.busyHarnesses, busyHarnesses) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(harnesses),
      const DeepCollectionEquality().hash(harnessProviders),
      const DeepCollectionEquality().hash(statuses),
      const DeepCollectionEquality().hash(busyHarnesses),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'HarnessAuthState(status: $status, harnesses: $harnesses, harnessProviders: $harnessProviders, statuses: $statuses, busyHarnesses: $busyHarnesses, error: $error)';
  }
}

/// @nodoc
abstract mixin class $HarnessAuthStateCopyWith<$Res> {
  factory $HarnessAuthStateCopyWith(
          HarnessAuthState value, $Res Function(HarnessAuthState) _then) =
      _$HarnessAuthStateCopyWithImpl;
  @useResult
  $Res call(
      {UiFlowStatus status,
      List<Harnesse> harnesses,
      List<HarnessProvider> harnessProviders,
      Map<String, HarnessAuthStatus> statuses,
      Set<String> busyHarnesses,
      Object? error});
}

/// @nodoc
class _$HarnessAuthStateCopyWithImpl<$Res>
    implements $HarnessAuthStateCopyWith<$Res> {
  _$HarnessAuthStateCopyWithImpl(this._self, this._then);

  final HarnessAuthState _self;
  final $Res Function(HarnessAuthState) _then;

  /// Create a copy of HarnessAuthState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? harnesses = null,
    Object? harnessProviders = null,
    Object? statuses = null,
    Object? busyHarnesses = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      harnesses: null == harnesses
          ? _self.harnesses
          : harnesses // ignore: cast_nullable_to_non_nullable
              as List<Harnesse>,
      harnessProviders: null == harnessProviders
          ? _self.harnessProviders
          : harnessProviders // ignore: cast_nullable_to_non_nullable
              as List<HarnessProvider>,
      statuses: null == statuses
          ? _self.statuses
          : statuses // ignore: cast_nullable_to_non_nullable
              as Map<String, HarnessAuthStatus>,
      busyHarnesses: null == busyHarnesses
          ? _self.busyHarnesses
          : busyHarnesses // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [HarnessAuthState].
extension HarnessAuthStatePatterns on HarnessAuthState {
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
    TResult Function(_HarnessAuthState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessAuthState() when $default != null:
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
    TResult Function(_HarnessAuthState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAuthState():
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
    TResult? Function(_HarnessAuthState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAuthState() when $default != null:
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
            List<Harnesse> harnesses,
            List<HarnessProvider> harnessProviders,
            Map<String, HarnessAuthStatus> statuses,
            Set<String> busyHarnesses,
            Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessAuthState() when $default != null:
        return $default(_that.status, _that.harnesses, _that.harnessProviders,
            _that.statuses, _that.busyHarnesses, _that.error);
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
            List<Harnesse> harnesses,
            List<HarnessProvider> harnessProviders,
            Map<String, HarnessAuthStatus> statuses,
            Set<String> busyHarnesses,
            Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAuthState():
        return $default(_that.status, _that.harnesses, _that.harnessProviders,
            _that.statuses, _that.busyHarnesses, _that.error);
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
            List<Harnesse> harnesses,
            List<HarnessProvider> harnessProviders,
            Map<String, HarnessAuthStatus> statuses,
            Set<String> busyHarnesses,
            Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessAuthState() when $default != null:
        return $default(_that.status, _that.harnesses, _that.harnessProviders,
            _that.statuses, _that.busyHarnesses, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _HarnessAuthState extends HarnessAuthState {
  const _HarnessAuthState(
      {this.status = UiFlowStatus.idle,
      final List<Harnesse> harnesses = const <Harnesse>[],
      final List<HarnessProvider> harnessProviders = const <HarnessProvider>[],
      final Map<String, HarnessAuthStatus> statuses =
          const <String, HarnessAuthStatus>{},
      final Set<String> busyHarnesses = const <String>{},
      this.error})
      : _harnesses = harnesses,
        _harnessProviders = harnessProviders,
        _statuses = statuses,
        _busyHarnesses = busyHarnesses,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  final List<Harnesse> _harnesses;
  @override
  @JsonKey()
  List<Harnesse> get harnesses {
    if (_harnesses is EqualUnmodifiableListView) return _harnesses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_harnesses);
  }

  final List<HarnessProvider> _harnessProviders;
  @override
  @JsonKey()
  List<HarnessProvider> get harnessProviders {
    if (_harnessProviders is EqualUnmodifiableListView)
      return _harnessProviders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_harnessProviders);
  }

  final Map<String, HarnessAuthStatus> _statuses;
  @override
  @JsonKey()
  Map<String, HarnessAuthStatus> get statuses {
    if (_statuses is EqualUnmodifiableMapView) return _statuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_statuses);
  }

  final Set<String> _busyHarnesses;
  @override
  @JsonKey()
  Set<String> get busyHarnesses {
    if (_busyHarnesses is EqualUnmodifiableSetView) return _busyHarnesses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_busyHarnesses);
  }

  @override
  final Object? error;

  /// Create a copy of HarnessAuthState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HarnessAuthStateCopyWith<_HarnessAuthState> get copyWith =>
      __$HarnessAuthStateCopyWithImpl<_HarnessAuthState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HarnessAuthState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality()
                .equals(other._harnesses, _harnesses) &&
            const DeepCollectionEquality()
                .equals(other._harnessProviders, _harnessProviders) &&
            const DeepCollectionEquality().equals(other._statuses, _statuses) &&
            const DeepCollectionEquality()
                .equals(other._busyHarnesses, _busyHarnesses) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_harnesses),
      const DeepCollectionEquality().hash(_harnessProviders),
      const DeepCollectionEquality().hash(_statuses),
      const DeepCollectionEquality().hash(_busyHarnesses),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'HarnessAuthState(status: $status, harnesses: $harnesses, harnessProviders: $harnessProviders, statuses: $statuses, busyHarnesses: $busyHarnesses, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$HarnessAuthStateCopyWith<$Res>
    implements $HarnessAuthStateCopyWith<$Res> {
  factory _$HarnessAuthStateCopyWith(
          _HarnessAuthState value, $Res Function(_HarnessAuthState) _then) =
      __$HarnessAuthStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {UiFlowStatus status,
      List<Harnesse> harnesses,
      List<HarnessProvider> harnessProviders,
      Map<String, HarnessAuthStatus> statuses,
      Set<String> busyHarnesses,
      Object? error});
}

/// @nodoc
class __$HarnessAuthStateCopyWithImpl<$Res>
    implements _$HarnessAuthStateCopyWith<$Res> {
  __$HarnessAuthStateCopyWithImpl(this._self, this._then);

  final _HarnessAuthState _self;
  final $Res Function(_HarnessAuthState) _then;

  /// Create a copy of HarnessAuthState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? harnesses = null,
    Object? harnessProviders = null,
    Object? statuses = null,
    Object? busyHarnesses = null,
    Object? error = freezed,
  }) {
    return _then(_HarnessAuthState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      harnesses: null == harnesses
          ? _self._harnesses
          : harnesses // ignore: cast_nullable_to_non_nullable
              as List<Harnesse>,
      harnessProviders: null == harnessProviders
          ? _self._harnessProviders
          : harnessProviders // ignore: cast_nullable_to_non_nullable
              as List<HarnessProvider>,
      statuses: null == statuses
          ? _self._statuses
          : statuses // ignore: cast_nullable_to_non_nullable
              as Map<String, HarnessAuthStatus>,
      busyHarnesses: null == busyHarnesses
          ? _self._busyHarnesses
          : busyHarnesses // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
