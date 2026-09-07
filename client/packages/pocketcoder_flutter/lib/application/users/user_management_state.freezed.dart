// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_management_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserManagementState {
  UiFlowStatus get status;
  List<User> get users;
  Object? get error;

  /// Create a copy of UserManagementState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserManagementStateCopyWith<UserManagementState> get copyWith =>
      _$UserManagementStateCopyWithImpl<UserManagementState>(
          this as UserManagementState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is UserManagementState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.users, users) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(users),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'UserManagementState(status: $status, users: $users, error: $error)';
  }
}

/// @nodoc
abstract mixin class $UserManagementStateCopyWith<$Res> {
  factory $UserManagementStateCopyWith(
          UserManagementState value, $Res Function(UserManagementState) _then) =
      _$UserManagementStateCopyWithImpl;
  @useResult
  $Res call(
      {UiFlowStatus status, List<User> users, Object? error});
}

/// @nodoc
class _$UserManagementStateCopyWithImpl<$Res>
    implements $UserManagementStateCopyWith<$Res> {
  _$UserManagementStateCopyWithImpl(this._self, this._then);

  final UserManagementState _self;
  final $Res Function(UserManagementState) _then;

  /// Create a copy of UserManagementState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? users = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      users: null == users
          ? _self.users
          : users // ignore: cast_nullable_to_non_nullable
              as List<User>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [UserManagementState].
extension UserManagementStatePatterns on UserManagementState {
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
    TResult Function(_UserManagementState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserManagementState() when $default != null:
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
    TResult Function(_UserManagementState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserManagementState():
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
    TResult? Function(_UserManagementState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserManagementState() when $default != null:
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
            UiFlowStatus status, List<User> users, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserManagementState() when $default != null:
        return $default(_that.status, _that.users, _that.error);
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
            UiFlowStatus status, List<User> users, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserManagementState():
        return $default(_that.status, _that.users, _that.error);
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
            UiFlowStatus status, List<User> users, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserManagementState() when $default != null:
        return $default(_that.status, _that.users, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _UserManagementState extends UserManagementState {
  const _UserManagementState(
      {this.status = UiFlowStatus.idle,
      final List<User> users = const [],
      this.error})
      : _users = users,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  final List<User> _users;
  @override
  @JsonKey()
  List<User> get users {
    if (_users is EqualUnmodifiableListView) return _users;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_users);
  }

  @override
  final Object? error;

  /// Create a copy of UserManagementState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UserManagementStateCopyWith<_UserManagementState> get copyWith =>
      __$UserManagementStateCopyWithImpl<_UserManagementState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _UserManagementState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality()
                .equals(other._users, _users) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_users),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'UserManagementState(status: $status, users: $users, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$UserManagementStateCopyWith<$Res>
    implements $UserManagementStateCopyWith<$Res> {
  factory _$UserManagementStateCopyWith(
          _UserManagementState value, $Res Function(_UserManagementState) _then) =
      __$UserManagementStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {UiFlowStatus status, List<User> users, Object? error});
}

/// @nodoc
class __$UserManagementStateCopyWithImpl<$Res>
    implements _$UserManagementStateCopyWith<$Res> {
  __$UserManagementStateCopyWithImpl(this._self, this._then);

  final _UserManagementState _self;
  final $Res Function(_UserManagementState) _then;

  /// Create a copy of UserManagementState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? users = null,
    Object? error = freezed,
  }) {
    return _then(_UserManagementState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      users: null == users
          ? _self._users
          : users // ignore: cast_nullable_to_non_nullable
              as List<User>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
