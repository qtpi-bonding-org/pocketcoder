// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'healthcheck.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Healthcheck {
  String get id;
  String get name;
  @JsonKey(unknownEnumValue: HealthcheckStatus.unknown)
  HealthcheckStatus get status;
  DateTime? get lastPing;

  /// Create a copy of Healthcheck
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HealthcheckCopyWith<Healthcheck> get copyWith =>
      _$HealthcheckCopyWithImpl<Healthcheck>(this as Healthcheck, _$identity);

  /// Serializes this Healthcheck to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Healthcheck &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastPing, lastPing) ||
                other.lastPing == lastPing));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, status, lastPing);

  @override
  String toString() {
    return 'Healthcheck(id: $id, name: $name, status: $status, lastPing: $lastPing)';
  }
}

/// @nodoc
abstract mixin class $HealthcheckCopyWith<$Res> {
  factory $HealthcheckCopyWith(
          Healthcheck value, $Res Function(Healthcheck) _then) =
      _$HealthcheckCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      @JsonKey(unknownEnumValue: HealthcheckStatus.unknown)
      HealthcheckStatus status,
      DateTime? lastPing});
}

/// @nodoc
class _$HealthcheckCopyWithImpl<$Res> implements $HealthcheckCopyWith<$Res> {
  _$HealthcheckCopyWithImpl(this._self, this._then);

  final Healthcheck _self;
  final $Res Function(Healthcheck) _then;

  /// Create a copy of Healthcheck
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? status = null,
    Object? lastPing = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as HealthcheckStatus,
      lastPing: freezed == lastPing
          ? _self.lastPing
          : lastPing // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Healthcheck].
extension HealthcheckPatterns on Healthcheck {
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
    TResult Function(_Healthcheck value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Healthcheck() when $default != null:
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
    TResult Function(_Healthcheck value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Healthcheck():
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
    TResult? Function(_Healthcheck value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Healthcheck() when $default != null:
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
            String id,
            String name,
            @JsonKey(unknownEnumValue: HealthcheckStatus.unknown)
            HealthcheckStatus status,
            DateTime? lastPing)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Healthcheck() when $default != null:
        return $default(_that.id, _that.name, _that.status, _that.lastPing);
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
            String id,
            String name,
            @JsonKey(unknownEnumValue: HealthcheckStatus.unknown)
            HealthcheckStatus status,
            DateTime? lastPing)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Healthcheck():
        return $default(_that.id, _that.name, _that.status, _that.lastPing);
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
    TResult? Function(
            String id,
            String name,
            @JsonKey(unknownEnumValue: HealthcheckStatus.unknown)
            HealthcheckStatus status,
            DateTime? lastPing)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Healthcheck() when $default != null:
        return $default(_that.id, _that.name, _that.status, _that.lastPing);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Healthcheck implements Healthcheck {
  const _Healthcheck(
      {required this.id,
      required this.name,
      @JsonKey(unknownEnumValue: HealthcheckStatus.unknown)
      required this.status,
      this.lastPing});
  factory _Healthcheck.fromJson(Map<String, dynamic> json) =>
      _$HealthcheckFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey(unknownEnumValue: HealthcheckStatus.unknown)
  final HealthcheckStatus status;
  @override
  final DateTime? lastPing;

  /// Create a copy of Healthcheck
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$HealthcheckCopyWith<_Healthcheck> get copyWith =>
      __$HealthcheckCopyWithImpl<_Healthcheck>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$HealthcheckToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Healthcheck &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lastPing, lastPing) ||
                other.lastPing == lastPing));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, status, lastPing);

  @override
  String toString() {
    return 'Healthcheck(id: $id, name: $name, status: $status, lastPing: $lastPing)';
  }
}

/// @nodoc
abstract mixin class _$HealthcheckCopyWith<$Res>
    implements $HealthcheckCopyWith<$Res> {
  factory _$HealthcheckCopyWith(
          _Healthcheck value, $Res Function(_Healthcheck) _then) =
      __$HealthcheckCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      @JsonKey(unknownEnumValue: HealthcheckStatus.unknown)
      HealthcheckStatus status,
      DateTime? lastPing});
}

/// @nodoc
class __$HealthcheckCopyWithImpl<$Res> implements _$HealthcheckCopyWith<$Res> {
  __$HealthcheckCopyWithImpl(this._self, this._then);

  final _Healthcheck _self;
  final $Res Function(_Healthcheck) _then;

  /// Create a copy of Healthcheck
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? status = null,
    Object? lastPing = freezed,
  }) {
    return _then(_Healthcheck(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as HealthcheckStatus,
      lastPing: freezed == lastPing
          ? _self.lastPing
          : lastPing // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
