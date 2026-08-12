// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'harness_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HarnessModel {
  String get id;
  String get harness;
  String get model;
  String get harnessModelId;
  bool? get isDefault;

  /// Create a copy of HarnessModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HarnessModelCopyWith<HarnessModel> get copyWith =>
      _$HarnessModelCopyWithImpl<HarnessModel>(
          this as HarnessModel, _$identity);

  /// Serializes this HarnessModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HarnessModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.harnessModelId, harnessModelId) ||
                other.harnessModelId == harnessModelId) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, harness, model, harnessModelId, isDefault);

  @override
  String toString() {
    return 'HarnessModel(id: $id, harness: $harness, model: $model, harnessModelId: $harnessModelId, isDefault: $isDefault)';
  }
}

/// @nodoc
abstract mixin class $HarnessModelCopyWith<$Res> {
  factory $HarnessModelCopyWith(
          HarnessModel value, $Res Function(HarnessModel) _then) =
      _$HarnessModelCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String harness,
      String model,
      String harnessModelId,
      bool? isDefault});
}

/// @nodoc
class _$HarnessModelCopyWithImpl<$Res> implements $HarnessModelCopyWith<$Res> {
  _$HarnessModelCopyWithImpl(this._self, this._then);

  final HarnessModel _self;
  final $Res Function(HarnessModel) _then;

  /// Create a copy of HarnessModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? harness = null,
    Object? model = null,
    Object? harnessModelId = null,
    Object? isDefault = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      harness: null == harness
          ? _self.harness
          : harness // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      harnessModelId: null == harnessModelId
          ? _self.harnessModelId
          : harnessModelId // ignore: cast_nullable_to_non_nullable
              as String,
      isDefault: freezed == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// Adds pattern-matching-related methods to [HarnessModel].
extension HarnessModelPatterns on HarnessModel {
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
    TResult Function(_HarnessModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessModel() when $default != null:
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
    TResult Function(_HarnessModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessModel():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
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
    TResult? Function(_HarnessModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessModel() when $default != null:
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
    TResult Function(String id, String harness, String model,
            String harnessModelId, bool? isDefault)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _HarnessModel() when $default != null:
        return $default(_that.id, _that.harness, _that.model,
            _that.harnessModelId, _that.isDefault);
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
    TResult Function(String id, String harness, String model,
            String harnessModelId, bool? isDefault)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessModel():
        return $default(_that.id, _that.harness, _that.model,
            _that.harnessModelId, _that.isDefault);
      case _:
        throw StateError('Unexpected subclass');
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
    TResult? Function(String id, String harness, String model,
            String harnessModelId, bool? isDefault)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _HarnessModel() when $default != null:
        return $default(_that.id, _that.harness, _that.model,
            _that.harnessModelId, _that.isDefault);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _HarnessModel implements HarnessModel {
  const _HarnessModel(
      {required this.id,
      required this.harness,
      required this.model,
      required this.harnessModelId,
      this.isDefault});
  factory _HarnessModel.fromJson(Map<String, dynamic> json) =>
      _$HarnessModelFromJson(json);

  @override
  final String id;
  @override
  final String harness;
  @override
  final String model;
  @override
  final String harnessModelId;
  @override
  final bool? isDefault;

  /// Create a copy of HarnessModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HarnessModelCopyWith<_HarnessModel> get copyWith =>
      __$HarnessModelCopyWithImpl<_HarnessModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HarnessModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _HarnessModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.harness, harness) || other.harness == harness) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.harnessModelId, harnessModelId) ||
                other.harnessModelId == harnessModelId) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, harness, model, harnessModelId, isDefault);

  @override
  String toString() {
    return 'HarnessModel(id: $id, harness: $harness, model: $model, harnessModelId: $harnessModelId, isDefault: $isDefault)';
  }
}

/// @nodoc
abstract mixin class _$HarnessModelCopyWith<$Res>
    implements $HarnessModelCopyWith<$Res> {
  factory _$HarnessModelCopyWith(
          _HarnessModel value, $Res Function(_HarnessModel) _then) =
      __$HarnessModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String harness,
      String model,
      String harnessModelId,
      bool? isDefault});
}

/// @nodoc
class __$HarnessModelCopyWithImpl<$Res>
    implements _$HarnessModelCopyWith<$Res> {
  __$HarnessModelCopyWithImpl(this._self, this._then);

  final _HarnessModel _self;
  final $Res Function(_HarnessModel) _then;

  /// Create a copy of HarnessModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? harness = null,
    Object? model = null,
    Object? harnessModelId = null,
    Object? isDefault = freezed,
  }) {
    return _then(_HarnessModel(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      harness: null == harness
          ? _self.harness
          : harness // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _self.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      harnessModelId: null == harnessModelId
          ? _self.harnessModelId
          : harnessModelId // ignore: cast_nullable_to_non_nullable
              as String,
      isDefault: freezed == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

// dart format on
