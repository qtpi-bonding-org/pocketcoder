// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_rule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationRule {
  String get id;
  String get user;
  dynamic get rules;

  /// Create a copy of NotificationRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NotificationRuleCopyWith<NotificationRule> get copyWith =>
      _$NotificationRuleCopyWithImpl<NotificationRule>(
          this as NotificationRule, _$identity);

  /// Serializes this NotificationRule to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NotificationRule &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            const DeepCollectionEquality().equals(other.rules, rules));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, user, const DeepCollectionEquality().hash(rules));

  @override
  String toString() {
    return 'NotificationRule(id: $id, user: $user, rules: $rules)';
  }
}

/// @nodoc
abstract mixin class $NotificationRuleCopyWith<$Res> {
  factory $NotificationRuleCopyWith(
          NotificationRule value, $Res Function(NotificationRule) _then) =
      _$NotificationRuleCopyWithImpl;
  @useResult
  $Res call({String id, String user, dynamic rules});
}

/// @nodoc
class _$NotificationRuleCopyWithImpl<$Res>
    implements $NotificationRuleCopyWith<$Res> {
  _$NotificationRuleCopyWithImpl(this._self, this._then);

  final NotificationRule _self;
  final $Res Function(NotificationRule) _then;

  /// Create a copy of NotificationRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? rules = freezed,
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
      rules: freezed == rules
          ? _self.rules
          : rules // ignore: cast_nullable_to_non_nullable
              as dynamic,
    ));
  }
}

/// Adds pattern-matching-related methods to [NotificationRule].
extension NotificationRulePatterns on NotificationRule {
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
    TResult Function(_NotificationRule value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NotificationRule() when $default != null:
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
    TResult Function(_NotificationRule value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationRule():
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
    TResult? Function(_NotificationRule value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationRule() when $default != null:
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
    TResult Function(String id, String user, dynamic rules)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NotificationRule() when $default != null:
        return $default(_that.id, _that.user, _that.rules);
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
    TResult Function(String id, String user, dynamic rules) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationRule():
        return $default(_that.id, _that.user, _that.rules);
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
    TResult? Function(String id, String user, dynamic rules)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationRule() when $default != null:
        return $default(_that.id, _that.user, _that.rules);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _NotificationRule implements NotificationRule {
  const _NotificationRule({required this.id, required this.user, this.rules});
  factory _NotificationRule.fromJson(Map<String, dynamic> json) =>
      _$NotificationRuleFromJson(json);

  @override
  final String id;
  @override
  final String user;
  @override
  final dynamic rules;

  /// Create a copy of NotificationRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NotificationRuleCopyWith<_NotificationRule> get copyWith =>
      __$NotificationRuleCopyWithImpl<_NotificationRule>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$NotificationRuleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NotificationRule &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.user, user) || other.user == user) &&
            const DeepCollectionEquality().equals(other.rules, rules));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, user, const DeepCollectionEquality().hash(rules));

  @override
  String toString() {
    return 'NotificationRule(id: $id, user: $user, rules: $rules)';
  }
}

/// @nodoc
abstract mixin class _$NotificationRuleCopyWith<$Res>
    implements $NotificationRuleCopyWith<$Res> {
  factory _$NotificationRuleCopyWith(
          _NotificationRule value, $Res Function(_NotificationRule) _then) =
      __$NotificationRuleCopyWithImpl;
  @override
  @useResult
  $Res call({String id, String user, dynamic rules});
}

/// @nodoc
class __$NotificationRuleCopyWithImpl<$Res>
    implements _$NotificationRuleCopyWith<$Res> {
  __$NotificationRuleCopyWithImpl(this._self, this._then);

  final _NotificationRule _self;
  final $Res Function(_NotificationRule) _then;

  /// Create a copy of NotificationRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? user = null,
    Object? rules = freezed,
  }) {
    return _then(_NotificationRule(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      rules: freezed == rules
          ? _self.rules
          : rules // ignore: cast_nullable_to_non_nullable
              as dynamic,
    ));
  }
}

// dart format on
