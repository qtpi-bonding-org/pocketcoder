// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mcp_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$McpState {
  UiFlowStatus get status;
  List<McpServer> get servers;
  Object? get error;

  /// Create a copy of McpState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $McpStateCopyWith<McpState> get copyWith =>
      _$McpStateCopyWithImpl<McpState>(this as McpState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is McpState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.servers, servers) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(servers),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'McpState(status: $status, servers: $servers, error: $error)';
  }
}

/// @nodoc
abstract mixin class $McpStateCopyWith<$Res> {
  factory $McpStateCopyWith(McpState value, $Res Function(McpState) _then) =
      _$McpStateCopyWithImpl;
  @useResult
  $Res call({UiFlowStatus status, List<McpServer> servers, Object? error});
}

/// @nodoc
class _$McpStateCopyWithImpl<$Res> implements $McpStateCopyWith<$Res> {
  _$McpStateCopyWithImpl(this._self, this._then);

  final McpState _self;
  final $Res Function(McpState) _then;

  /// Create a copy of McpState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? servers = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      servers: null == servers
          ? _self.servers
          : servers // ignore: cast_nullable_to_non_nullable
              as List<McpServer>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [McpState].
extension McpStatePatterns on McpState {
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
    TResult Function(_McpState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _McpState() when $default != null:
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
    TResult Function(_McpState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _McpState():
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
    TResult? Function(_McpState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _McpState() when $default != null:
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
            UiFlowStatus status, List<McpServer> servers, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _McpState() when $default != null:
        return $default(_that.status, _that.servers, _that.error);
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
            UiFlowStatus status, List<McpServer> servers, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _McpState():
        return $default(_that.status, _that.servers, _that.error);
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
            UiFlowStatus status, List<McpServer> servers, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _McpState() when $default != null:
        return $default(_that.status, _that.servers, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _McpState extends McpState {
  const _McpState(
      {this.status = UiFlowStatus.idle,
      final List<McpServer> servers = const [],
      this.error})
      : _servers = servers,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  final List<McpServer> _servers;
  @override
  @JsonKey()
  List<McpServer> get servers {
    if (_servers is EqualUnmodifiableListView) return _servers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_servers);
  }

  @override
  final Object? error;

  /// Create a copy of McpState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$McpStateCopyWith<_McpState> get copyWith =>
      __$McpStateCopyWithImpl<_McpState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _McpState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._servers, _servers) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_servers),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'McpState(status: $status, servers: $servers, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$McpStateCopyWith<$Res>
    implements $McpStateCopyWith<$Res> {
  factory _$McpStateCopyWith(_McpState value, $Res Function(_McpState) _then) =
      __$McpStateCopyWithImpl;
  @override
  @useResult
  $Res call({UiFlowStatus status, List<McpServer> servers, Object? error});
}

/// @nodoc
class __$McpStateCopyWithImpl<$Res> implements _$McpStateCopyWith<$Res> {
  __$McpStateCopyWithImpl(this._self, this._then);

  final _McpState _self;
  final $Res Function(_McpState) _then;

  /// Create a copy of McpState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? servers = null,
    Object? error = freezed,
  }) {
    return _then(_McpState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      servers: null == servers
          ? _self._servers
          : servers // ignore: cast_nullable_to_non_nullable
              as List<McpServer>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
