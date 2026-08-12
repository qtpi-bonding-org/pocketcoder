// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sandbox_agent_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SandboxAgentState {
  List<SandboxAgent> get sandboxAgents;
  bool get isLoading;
  String? get error;

  /// Create a copy of SandboxAgentState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SandboxAgentStateCopyWith<SandboxAgentState> get copyWith =>
      _$SandboxAgentStateCopyWithImpl<SandboxAgentState>(
          this as SandboxAgentState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SandboxAgentState &&
            const DeepCollectionEquality()
                .equals(other.sandboxAgents, sandboxAgents) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(sandboxAgents), isLoading, error);

  @override
  String toString() {
    return 'SandboxAgentState(sandboxAgents: $sandboxAgents, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class $SandboxAgentStateCopyWith<$Res> {
  factory $SandboxAgentStateCopyWith(
          SandboxAgentState value, $Res Function(SandboxAgentState) _then) =
      _$SandboxAgentStateCopyWithImpl;
  @useResult
  $Res call({List<SandboxAgent> sandboxAgents, bool isLoading, String? error});
}

/// @nodoc
class _$SandboxAgentStateCopyWithImpl<$Res>
    implements $SandboxAgentStateCopyWith<$Res> {
  _$SandboxAgentStateCopyWithImpl(this._self, this._then);

  final SandboxAgentState _self;
  final $Res Function(SandboxAgentState) _then;

  /// Create a copy of SandboxAgentState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sandboxAgents = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      sandboxAgents: null == sandboxAgents
          ? _self.sandboxAgents
          : sandboxAgents // ignore: cast_nullable_to_non_nullable
              as List<SandboxAgent>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SandboxAgentState].
extension SandboxAgentStatePatterns on SandboxAgentState {
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
    TResult Function(_SandboxAgentState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SandboxAgentState() when $default != null:
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
    TResult Function(_SandboxAgentState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SandboxAgentState():
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
    TResult? Function(_SandboxAgentState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SandboxAgentState() when $default != null:
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
            List<SandboxAgent> sandboxAgents, bool isLoading, String? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SandboxAgentState() when $default != null:
        return $default(_that.sandboxAgents, _that.isLoading, _that.error);
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
            List<SandboxAgent> sandboxAgents, bool isLoading, String? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SandboxAgentState():
        return $default(_that.sandboxAgents, _that.isLoading, _that.error);
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
            List<SandboxAgent> sandboxAgents, bool isLoading, String? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SandboxAgentState() when $default != null:
        return $default(_that.sandboxAgents, _that.isLoading, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SandboxAgentState implements SandboxAgentState {
  const _SandboxAgentState(
      {final List<SandboxAgent> sandboxAgents = const [],
      this.isLoading = false,
      this.error})
      : _sandboxAgents = sandboxAgents;

  final List<SandboxAgent> _sandboxAgents;
  @override
  @JsonKey()
  List<SandboxAgent> get sandboxAgents {
    if (_sandboxAgents is EqualUnmodifiableListView) return _sandboxAgents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sandboxAgents);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  /// Create a copy of SandboxAgentState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SandboxAgentStateCopyWith<_SandboxAgentState> get copyWith =>
      __$SandboxAgentStateCopyWithImpl<_SandboxAgentState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SandboxAgentState &&
            const DeepCollectionEquality()
                .equals(other._sandboxAgents, _sandboxAgents) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_sandboxAgents), isLoading, error);

  @override
  String toString() {
    return 'SandboxAgentState(sandboxAgents: $sandboxAgents, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$SandboxAgentStateCopyWith<$Res>
    implements $SandboxAgentStateCopyWith<$Res> {
  factory _$SandboxAgentStateCopyWith(
          _SandboxAgentState value, $Res Function(_SandboxAgentState) _then) =
      __$SandboxAgentStateCopyWithImpl;
  @override
  @useResult
  $Res call({List<SandboxAgent> sandboxAgents, bool isLoading, String? error});
}

/// @nodoc
class __$SandboxAgentStateCopyWithImpl<$Res>
    implements _$SandboxAgentStateCopyWith<$Res> {
  __$SandboxAgentStateCopyWithImpl(this._self, this._then);

  final _SandboxAgentState _self;
  final $Res Function(_SandboxAgentState) _then;

  /// Create a copy of SandboxAgentState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sandboxAgents = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_SandboxAgentState(
      sandboxAgents: null == sandboxAgents
          ? _self._sandboxAgents
          : sandboxAgents // ignore: cast_nullable_to_non_nullable
              as List<SandboxAgent>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
