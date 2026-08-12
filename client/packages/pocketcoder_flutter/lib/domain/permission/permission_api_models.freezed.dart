// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'permission_api_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PermissionResponse {
  bool get permitted;
  String get id;
  String get status;

  /// Create a copy of PermissionResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PermissionResponseCopyWith<PermissionResponse> get copyWith =>
      _$PermissionResponseCopyWithImpl<PermissionResponse>(
          this as PermissionResponse, _$identity);

  /// Serializes this PermissionResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PermissionResponse &&
            (identical(other.permitted, permitted) ||
                other.permitted == permitted) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, permitted, id, status);

  @override
  String toString() {
    return 'PermissionResponse(permitted: $permitted, id: $id, status: $status)';
  }
}

/// @nodoc
abstract mixin class $PermissionResponseCopyWith<$Res> {
  factory $PermissionResponseCopyWith(
          PermissionResponse value, $Res Function(PermissionResponse) _then) =
      _$PermissionResponseCopyWithImpl;
  @useResult
  $Res call({bool permitted, String id, String status});
}

/// @nodoc
class _$PermissionResponseCopyWithImpl<$Res>
    implements $PermissionResponseCopyWith<$Res> {
  _$PermissionResponseCopyWithImpl(this._self, this._then);

  final PermissionResponse _self;
  final $Res Function(PermissionResponse) _then;

  /// Create a copy of PermissionResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? permitted = null,
    Object? id = null,
    Object? status = null,
  }) {
    return _then(_self.copyWith(
      permitted: null == permitted
          ? _self.permitted
          : permitted // ignore: cast_nullable_to_non_nullable
              as bool,
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [PermissionResponse].
extension PermissionResponsePatterns on PermissionResponse {
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
    TResult Function(_PermissionResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PermissionResponse() when $default != null:
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
    TResult Function(_PermissionResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionResponse():
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
    TResult? Function(_PermissionResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionResponse() when $default != null:
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
    TResult Function(bool permitted, String id, String status)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PermissionResponse() when $default != null:
        return $default(_that.permitted, _that.id, _that.status);
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
    TResult Function(bool permitted, String id, String status) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionResponse():
        return $default(_that.permitted, _that.id, _that.status);
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
    TResult? Function(bool permitted, String id, String status)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PermissionResponse() when $default != null:
        return $default(_that.permitted, _that.id, _that.status);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PermissionResponse implements PermissionResponse {
  const _PermissionResponse(
      {required this.permitted, required this.id, required this.status});
  factory _PermissionResponse.fromJson(Map<String, dynamic> json) =>
      _$PermissionResponseFromJson(json);

  @override
  final bool permitted;
  @override
  final String id;
  @override
  final String status;

  /// Create a copy of PermissionResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PermissionResponseCopyWith<_PermissionResponse> get copyWith =>
      __$PermissionResponseCopyWithImpl<_PermissionResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PermissionResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PermissionResponse &&
            (identical(other.permitted, permitted) ||
                other.permitted == permitted) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, permitted, id, status);

  @override
  String toString() {
    return 'PermissionResponse(permitted: $permitted, id: $id, status: $status)';
  }
}

/// @nodoc
abstract mixin class _$PermissionResponseCopyWith<$Res>
    implements $PermissionResponseCopyWith<$Res> {
  factory _$PermissionResponseCopyWith(
          _PermissionResponse value, $Res Function(_PermissionResponse) _then) =
      __$PermissionResponseCopyWithImpl;
  @override
  @useResult
  $Res call({bool permitted, String id, String status});
}

/// @nodoc
class __$PermissionResponseCopyWithImpl<$Res>
    implements _$PermissionResponseCopyWith<$Res> {
  __$PermissionResponseCopyWithImpl(this._self, this._then);

  final _PermissionResponse _self;
  final $Res Function(_PermissionResponse) _then;

  /// Create a copy of PermissionResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? permitted = null,
    Object? id = null,
    Object? status = null,
  }) {
    return _then(_PermissionResponse(
      permitted: null == permitted
          ? _self.permitted
          : permitted // ignore: cast_nullable_to_non_nullable
              as bool,
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
