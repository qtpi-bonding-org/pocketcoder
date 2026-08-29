// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'observability_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ObservabilityState {
  SystemStats? get stats;
  List<LogEntry> get logs;
  List<ContainerInfo> get containers;
  UiFlowStatus get status;
  String? get currentContainer;
  Object? get error;

  /// Create a copy of ObservabilityState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ObservabilityStateCopyWith<ObservabilityState> get copyWith =>
      _$ObservabilityStateCopyWithImpl<ObservabilityState>(
          this as ObservabilityState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ObservabilityState &&
            (identical(other.stats, stats) || other.stats == stats) &&
            const DeepCollectionEquality().equals(other.logs, logs) &&
            const DeepCollectionEquality()
                .equals(other.containers, containers) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.currentContainer, currentContainer) ||
                other.currentContainer == currentContainer) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      stats,
      const DeepCollectionEquality().hash(logs),
      const DeepCollectionEquality().hash(containers),
      status,
      currentContainer,
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'ObservabilityState(stats: $stats, logs: $logs, containers: $containers, status: $status, currentContainer: $currentContainer, error: $error)';
  }
}

/// @nodoc
abstract mixin class $ObservabilityStateCopyWith<$Res> {
  factory $ObservabilityStateCopyWith(
          ObservabilityState value, $Res Function(ObservabilityState) _then) =
      _$ObservabilityStateCopyWithImpl;
  @useResult
  $Res call(
      {SystemStats? stats,
      List<LogEntry> logs,
      List<ContainerInfo> containers,
      UiFlowStatus status,
      String? currentContainer,
      Object? error});

  $SystemStatsCopyWith<$Res>? get stats;
}

/// @nodoc
class _$ObservabilityStateCopyWithImpl<$Res>
    implements $ObservabilityStateCopyWith<$Res> {
  _$ObservabilityStateCopyWithImpl(this._self, this._then);

  final ObservabilityState _self;
  final $Res Function(ObservabilityState) _then;

  /// Create a copy of ObservabilityState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stats = freezed,
    Object? logs = null,
    Object? containers = null,
    Object? status = null,
    Object? currentContainer = freezed,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      stats: freezed == stats
          ? _self.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as SystemStats?,
      logs: null == logs
          ? _self.logs
          : logs // ignore: cast_nullable_to_non_nullable
              as List<LogEntry>,
      containers: null == containers
          ? _self.containers
          : containers // ignore: cast_nullable_to_non_nullable
              as List<ContainerInfo>,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      currentContainer: freezed == currentContainer
          ? _self.currentContainer
          : currentContainer // ignore: cast_nullable_to_non_nullable
              as String?,
      error: freezed == error ? _self.error : error,
    ));
  }

  /// Create a copy of ObservabilityState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SystemStatsCopyWith<$Res>? get stats {
    if (_self.stats == null) {
      return null;
    }

    return $SystemStatsCopyWith<$Res>(_self.stats!, (value) {
      return _then(_self.copyWith(stats: value));
    });
  }
}

