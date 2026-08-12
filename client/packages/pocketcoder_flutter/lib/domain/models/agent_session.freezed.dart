// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentSession {
  String get id;
  String get chat;
  String get user;
  String get acpSessionId;
  String? get harnessVersion;
  String? get modelProvider;
  String? get harnessInstance;

  /// Create a copy of AgentSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentSessionCopyWith<AgentSession> get copyWith =>
      _$AgentSessionCopyWithImpl<AgentSession>(
          this as AgentSession, _$identity);

  /// Serializes this AgentSession to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentSession &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.chat, chat) || other.chat == chat) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.acpSessionId, acpSessionId) ||
                other.acpSessionId == acpSessionId) &&
            (identical(other.harnessVersion, harnessVersion) ||
                other.harnessVersion == harnessVersion) &&
            (identical(other.modelProvider, modelProvider) ||
                other.modelProvider == modelProvider) &&
            (identical(other.harnessInstance, harnessInstance) ||
                other.harnessInstance == harnessInstance));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, chat, user, acpSessionId,
      harnessVersion, modelProvider, harnessInstance);

  @override
  String toString() {
    return 'AgentSession(id: $id, chat: $chat, user: $user, acpSessionId: $acpSessionId, harnessVersion: $harnessVersion, modelProvider: $modelProvider, harnessInstance: $harnessInstance)';
  }
}

/// @nodoc
abstract mixin class $AgentSessionCopyWith<$Res> {
  factory $AgentSessionCopyWith(
          AgentSession value, $Res Function(AgentSession) _then) =
      _$AgentSessionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String chat,
      String user,
      String acpSessionId,
      String? harnessVersion,
      String? modelProvider,
      String? harnessInstance});
}

/// @nodoc
class _$AgentSessionCopyWithImpl<$Res> implements $AgentSessionCopyWith<$Res> {
  _$AgentSessionCopyWithImpl(this._self, this._then);

  final AgentSession _self;
  final $Res Function(AgentSession) _then;

  /// Create a copy of AgentSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? chat = null,
    Object? user = null,
    Object? acpSessionId = null,
    Object? harnessVersion = freezed,
    Object? modelProvider = freezed,
    Object? harnessInstance = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      chat: null == chat
          ? _self.chat
          : chat // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      acpSessionId: null == acpSessionId
          ? _self.acpSessionId
          : acpSessionId // ignore: cast_nullable_to_non_nullable
              as String,
      harnessVersion: freezed == harnessVersion
          ? _self.harnessVersion
          : harnessVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      modelProvider: freezed == modelProvider
          ? _self.modelProvider
          : modelProvider // ignore: cast_nullable_to_non_nullable
              as String?,
      harnessInstance: freezed == harnessInstance
          ? _self.harnessInstance
          : harnessInstance // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AgentSession].
extension AgentSessionPatterns on AgentSession {
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
    TResult Function(_AgentSession value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AgentSession() when $default != null:
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
    TResult Function(_AgentSession value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentSession():
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
    TResult? Function(_AgentSession value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentSession() when $default != null:
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
            String chat,
            String user,
            String acpSessionId,
            String? harnessVersion,
            String? modelProvider,
            String? harnessInstance)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AgentSession() when $default != null:
        return $default(_that.id, _that.chat, _that.user, _that.acpSessionId,
            _that.harnessVersion, _that.modelProvider, _that.harnessInstance);
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
            String chat,
            String user,
            String acpSessionId,
            String? harnessVersion,
            String? modelProvider,
            String? harnessInstance)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentSession():
        return $default(_that.id, _that.chat, _that.user, _that.acpSessionId,
            _that.harnessVersion, _that.modelProvider, _that.harnessInstance);
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
            String chat,
            String user,
            String acpSessionId,
            String? harnessVersion,
            String? modelProvider,
            String? harnessInstance)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AgentSession() when $default != null:
        return $default(_that.id, _that.chat, _that.user, _that.acpSessionId,
            _that.harnessVersion, _that.modelProvider, _that.harnessInstance);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AgentSession implements AgentSession {
  const _AgentSession(
      {required this.id,
      required this.chat,
      required this.user,
      required this.acpSessionId,
      this.harnessVersion,
      this.modelProvider,
      this.harnessInstance});
  factory _AgentSession.fromJson(Map<String, dynamic> json) =>
      _$AgentSessionFromJson(json);

  @override
  final String id;
  @override
  final String chat;
  @override
  final String user;
  @override
  final String acpSessionId;
  @override
  final String? harnessVersion;
  @override
  final String? modelProvider;
  @override
  final String? harnessInstance;

  /// Create a copy of AgentSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AgentSessionCopyWith<_AgentSession> get copyWith =>
      __$AgentSessionCopyWithImpl<_AgentSession>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentSessionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AgentSession &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.chat, chat) || other.chat == chat) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.acpSessionId, acpSessionId) ||
                other.acpSessionId == acpSessionId) &&
            (identical(other.harnessVersion, harnessVersion) ||
                other.harnessVersion == harnessVersion) &&
            (identical(other.modelProvider, modelProvider) ||
                other.modelProvider == modelProvider) &&
            (identical(other.harnessInstance, harnessInstance) ||
                other.harnessInstance == harnessInstance));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, chat, user, acpSessionId,
      harnessVersion, modelProvider, harnessInstance);

  @override
  String toString() {
    return 'AgentSession(id: $id, chat: $chat, user: $user, acpSessionId: $acpSessionId, harnessVersion: $harnessVersion, modelProvider: $modelProvider, harnessInstance: $harnessInstance)';
  }
}

/// @nodoc
abstract mixin class _$AgentSessionCopyWith<$Res>
    implements $AgentSessionCopyWith<$Res> {
  factory _$AgentSessionCopyWith(
          _AgentSession value, $Res Function(_AgentSession) _then) =
      __$AgentSessionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String chat,
      String user,
      String acpSessionId,
      String? harnessVersion,
      String? modelProvider,
      String? harnessInstance});
}

/// @nodoc
class __$AgentSessionCopyWithImpl<$Res>
    implements _$AgentSessionCopyWith<$Res> {
  __$AgentSessionCopyWithImpl(this._self, this._then);

  final _AgentSession _self;
  final $Res Function(_AgentSession) _then;

  /// Create a copy of AgentSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? chat = null,
    Object? user = null,
    Object? acpSessionId = null,
    Object? harnessVersion = freezed,
    Object? modelProvider = freezed,
    Object? harnessInstance = freezed,
  }) {
    return _then(_AgentSession(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      chat: null == chat
          ? _self.chat
          : chat // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      acpSessionId: null == acpSessionId
          ? _self.acpSessionId
          : acpSessionId // ignore: cast_nullable_to_non_nullable
              as String,
      harnessVersion: freezed == harnessVersion
          ? _self.harnessVersion
          : harnessVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      modelProvider: freezed == modelProvider
          ? _self.modelProvider
          : modelProvider // ignore: cast_nullable_to_non_nullable
              as String?,
      harnessInstance: freezed == harnessInstance
          ? _self.harnessInstance
          : harnessInstance // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
