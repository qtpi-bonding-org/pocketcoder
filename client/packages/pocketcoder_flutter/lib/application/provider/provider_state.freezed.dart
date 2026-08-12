// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProviderState {
  UiFlowStatus get status;
  List<Harnesse> get harnesses;
  List<Model> get models;
  List<HarnessModel> get harnessModels;
  List<ProviderKey> get providerKeys;
  Object? get error;

  /// Create a copy of ProviderState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProviderStateCopyWith<ProviderState> get copyWith =>
      _$ProviderStateCopyWithImpl<ProviderState>(
          this as ProviderState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProviderState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.harnesses, harnesses) &&
            const DeepCollectionEquality().equals(other.models, models) &&
            const DeepCollectionEquality()
                .equals(other.harnessModels, harnessModels) &&
            const DeepCollectionEquality()
                .equals(other.providerKeys, providerKeys) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(harnesses),
      const DeepCollectionEquality().hash(models),
      const DeepCollectionEquality().hash(harnessModels),
      const DeepCollectionEquality().hash(providerKeys),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'ProviderState(status: $status, harnesses: $harnesses, models: $models, harnessModels: $harnessModels, providerKeys: $providerKeys, error: $error)';
  }
}

/// @nodoc
abstract mixin class $ProviderStateCopyWith<$Res> {
  factory $ProviderStateCopyWith(
          ProviderState value, $Res Function(ProviderState) _then) =
      _$ProviderStateCopyWithImpl;
  @useResult
  $Res call(
      {UiFlowStatus status,
      List<Harnesse> harnesses,
      List<Model> models,
      List<HarnessModel> harnessModels,
      List<ProviderKey> providerKeys,
      Object? error});
}

/// @nodoc
class _$ProviderStateCopyWithImpl<$Res>
    implements $ProviderStateCopyWith<$Res> {
  _$ProviderStateCopyWithImpl(this._self, this._then);

  final ProviderState _self;
  final $Res Function(ProviderState) _then;

  /// Create a copy of ProviderState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? harnesses = null,
    Object? models = null,
    Object? harnessModels = null,
    Object? providerKeys = null,
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
      models: null == models
          ? _self.models
          : models // ignore: cast_nullable_to_non_nullable
              as List<Model>,
      harnessModels: null == harnessModels
          ? _self.harnessModels
          : harnessModels // ignore: cast_nullable_to_non_nullable
              as List<HarnessModel>,
      providerKeys: null == providerKeys
          ? _self.providerKeys
          : providerKeys // ignore: cast_nullable_to_non_nullable
              as List<ProviderKey>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [ProviderState].
extension ProviderStatePatterns on ProviderState {
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
    TResult Function(_ProviderState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProviderState() when $default != null:
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
    TResult Function(_ProviderState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderState():
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
    TResult? Function(_ProviderState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderState() when $default != null:
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
            List<Model> models,
            List<HarnessModel> harnessModels,
            List<ProviderKey> providerKeys,
            Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProviderState() when $default != null:
        return $default(_that.status, _that.harnesses, _that.models,
            _that.harnessModels, _that.providerKeys, _that.error);
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
            List<Model> models,
            List<HarnessModel> harnessModels,
            List<ProviderKey> providerKeys,
            Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderState():
        return $default(_that.status, _that.harnesses, _that.models,
            _that.harnessModels, _that.providerKeys, _that.error);
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
            List<Model> models,
            List<HarnessModel> harnessModels,
            List<ProviderKey> providerKeys,
            Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProviderState() when $default != null:
        return $default(_that.status, _that.harnesses, _that.models,
            _that.harnessModels, _that.providerKeys, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ProviderState extends ProviderState {
  const _ProviderState(
      {this.status = UiFlowStatus.idle,
      final List<Harnesse> harnesses = const [],
      final List<Model> models = const [],
      final List<HarnessModel> harnessModels = const [],
      final List<ProviderKey> providerKeys = const [],
      this.error})
      : _harnesses = harnesses,
        _models = models,
        _harnessModels = harnessModels,
        _providerKeys = providerKeys,
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

  final List<Model> _models;
  @override
  @JsonKey()
  List<Model> get models {
    if (_models is EqualUnmodifiableListView) return _models;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_models);
  }

  final List<HarnessModel> _harnessModels;
  @override
  @JsonKey()
  List<HarnessModel> get harnessModels {
    if (_harnessModels is EqualUnmodifiableListView) return _harnessModels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_harnessModels);
  }

  final List<ProviderKey> _providerKeys;
  @override
  @JsonKey()
  List<ProviderKey> get providerKeys {
    if (_providerKeys is EqualUnmodifiableListView) return _providerKeys;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_providerKeys);
  }

  @override
  final Object? error;

  /// Create a copy of ProviderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProviderStateCopyWith<_ProviderState> get copyWith =>
      __$ProviderStateCopyWithImpl<_ProviderState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProviderState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality()
                .equals(other._harnesses, _harnesses) &&
            const DeepCollectionEquality().equals(other._models, _models) &&
            const DeepCollectionEquality()
                .equals(other._harnessModels, _harnessModels) &&
            const DeepCollectionEquality()
                .equals(other._providerKeys, _providerKeys) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_harnesses),
      const DeepCollectionEquality().hash(_models),
      const DeepCollectionEquality().hash(_harnessModels),
      const DeepCollectionEquality().hash(_providerKeys),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'ProviderState(status: $status, harnesses: $harnesses, models: $models, harnessModels: $harnessModels, providerKeys: $providerKeys, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$ProviderStateCopyWith<$Res>
    implements $ProviderStateCopyWith<$Res> {
  factory _$ProviderStateCopyWith(
          _ProviderState value, $Res Function(_ProviderState) _then) =
      __$ProviderStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {UiFlowStatus status,
      List<Harnesse> harnesses,
      List<Model> models,
      List<HarnessModel> harnessModels,
      List<ProviderKey> providerKeys,
      Object? error});
}

/// @nodoc
class __$ProviderStateCopyWithImpl<$Res>
    implements _$ProviderStateCopyWith<$Res> {
  __$ProviderStateCopyWithImpl(this._self, this._then);

  final _ProviderState _self;
  final $Res Function(_ProviderState) _then;

  /// Create a copy of ProviderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? harnesses = null,
    Object? models = null,
    Object? harnessModels = null,
    Object? providerKeys = null,
    Object? error = freezed,
  }) {
    return _then(_ProviderState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      harnesses: null == harnesses
          ? _self._harnesses
          : harnesses // ignore: cast_nullable_to_non_nullable
              as List<Harnesse>,
      models: null == models
          ? _self._models
          : models // ignore: cast_nullable_to_non_nullable
              as List<Model>,
      harnessModels: null == harnessModels
          ? _self._harnessModels
          : harnessModels // ignore: cast_nullable_to_non_nullable
              as List<HarnessModel>,
      providerKeys: null == providerKeys
          ? _self._providerKeys
          : providerKeys // ignore: cast_nullable_to_non_nullable
              as List<ProviderKey>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
