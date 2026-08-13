// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prompt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Prompt {
  String get id;
  String get name;
  String get body;
  String? get user;
  bool? get isSystem;

  /// Create a copy of Prompt
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PromptCopyWith<Prompt> get copyWith =>
      _$PromptCopyWithImpl<Prompt>(this as Prompt, _$identity);

  /// Serializes this Prompt to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Prompt &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.isSystem, isSystem) ||
                other.isSystem == isSystem));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, body, user, isSystem);

  @override
  String toString() {
    return 'Prompt(id: $id, name: $name, body: $body, user: $user, isSystem: $isSystem)';
  }
}

/// @nodoc
abstract mixin class $PromptCopyWith<$Res> {
  factory $PromptCopyWith(Prompt value, $Res Function(Prompt) _then) =
      _$PromptCopyWithImpl;
  @useResult
  $Res call(
      {String id, String name, String body, String? user, bool? isSystem});
}

/// @nodoc
class _$PromptCopyWithImpl<$Res> implements $PromptCopyWith<$Res> {
  _$PromptCopyWithImpl(this._self, this._then);

  final Prompt _self;
  final $Res Function(Prompt) _then;

  /// Create a copy of Prompt
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? body = null,
    Object? user = freezed,
    Object? isSystem = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      user: freezed == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String?,
      isSystem: freezed == isSystem
          ? _self.isSystem
          : isSystem // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Prompt].
extension PromptPatterns on Prompt {
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
    TResult Function(_Prompt value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Prompt() when $default != null:
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
    TResult Function(_Prompt value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Prompt():
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
    TResult? Function(_Prompt value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Prompt() when $default != null:
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
            String id, String name, String body, String? user, bool? isSystem)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Prompt() when $default != null:
        return $default(
            _that.id, _that.name, _that.body, _that.user, _that.isSystem);
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
            String id, String name, String body, String? user, bool? isSystem)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Prompt():
        return $default(
            _that.id, _that.name, _that.body, _that.user, _that.isSystem);
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
            String id, String name, String body, String? user, bool? isSystem)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Prompt() when $default != null:
        return $default(
            _that.id, _that.name, _that.body, _that.user, _that.isSystem);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Prompt implements Prompt {
  const _Prompt(
      {required this.id,
      required this.name,
      required this.body,
      this.user,
      this.isSystem});
  factory _Prompt.fromJson(Map<String, dynamic> json) => _$PromptFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String body;
  @override
  final String? user;
  @override
  final bool? isSystem;

  /// Create a copy of Prompt
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PromptCopyWith<_Prompt> get copyWith =>
      __$PromptCopyWithImpl<_Prompt>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PromptToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Prompt &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.isSystem, isSystem) ||
                other.isSystem == isSystem));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, body, user, isSystem);

  @override
  String toString() {
    return 'Prompt(id: $id, name: $name, body: $body, user: $user, isSystem: $isSystem)';
  }
}

/// @nodoc
abstract mixin class _$PromptCopyWith<$Res> implements $PromptCopyWith<$Res> {
  factory _$PromptCopyWith(_Prompt value, $Res Function(_Prompt) _then) =
      __$PromptCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id, String name, String body, String? user, bool? isSystem});
}

/// @nodoc
class __$PromptCopyWithImpl<$Res> implements _$PromptCopyWith<$Res> {
  __$PromptCopyWithImpl(this._self, this._then);

  final _Prompt _self;
  final $Res Function(_Prompt) _then;

  /// Create a copy of Prompt
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? body = null,
    Object? user = freezed,
    Object? isSystem = freezed,
  }) {
    return _then(_Prompt(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      user: freezed == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String?,
      isSystem: freezed == isSystem
          ? _self.isSystem
          : isSystem // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

// dart format on
