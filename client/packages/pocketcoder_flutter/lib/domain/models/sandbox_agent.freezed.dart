// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sandbox_agent.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SandboxAgent {
  String get id;
  String get sandboxAgentId;
  String get delegatingAgentId;
  double? get tmuxWindowId;
  String? get chat;

  /// Create a copy of SandboxAgent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SandboxAgentCopyWith<SandboxAgent> get copyWith =>
      _$SandboxAgentCopyWithImpl<SandboxAgent>(
          this as SandboxAgent, _$identity);

  /// Serializes this SandboxAgent to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SandboxAgent &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sandboxAgentId, sandboxAgentId) ||
                other.sandboxAgentId == sandboxAgentId) &&
            (identical(other.delegatingAgentId, delegatingAgentId) ||
                other.delegatingAgentId == delegatingAgentId) &&
            (identical(other.tmuxWindowId, tmuxWindowId) ||
                other.tmuxWindowId == tmuxWindowId) &&
            (identical(other.chat, chat) || other.chat == chat));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, sandboxAgentId, delegatingAgentId, tmuxWindowId, chat);

  @override
  String toString() {
    return 'SandboxAgent(id: $id, sandboxAgentId: $sandboxAgentId, delegatingAgentId: $delegatingAgentId, tmuxWindowId: $tmuxWindowId, chat: $chat)';
  }
}

/// @nodoc
abstract mixin class $SandboxAgentCopyWith<$Res> {
  factory $SandboxAgentCopyWith(
          SandboxAgent value, $Res Function(SandboxAgent) _then) =
      _$SandboxAgentCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String sandboxAgentId,
      String delegatingAgentId,
      double? tmuxWindowId,
      String? chat});
}

/// @nodoc
class _$SandboxAgentCopyWithImpl<$Res> implements $SandboxAgentCopyWith<$Res> {
  _$SandboxAgentCopyWithImpl(this._self, this._then);

  final SandboxAgent _self;
  final $Res Function(SandboxAgent) _then;

  /// Create a copy of SandboxAgent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sandboxAgentId = null,
    Object? delegatingAgentId = null,
    Object? tmuxWindowId = freezed,
    Object? chat = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sandboxAgentId: null == sandboxAgentId
          ? _self.sandboxAgentId
          : sandboxAgentId // ignore: cast_nullable_to_non_nullable
              as String,
      delegatingAgentId: null == delegatingAgentId
          ? _self.delegatingAgentId
          : delegatingAgentId // ignore: cast_nullable_to_non_nullable
              as String,
      tmuxWindowId: freezed == tmuxWindowId
          ? _self.tmuxWindowId
          : tmuxWindowId // ignore: cast_nullable_to_non_nullable
              as double?,
      chat: freezed == chat
          ? _self.chat
          : chat // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SandboxAgent].
extension SandboxAgentPatterns on SandboxAgent {
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
    TResult Function(_SandboxAgent value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SandboxAgent() when $default != null:
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
    TResult Function(_SandboxAgent value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SandboxAgent():
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
    TResult? Function(_SandboxAgent value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SandboxAgent() when $default != null:
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
    TResult Function(String id, String sandboxAgentId, String delegatingAgentId,
            double? tmuxWindowId, String? chat)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SandboxAgent() when $default != null:
        return $default(_that.id, _that.sandboxAgentId, _that.delegatingAgentId,
            _that.tmuxWindowId, _that.chat);
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
    TResult Function(String id, String sandboxAgentId, String delegatingAgentId,
            double? tmuxWindowId, String? chat)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SandboxAgent():
        return $default(_that.id, _that.sandboxAgentId, _that.delegatingAgentId,
            _that.tmuxWindowId, _that.chat);
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
    TResult? Function(String id, String sandboxAgentId,
            String delegatingAgentId, double? tmuxWindowId, String? chat)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SandboxAgent() when $default != null:
        return $default(_that.id, _that.sandboxAgentId, _that.delegatingAgentId,
            _that.tmuxWindowId, _that.chat);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SandboxAgent implements SandboxAgent {
  const _SandboxAgent(
      {required this.id,
      required this.sandboxAgentId,
      required this.delegatingAgentId,
      this.tmuxWindowId,
      this.chat});
  factory _SandboxAgent.fromJson(Map<String, dynamic> json) =>
      _$SandboxAgentFromJson(json);

  @override
  final String id;
  @override
  final String sandboxAgentId;
  @override
  final String delegatingAgentId;
  @override
  final double? tmuxWindowId;
  @override
  final String? chat;

  /// Create a copy of SandboxAgent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SandboxAgentCopyWith<_SandboxAgent> get copyWith =>
      __$SandboxAgentCopyWithImpl<_SandboxAgent>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SandboxAgentToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SandboxAgent &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sandboxAgentId, sandboxAgentId) ||
                other.sandboxAgentId == sandboxAgentId) &&
            (identical(other.delegatingAgentId, delegatingAgentId) ||
                other.delegatingAgentId == delegatingAgentId) &&
            (identical(other.tmuxWindowId, tmuxWindowId) ||
                other.tmuxWindowId == tmuxWindowId) &&
            (identical(other.chat, chat) || other.chat == chat));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, sandboxAgentId, delegatingAgentId, tmuxWindowId, chat);

  @override
  String toString() {
    return 'SandboxAgent(id: $id, sandboxAgentId: $sandboxAgentId, delegatingAgentId: $delegatingAgentId, tmuxWindowId: $tmuxWindowId, chat: $chat)';
  }
}

/// @nodoc
abstract mixin class _$SandboxAgentCopyWith<$Res>
    implements $SandboxAgentCopyWith<$Res> {
  factory _$SandboxAgentCopyWith(
          _SandboxAgent value, $Res Function(_SandboxAgent) _then) =
      __$SandboxAgentCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String sandboxAgentId,
      String delegatingAgentId,
      double? tmuxWindowId,
      String? chat});
}

/// @nodoc
class __$SandboxAgentCopyWithImpl<$Res>
    implements _$SandboxAgentCopyWith<$Res> {
  __$SandboxAgentCopyWithImpl(this._self, this._then);

  final _SandboxAgent _self;
  final $Res Function(_SandboxAgent) _then;

  /// Create a copy of SandboxAgent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? sandboxAgentId = null,
    Object? delegatingAgentId = null,
    Object? tmuxWindowId = freezed,
    Object? chat = freezed,
  }) {
    return _then(_SandboxAgent(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sandboxAgentId: null == sandboxAgentId
          ? _self.sandboxAgentId
          : sandboxAgentId // ignore: cast_nullable_to_non_nullable
              as String,
      delegatingAgentId: null == delegatingAgentId
          ? _self.delegatingAgentId
          : delegatingAgentId // ignore: cast_nullable_to_non_nullable
              as String,
      tmuxWindowId: freezed == tmuxWindowId
          ? _self.tmuxWindowId
          : tmuxWindowId // ignore: cast_nullable_to_non_nullable
              as double?,
      chat: freezed == chat
          ? _self.chat
          : chat // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
