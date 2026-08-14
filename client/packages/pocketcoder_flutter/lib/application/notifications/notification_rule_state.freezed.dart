// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_rule_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationRuleState {
  UiFlowStatus get status;
  Map<String, bool> get rules;
  Object? get error;

  /// Create a copy of NotificationRuleState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NotificationRuleStateCopyWith<NotificationRuleState> get copyWith =>
      _$NotificationRuleStateCopyWithImpl<NotificationRuleState>(
          this as NotificationRuleState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NotificationRuleState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.rules, rules) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(rules),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'NotificationRuleState(status: $status, rules: $rules, error: $error)';
  }
}

/// @nodoc
abstract mixin class $NotificationRuleStateCopyWith<$Res> {
  factory $NotificationRuleStateCopyWith(NotificationRuleState value,
          $Res Function(NotificationRuleState) _then) =
      _$NotificationRuleStateCopyWithImpl;
  @useResult
  $Res call({UiFlowStatus status, Map<String, bool> rules, Object? error});
}

/// @nodoc
class _$NotificationRuleStateCopyWithImpl<$Res>
    implements $NotificationRuleStateCopyWith<$Res> {
  _$NotificationRuleStateCopyWithImpl(this._self, this._then);

  final NotificationRuleState _self;
  final $Res Function(NotificationRuleState) _then;

  /// Create a copy of NotificationRuleState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? rules = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      rules: null == rules
          ? _self.rules
          : rules // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

/// Adds pattern-matching-related methods to [NotificationRuleState].
extension NotificationRuleStatePatterns on NotificationRuleState {
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
    TResult Function(_NotificationRuleState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NotificationRuleState() when $default != null:
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
    TResult Function(_NotificationRuleState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationRuleState():
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
    TResult? Function(_NotificationRuleState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationRuleState() when $default != null:
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
            UiFlowStatus status, Map<String, bool> rules, Object? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NotificationRuleState() when $default != null:
        return $default(_that.status, _that.rules, _that.error);
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
            UiFlowStatus status, Map<String, bool> rules, Object? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationRuleState():
        return $default(_that.status, _that.rules, _that.error);
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
            UiFlowStatus status, Map<String, bool> rules, Object? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationRuleState() when $default != null:
        return $default(_that.status, _that.rules, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _NotificationRuleState extends NotificationRuleState {
  const _NotificationRuleState(
      {this.status = UiFlowStatus.idle,
      final Map<String, bool> rules = const {},
      this.error})
      : _rules = rules,
        super._();

  @override
  @JsonKey()
  final UiFlowStatus status;
  final Map<String, bool> _rules;
  @override
  @JsonKey()
  Map<String, bool> get rules {
    if (_rules is EqualUnmodifiableMapView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_rules);
  }

  @override
  final Object? error;

  /// Create a copy of NotificationRuleState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NotificationRuleStateCopyWith<_NotificationRuleState> get copyWith =>
      __$NotificationRuleStateCopyWithImpl<_NotificationRuleState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NotificationRuleState &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            const DeepCollectionEquality().equals(other.error, error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      const DeepCollectionEquality().hash(_rules),
      const DeepCollectionEquality().hash(error));

  @override
  String toString() {
    return 'NotificationRuleState(status: $status, rules: $rules, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$NotificationRuleStateCopyWith<$Res>
    implements $NotificationRuleStateCopyWith<$Res> {
  factory _$NotificationRuleStateCopyWith(_NotificationRuleState value,
          $Res Function(_NotificationRuleState) _then) =
      __$NotificationRuleStateCopyWithImpl;
  @override
  @useResult
  $Res call({UiFlowStatus status, Map<String, bool> rules, Object? error});
}

/// @nodoc
class __$NotificationRuleStateCopyWithImpl<$Res>
    implements _$NotificationRuleStateCopyWith<$Res> {
  __$NotificationRuleStateCopyWithImpl(this._self, this._then);

  final _NotificationRuleState _self;
  final $Res Function(_NotificationRuleState) _then;

  /// Create a copy of NotificationRuleState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? rules = null,
    Object? error = freezed,
  }) {
    return _then(_NotificationRuleState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as UiFlowStatus,
      rules: null == rules
          ? _self._rules
          : rules // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      error: freezed == error ? _self.error : error,
    ));
  }
}

// dart format on
