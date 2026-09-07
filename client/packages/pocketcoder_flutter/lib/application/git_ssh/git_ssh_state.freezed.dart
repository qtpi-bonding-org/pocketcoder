// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'git_ssh_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GitSshState {
  UiFlowStatus get status;
  List<GitSshCredential> get credentials;
  List<GitRepositoryAccess> get access;
  Object? get error;

  /// Create a copy of GitSshState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GitSshStateCopyWith<GitSshState> get copyWith =>
      _$GitSshStateCopyWithImpl<GitSshState>(this as GitSshState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GitSshState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality()
                .equals(other.credentials, credentials) &&
            const DeepCollectionEquality().equals(other.access, access) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(credentials),
      const DeepCollectionEquality().hash(access),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'GitSshState(status: $status, credentials: $credentials, access: $access, error: $error)';
  }
}

/// @nodoc
abstract mixin class $GitSshStateCopyWith<$Res> {
  factory $GitSshStateCopyWith(
          GitSshState value, $Res Function(GitSshState) _then) =
      _$GitSshStateCopyWithImpl;
  @useResult
  $Res call(
      {UiFlowStatus status,
      List<GitSshCredential> credentials,
      List<GitRepositoryAccess> access,
      Object? error});
}

/// @nodoc
class _$GitSshStateCopyWithImpl<$Res> implements $GitSshStateCopyWith<$Res> {
  _$GitSshStateCopyWithImpl(this._self, this._then);

  final GitSshState _self;
  final $Res Function(GitSshState) _then;

  /// Create a copy of GitSshState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? credentials = null,
    Object? access = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      credentials: null == credentials
          ? _self.credentials
          : credentials // ignore: cast_nullable_to_non_nullable
              as List<GitSshCredential>,
      access: null == access
          ? _self.access
          : access // ignore: cast_nullable_to_non_nullable
              as List<GitRepositoryAccess>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [GitSshState].
extension GitSshStatePatterns on GitSshState {
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
    TResult Function(_GitSshState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GitSshState() when $default != null:
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
    TResult Function(_GitSshState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitSshState():
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
    TResult? Function(_GitSshState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitSshState() when $default != null:
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
    TResult Function(UiFlowStatus status, List<GitSshCredential> credentials,
            List<GitRepositoryAccess> access, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GitSshState() when $default != null:
        return $default(
            _that.status, _that.credentials, _that.access, _that.error);
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
    TResult Function(UiFlowStatus status, List<GitSshCredential> credentials,
            List<GitRepositoryAccess> access, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitSshState():
        return $default(
            _that.status, _that.credentials, _that.access, _that.error);
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
    TResult? Function(UiFlowStatus status, List<GitSshCredential> credentials,
            List<GitRepositoryAccess> access, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GitSshState() when $default != null:
        return $default(
            _that.status, _that.credentials, _that.access, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _GitSshState extends GitSshState {
  const _GitSshState(
      {this.status = UiFlowStatus.idle,
      final List<GitSshCredential> credentials = const [],
      final List<GitRepositoryAccess> access = const [],
      this.error})
      : _credentials = credentials,
        _access = access,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  final List<GitSshCredential> _credentials;
  @override
  @JsonKey()
  List<GitSshCredential> get credentials {
    if (_credentials is EqualUnmodifiableListView) return _credentials;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_credentials);
  }

  final List<GitRepositoryAccess> _access;
  @override
  @JsonKey()
  List<GitRepositoryAccess> get access {
    if (_access is EqualUnmodifiableListView) return _access;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_access);
  }

  @override
  final Object? error;

  /// Create a copy of GitSshState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GitSshStateCopyWith<_GitSshState> get copyWith =>
      __$GitSshStateCopyWithImpl<_GitSshState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _GitSshState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality()
                .equals(other._credentials, _credentials) &&
            const DeepCollectionEquality().equals(other._access, _access) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_credentials),
      const DeepCollectionEquality().hash(_access),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'GitSshState(status: $status, credentials: $credentials, access: $access, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$GitSshStateCopyWith<$Res>
    implements $GitSshStateCopyWith<$Res> {
  factory _$GitSshStateCopyWith(
          _GitSshState value, $Res Function(_GitSshState) _then) =
      __$GitSshStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {UiFlowStatus status,
      List<GitSshCredential> credentials,
      List<GitRepositoryAccess> access,
      Object? error});
}

/// @nodoc
class __$GitSshStateCopyWithImpl<$Res> implements _$GitSshStateCopyWith<$Res> {
  __$GitSshStateCopyWithImpl(this._self, this._then);

  final _GitSshState _self;
  final $Res Function(_GitSshState) _then;

  /// Create a copy of GitSshState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? credentials = null,
    Object? access = null,
    Object? error = freezed,
  }) {
    return _then(_GitSshState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      credentials: null == credentials
          ? _self._credentials
          : credentials // ignore: cast_nullable_to_non_nullable
              as List<GitSshCredential>,
      access: null == access
          ? _self._access
          : access // ignore: cast_nullable_to_non_nullable
              as List<GitRepositoryAccess>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
