// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule_owner.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ScheduleOwner {
  String get id;
  String get user;
  String get gooseScheduleId;
  String get displayName;

  /// Create a copy of ScheduleOwner
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ScheduleOwnerCopyWith<ScheduleOwner> get copyWith =>
      _$ScheduleOwnerCopyWithImpl<ScheduleOwner>(
          this as ScheduleOwner, _$identity);

  /// Serializes this ScheduleOwner to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ScheduleOwner &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.gooseScheduleId, gooseScheduleId) ||
                other.gooseScheduleId == gooseScheduleId) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, user, gooseScheduleId, displayName);

  @override
  String toString() {
    return 'ScheduleOwner(id: $id, user: $user, gooseScheduleId: $gooseScheduleId, displayName: $displayName)';
  }
}

/// @nodoc
abstract mixin class $ScheduleOwnerCopyWith<$Res> {
  factory $ScheduleOwnerCopyWith(
          ScheduleOwner value, $Res Function(ScheduleOwner) _then) =
      _$ScheduleOwnerCopyWithImpl;
  @useResult
  $Res call(
      {String id, String user, String gooseScheduleId, String displayName});
}

/// @nodoc
class _$ScheduleOwnerCopyWithImpl<$Res>
    implements $ScheduleOwnerCopyWith<$Res> {
  _$ScheduleOwnerCopyWithImpl(this._self, this._then);

  final ScheduleOwner _self;
  final $Res Function(ScheduleOwner) _then;

  /// Create a copy of ScheduleOwner
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? gooseScheduleId = null,
    Object? displayName = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      gooseScheduleId: null == gooseScheduleId
          ? _self.gooseScheduleId
          : gooseScheduleId // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [ScheduleOwner].
extension ScheduleOwnerPatterns on ScheduleOwner {
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
    TResult Function(_ScheduleOwner value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ScheduleOwner() when $default != null:
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
    TResult Function(_ScheduleOwner value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ScheduleOwner():
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
    TResult? Function(_ScheduleOwner value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ScheduleOwner() when $default != null:
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
            String id, String user, String gooseScheduleId, String displayName)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ScheduleOwner() when $default != null:
        return $default(
            _that.id, _that.user, _that.gooseScheduleId, _that.displayName);
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
            String id, String user, String gooseScheduleId, String displayName)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ScheduleOwner():
        return $default(
            _that.id, _that.user, _that.gooseScheduleId, _that.displayName);
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
            String id, String user, String gooseScheduleId, String displayName)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ScheduleOwner() when $default != null:
        return $default(
            _that.id, _that.user, _that.gooseScheduleId, _that.displayName);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ScheduleOwner implements ScheduleOwner {
  const _ScheduleOwner(
      {required this.id,
      required this.user,
      required this.gooseScheduleId,
      required this.displayName});
  factory _ScheduleOwner.fromJson(Map<String, dynamic> json) =>
      _$ScheduleOwnerFromJson(json);

  @override
  final String id;
  @override
  final String user;
  @override
  final String gooseScheduleId;
  @override
  final String displayName;

  /// Create a copy of ScheduleOwner
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ScheduleOwnerCopyWith<_ScheduleOwner> get copyWith =>
      __$ScheduleOwnerCopyWithImpl<_ScheduleOwner>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ScheduleOwnerToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ScheduleOwner &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.gooseScheduleId, gooseScheduleId) ||
                other.gooseScheduleId == gooseScheduleId) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, user, gooseScheduleId, displayName);

  @override
  String toString() {
    return 'ScheduleOwner(id: $id, user: $user, gooseScheduleId: $gooseScheduleId, displayName: $displayName)';
  }
}

/// @nodoc
abstract mixin class _$ScheduleOwnerCopyWith<$Res>
    implements $ScheduleOwnerCopyWith<$Res> {
  factory _$ScheduleOwnerCopyWith(
          _ScheduleOwner value, $Res Function(_ScheduleOwner) _then) =
      __$ScheduleOwnerCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id, String user, String gooseScheduleId, String displayName});
}

/// @nodoc
class __$ScheduleOwnerCopyWithImpl<$Res>
    implements _$ScheduleOwnerCopyWith<$Res> {
  __$ScheduleOwnerCopyWithImpl(this._self, this._then);

  final _ScheduleOwner _self;
  final $Res Function(_ScheduleOwner) _then;

  /// Create a copy of ScheduleOwner
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? gooseScheduleId = null,
    Object? displayName = null,
  }) {
    return _then(_ScheduleOwner(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      gooseScheduleId: null == gooseScheduleId
          ? _self.gooseScheduleId
          : gooseScheduleId // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
