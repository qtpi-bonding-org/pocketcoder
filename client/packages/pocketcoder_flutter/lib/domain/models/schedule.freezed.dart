// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Schedule {
  String get id;
  @JsonKey(name: 'displayName')
  String get displayName;
  String get cron;
  bool get paused;
  @JsonKey(name: 'currentlyRunning')
  bool get currentlyRunning;
  @JsonKey(name: 'lastRun')
  String? get lastRun;

  /// Create a copy of Schedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ScheduleCopyWith<Schedule> get copyWith =>
      _$ScheduleCopyWithImpl<Schedule>(this as Schedule, _$identity);

  /// Serializes this Schedule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Schedule &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.cron, cron) || other.cron == cron) &&
            (identical(other.paused, paused) || other.paused == paused) &&
            (identical(other.currentlyRunning, currentlyRunning) ||
                other.currentlyRunning == currentlyRunning) &&
            (identical(other.lastRun, lastRun) || other.lastRun == lastRun));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, displayName, cron, paused, currentlyRunning, lastRun);

  @override
  String toString() {
    return 'Schedule(id: $id, displayName: $displayName, cron: $cron, paused: $paused, currentlyRunning: $currentlyRunning, lastRun: $lastRun)';
  }
}

/// @nodoc
abstract mixin class $ScheduleCopyWith<$Res> {
  factory $ScheduleCopyWith(Schedule value, $Res Function(Schedule) _then) =
      _$ScheduleCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'displayName') String displayName,
      String cron,
      bool paused,
      @JsonKey(name: 'currentlyRunning') bool currentlyRunning,
      @JsonKey(name: 'lastRun') String? lastRun});
}

/// @nodoc
class _$ScheduleCopyWithImpl<$Res> implements $ScheduleCopyWith<$Res> {
  _$ScheduleCopyWithImpl(this._self, this._then);

  final Schedule _self;
  final $Res Function(Schedule) _then;

  /// Create a copy of Schedule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? cron = null,
    Object? paused = null,
    Object? currentlyRunning = null,
    Object? lastRun = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      cron: null == cron
          ? _self.cron
          : cron // ignore: cast_nullable_to_non_nullable
              as String,
      paused: null == paused
          ? _self.paused
          : paused // ignore: cast_nullable_to_non_nullable
              as bool,
      currentlyRunning: null == currentlyRunning
          ? _self.currentlyRunning
          : currentlyRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      lastRun: freezed == lastRun
          ? _self.lastRun
          : lastRun // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Schedule].
extension SchedulePatterns on Schedule {
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
    TResult Function(_Schedule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Schedule() when $default != null:
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
    TResult Function(_Schedule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Schedule():
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
    TResult? Function(_Schedule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Schedule() when $default != null:
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
            @JsonKey(name: 'displayName') String displayName,
            String cron,
            bool paused,
            @JsonKey(name: 'currentlyRunning') bool currentlyRunning,
            @JsonKey(name: 'lastRun') String? lastRun)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Schedule() when $default != null:
        return $default(_that.id, _that.displayName, _that.cron, _that.paused,
            _that.currentlyRunning, _that.lastRun);
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
            @JsonKey(name: 'displayName') String displayName,
            String cron,
            bool paused,
            @JsonKey(name: 'currentlyRunning') bool currentlyRunning,
            @JsonKey(name: 'lastRun') String? lastRun)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Schedule():
        return $default(_that.id, _that.displayName, _that.cron, _that.paused,
            _that.currentlyRunning, _that.lastRun);
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
            @JsonKey(name: 'displayName') String displayName,
            String cron,
            bool paused,
            @JsonKey(name: 'currentlyRunning') bool currentlyRunning,
            @JsonKey(name: 'lastRun') String? lastRun)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Schedule() when $default != null:
        return $default(_that.id, _that.displayName, _that.cron, _that.paused,
            _that.currentlyRunning, _that.lastRun);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Schedule implements Schedule {
  const _Schedule(
      {required this.id,
      @JsonKey(name: 'displayName') required this.displayName,
      required this.cron,
      required this.paused,
      @JsonKey(name: 'currentlyRunning') required this.currentlyRunning,
      @JsonKey(name: 'lastRun') this.lastRun});
  factory _Schedule.fromJson(Map<String, dynamic> json) =>
      _$ScheduleFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'displayName')
  final String displayName;
  @override
  final String cron;
  @override
  final bool paused;
  @override
  @JsonKey(name: 'currentlyRunning')
  final bool currentlyRunning;
  @override
  @JsonKey(name: 'lastRun')
  final String? lastRun;

  /// Create a copy of Schedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ScheduleCopyWith<_Schedule> get copyWith =>
      __$ScheduleCopyWithImpl<_Schedule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ScheduleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Schedule &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.cron, cron) || other.cron == cron) &&
            (identical(other.paused, paused) || other.paused == paused) &&
            (identical(other.currentlyRunning, currentlyRunning) ||
                other.currentlyRunning == currentlyRunning) &&
            (identical(other.lastRun, lastRun) || other.lastRun == lastRun));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, displayName, cron, paused, currentlyRunning, lastRun);

  @override
  String toString() {
    return 'Schedule(id: $id, displayName: $displayName, cron: $cron, paused: $paused, currentlyRunning: $currentlyRunning, lastRun: $lastRun)';
  }
}

/// @nodoc
abstract mixin class _$ScheduleCopyWith<$Res>
    implements $ScheduleCopyWith<$Res> {
  factory _$ScheduleCopyWith(_Schedule value, $Res Function(_Schedule) _then) =
      __$ScheduleCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'displayName') String displayName,
      String cron,
      bool paused,
      @JsonKey(name: 'currentlyRunning') bool currentlyRunning,
      @JsonKey(name: 'lastRun') String? lastRun});
}

/// @nodoc
class __$ScheduleCopyWithImpl<$Res> implements _$ScheduleCopyWith<$Res> {
  __$ScheduleCopyWithImpl(this._self, this._then);

  final _Schedule _self;
  final $Res Function(_Schedule) _then;

  /// Create a copy of Schedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? cron = null,
    Object? paused = null,
    Object? currentlyRunning = null,
    Object? lastRun = freezed,
  }) {
    return _then(_Schedule(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      cron: null == cron
          ? _self.cron
          : cron // ignore: cast_nullable_to_non_nullable
              as String,
      paused: null == paused
          ? _self.paused
          : paused // ignore: cast_nullable_to_non_nullable
              as bool,
      currentlyRunning: null == currentlyRunning
          ? _self.currentlyRunning
          : currentlyRunning // ignore: cast_nullable_to_non_nullable
              as bool,
      lastRun: freezed == lastRun
          ? _self.lastRun
          : lastRun // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