/// Adds pattern-matching-related methods to [ObservabilityState].
extension ObservabilityStatePatterns on ObservabilityState {
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
    TResult Function(_ObservabilityState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ObservabilityState() when $default != null:
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
    TResult Function(_ObservabilityState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ObservabilityState():
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
    TResult? Function(_ObservabilityState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ObservabilityState() when $default != null:
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
            SystemStats? stats,
            List<LogEntry> logs,
            List<ContainerInfo> containers,
            UiFlowStatus status,
            String? currentContainer,
            Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ObservabilityState() when $default != null:
        return $default(_that.stats, _that.logs, _that.containers, _that.status,
            _that.currentContainer, _that.error);
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
            SystemStats? stats,
            List<LogEntry> logs,
            List<ContainerInfo> containers,
            UiFlowStatus status,
            String? currentContainer,
            Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ObservabilityState():
        return $default(_that.stats, _that.logs, _that.containers, _that.status,
            _that.currentContainer, _that.error);
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
            SystemStats? stats,
            List<LogEntry> logs,
            List<ContainerInfo> containers,
            UiFlowStatus status,
            String? currentContainer,
            Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ObservabilityState() when $default != null:
        return $default(_that.stats, _that.logs, _that.containers, _that.status,
            _that.currentContainer, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ObservabilityState extends ObservabilityState {
  const _ObservabilityState(
      {this.stats,
      final List<LogEntry> logs = const [],
      final List<ContainerInfo> containers = const [],
      this.status = UiFlowStatus.idle,
      this.currentContainer,
      this.error})
      : _logs = logs,
        _containers = containers,
        super._();

  @override
  final SystemStats? stats;
  final List<LogEntry> _logs;
  @override
  @JsonKey()
  List<LogEntry> get logs {
    if (_logs is EqualUnmodifiableListView) return _logs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_logs);
  }

  final List<ContainerInfo> _containers;
  @override
  @JsonKey()
  List<ContainerInfo> get containers {
    if (_containers is EqualUnmodifiableListView) return _containers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_containers);
  }

  @override
  @JsonKey()
  final UiFlowStatus status;
  @override
  final String? currentContainer;
  @override
  final Object? error;

  /// Create a copy of ObservabilityState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ObservabilityStateCopyWith<_ObservabilityState> get copyWith =>
      __$ObservabilityStateCopyWithImpl<_ObservabilityState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ObservabilityState &&
            (identical(other.stats, stats) || other.stats == stats) &&
            const DeepCollectionEquality().equals(other._logs, _logs) &&
            const DeepCollectionEquality()
                .equals(other._containers, _containers) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.currentContainer, currentContainer) ||
                other.currentContainer == currentContainer) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      stats,
      const DeepCollectionEquality().hash(_logs),
      const DeepCollectionEquality().hash(_containers),
      status,
      currentContainer,
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'ObservabilityState(stats: $stats, logs: $logs, containers: $containers, status: $status, currentContainer: $currentContainer, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$ObservabilityStateCopyWith<$Res>
    implements $ObservabilityStateCopyWith<$Res> {
  factory _$ObservabilityStateCopyWith(
          _ObservabilityState value, $Res Function(_ObservabilityState) _then) =
      __$ObservabilityStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {SystemStats? stats,
      List<LogEntry> logs,
      List<ContainerInfo> containers,
      UiFlowStatus status,
      String? currentContainer,
      Object? error});

  @override
  $SystemStatsCopyWith<$Res>? get stats;
}

/// @nodoc
class __$ObservabilityStateCopyWithImpl<$Res>
    implements _$ObservabilityStateCopyWith<$Res> {
  __$ObservabilityStateCopyWithImpl(this._self, this._then);

  final _ObservabilityState _self;
  final $Res Function(_ObservabilityState) _then;

  /// Create a copy of ObservabilityState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? stats = freezed,
    Object? logs = null,
    Object? containers = null,
    Object? status = null,
    Object? currentContainer = freezed,
    Object? error = freezed,
  }) {
    return _then(_ObservabilityState(
      stats: freezed == stats
          ? _self.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as SystemStats?,
      logs: null == logs
          ? _self._logs
          : logs // ignore: cast_nullable_to_non_nullable
              as List<LogEntry>,
      containers: null == containers
          ? _self._containers
          : containers // ignore: cast_nullable_to_non_nullable
              as List<ContainerInfo>,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      currentContainer: freezed == currentContainer
          ? _self.currentContainer
          : currentContainer // ignore: cast_nullable_to_non_nullable
              as String?,
      error: freezed == error ? _self.error : error,
    ));
  }

  /// Create a copy of ObservabilityState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SystemStatsCopyWith<$Res>? get stats {
    if (_self.stats == null) {
      return null;
    }

    return $SystemStatsCopyWith<$Res>(_self.stats!, (value) {
      return _then(_self.copyWith(stats: value));
    });
  }
}

// dart format on
